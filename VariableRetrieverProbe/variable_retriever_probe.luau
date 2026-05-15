-- VariableRetrieverProbe
-- Safe runtime mapper for executor-exposed Roblox/Luau APIs.
-- It does not use memory byte editing. It only reports what the current client/executor can access.

local HttpService = game:GetService("HttpService")

local REPORT_FILE = "VariableRetrieverProbe_Report.json"
local PLACEHOLDER_FILE = "VariableRetrieverProbe_SSS_Placeholders.luau"
local MAX_DESCENDANTS_PER_SERVICE = 5000
local MAX_PATHS_PER_SERVICE = 250
local MAX_GC_OBJECTS = 20000
local MAX_INFERRED_NAMES = 300
local MAX_CONSTANTS_PER_FUNCTION = 80

local function now()
	return os.date and os.date("!%Y-%m-%dT%H:%M:%SZ") or tostring(os.clock())
end

local function safe(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

local function typeof_safe(value)
	local ok, result = pcall(typeof, value)
	return ok and result or type(value)
end

local function executor_name()
	if identifyexecutor then
		local ok, name, versionText = pcall(identifyexecutor)
		if ok then
			return table.concat({ tostring(name), tostring(versionText or "") }, " ")
		end
	end
	if getexecutorname then
		local ok, name = pcall(getexecutorname)
		if ok then
			return tostring(name)
		end
	end
	return "unknown"
end

local function api_status(name)
	local value = getgenv and getgenv()[name] or _G[name]
	return {
		exists = value ~= nil,
		type = value ~= nil and typeof_safe(value) or "nil",
	}
end

local function add_unique(list, seen, value, limit)
	if not value or value == "" or seen[value] then
		return
	end
	seen[value] = true
	if #list < limit then
		list[#list + 1] = value
	end
end

local function looks_scriptish(value)
	if type(value) ~= "string" then
		return false
	end
	local lower = string.lower(value)
	return string.find(lower, "serverscriptservice", 1, true)
		or string.find(lower, "serverstorage", 1, true)
		or string.find(lower, "script", 1, true)
		or string.find(lower, "service", 1, true)
		or string.find(lower, "remote", 1, true)
		or string.find(lower, "handler", 1, true)
		or string.find(lower, "controller", 1, true)
end

local function split_candidate_names(value)
	local out = {}
	if type(value) ~= "string" then
		return out
	end

	for token in string.gmatch(value, "[%w_][%w_%- ]+") do
		token = string.gsub(token, "^%s+", "")
		token = string.gsub(token, "%s+$", "")
		if #token >= 3 and #token <= 80 and looks_scriptish(token) then
			out[#out + 1] = token
		end
	end

	return out
end

local function read_source_state(instance)
	local ok, result = safe(function()
		return instance.Source
	end)

	if ok then
		return {
			readable = true,
			length = type(result) == "string" and #result or 0,
			candidates = type(result) == "string" and split_candidate_names(result) or {},
		}
	end

	return {
		readable = false,
		error = tostring(result),
	}
end

local function class_bucket()
	return {
		total = 0,
		classes = {},
		paths = {},
		scripts = {},
	}
end

local function push_limited(list, value, limit)
	if #list < limit then
		list[#list + 1] = value
	end
end

local function relative_segments(instance, root)
	local segments = {}
	local current = instance
	while current and current ~= root do
		table.insert(segments, 1, current.Name)
		current = current.Parent
	end
	return segments
end

local function scan_service(serviceName)
	local bucket = class_bucket()
	local okService, serviceOrErr = safe(game.GetService, game, serviceName)
	bucket.accessible = okService

	if not okService then
		bucket.error = serviceOrErr
		return bucket
	end

	bucket.className = serviceOrErr.ClassName
	bucket.fullName = serviceOrErr:GetFullName()

	local okChildren, childrenOrErr = safe(serviceOrErr.GetDescendants, serviceOrErr)
	if not okChildren then
		bucket.descendantsReadable = false
		bucket.error = childrenOrErr
		return bucket
	end

	bucket.descendantsReadable = true

	for i, descendant in childrenOrErr do
		if i > MAX_DESCENDANTS_PER_SERVICE then
			bucket.truncated = true
			break
		end

		bucket.total += 1
		local className = descendant.ClassName
		bucket.classes[className] = (bucket.classes[className] or 0) + 1
		push_limited(bucket.paths, descendant:GetFullName(), MAX_PATHS_PER_SERVICE)

		if descendant:IsA("LuaSourceContainer") then
			local sourceState = read_source_state(descendant)
			push_limited(bucket.scripts, {
				name = descendant.Name,
				className = className,
				path = descendant:GetFullName(),
				relativeSegments = relative_segments(descendant, serviceOrErr),
				source = sourceState,
			}, MAX_PATHS_PER_SERVICE)
		end
	end

	return bucket
end

local function scan_nil_instances()
	local info = {
		available = getnilinstances ~= nil,
		total = 0,
		classes = {},
		scripts = {},
	}

	if not getnilinstances then
		return info
	end

	local ok, instancesOrErr = safe(getnilinstances)
	if not ok then
		info.error = instancesOrErr
		return info
	end

	for _, instance in instancesOrErr do
		info.total += 1
		info.classes[instance.ClassName] = (info.classes[instance.ClassName] or 0) + 1
		if instance:IsA("LuaSourceContainer") then
			push_limited(info.scripts, {
				name = instance.Name,
				className = instance.ClassName,
				path = instance:GetFullName(),
				source = read_source_state(instance),
			}, MAX_PATHS_PER_SERVICE)
		end
	end

	return info
end

local function scan_replicated_source_hints(report)
	local hints = {
		totalReadableSources = 0,
		names = {},
	}
	local seen = {}

	for _, serviceScan in report.services do
		for _, scriptInfo in serviceScan.scripts or {} do
			if scriptInfo.source and scriptInfo.source.readable and scriptInfo.source.length > 0 then
				hints.totalReadableSources += 1
				for _, candidate in scriptInfo.source.candidates or {} do
					add_unique(hints.names, seen, candidate, MAX_INFERRED_NAMES)
				end
			end
		end
	end

	return hints
end

local function get_function_constants(fn)
	local getters = {}
	if debug then
		getters[#getters + 1] = debug.getconstants
		getters[#getters + 1] = debug.getconstant and function(func)
			local constants = {}
			for i = 1, MAX_CONSTANTS_PER_FUNCTION do
				local ok, value = pcall(debug.getconstant, func, i)
				if ok then
					constants[#constants + 1] = value
				end
			end
			return constants
		end
	end
	if getconstants then
		getters[#getters + 1] = getconstants
	end

	for _, getter in getters do
		if type(getter) == "function" then
			local ok, constants = safe(getter, fn)
			if ok and type(constants) == "table" then
				return constants
			end
		end
	end

	return nil
end

local function scan_gc_hints()
	local hints = {
		available = getgc ~= nil,
		scanned = 0,
		functions = 0,
		envScripts = {},
		constants = {},
		inferredNames = {},
	}
	local seenEnvScripts = {}
	local seenConstants = {}
	local seenNames = {}

	if not getgc then
		return hints
	end

	local ok, objectsOrErr = safe(getgc, true)
	if not ok then
		hints.error = objectsOrErr
		return hints
	end

	for _, obj in objectsOrErr do
		hints.scanned += 1
		if hints.scanned > MAX_GC_OBJECTS then
			hints.truncated = true
			break
		end

		if type(obj) == "function" then
			hints.functions += 1

			if getfenv then
				local okEnv, env = safe(getfenv, obj)
				if okEnv and type(env) == "table" and typeof(env.script) == "Instance" then
					add_unique(hints.envScripts, seenEnvScripts, env.script:GetFullName(), MAX_INFERRED_NAMES)
				end
			end

			local constants = get_function_constants(obj)
			if constants then
				local count = 0
				for _, constant in constants do
					count += 1
					if count > MAX_CONSTANTS_PER_FUNCTION then
						break
					end
					if looks_scriptish(constant) then
						add_unique(hints.constants, seenConstants, constant, MAX_INFERRED_NAMES)
						for _, candidate in split_candidate_names(constant) do
							add_unique(hints.inferredNames, seenNames, candidate, MAX_INFERRED_NAMES)
						end
					end
				end
			end
		end
	end

	return hints
end

local function lua_quote(value)
	return string.format("%q", tostring(value))
end

local function build_sss_placeholders(sssScan, inference)
	local lines = {
		"-- Generated by VariableRetrieverProbe.",
		"-- Run this in Studio Command Bar or a trusted Studio plugin to create empty ServerScriptService placeholders.",
		"local SSS = game:GetService(\"ServerScriptService\")",
		"local function child(parent, className, name)",
		"\tlocal existing = parent:FindFirstChild(name)",
		"\tif existing then return existing end",
		"\tlocal ok, obj = pcall(Instance.new, className)",
		"\tif not ok then obj = Instance.new(\"Folder\") end",
		"\tobj.Name = name",
		"\tobj.Parent = parent",
		"\treturn obj",
		"end",
		"local function ensure(path, className)",
		"\tlocal parent = SSS",
		"\tfor i = 1, #path - 1 do",
		"\t\tparent = child(parent, \"Folder\", path[i])",
		"\tend",
		"\tlocal obj = child(parent, className, path[#path])",
		"\tpcall(function() obj.Source = \"\" end)",
		"\treturn obj",
		"end",
	}

	local scripts = sssScan and sssScan.scripts or {}
	if #scripts == 0 then
		local inferred = inference and inference.inferredNames or {}
		if #inferred == 0 then
			lines[#lines + 1] = "local marker = child(SSS, \"Script\", \"ServerScriptService_NotReplicated\")"
			lines[#lines + 1] = "pcall(function() marker.Source = " .. lua_quote("-- ServerScriptService descendants were not visible from this client/executor.") .. " end)"
		else
			lines[#lines + 1] = "local folder = child(SSS, \"Folder\", \"Inferred_Server_Scripts\")"
			for _, name in inferred do
				lines[#lines + 1] = "pcall(function() child(folder, \"Script\", " .. lua_quote(name) .. ").Source = \"\" end)"
			end
		end
		return table.concat(lines, "\n")
	end

	for _, scriptInfo in scripts do
		local parts = scriptInfo.relativeSegments or { scriptInfo.name }
		local quotedParts = {}
		for _, part in parts do
			quotedParts[#quotedParts + 1] = lua_quote(part)
		end
		lines[#lines + 1] = "ensure({" .. table.concat(quotedParts, ", ") .. "}, " .. lua_quote(scriptInfo.className) .. ")"
	end

	return table.concat(lines, "\n")
end

local report = {
	generatedAt = now(),
	executor = executor_name(),
	version = version(),
	placeId = game.PlaceId,
	placeVersion = game.PlaceVersion,
	apis = {
		gethiddenproperty = api_status("gethiddenproperty"),
		gethiddenprop = api_status("gethiddenprop"),
		getnilinstances = api_status("getnilinstances"),
		getgc = api_status("getgc"),
		debug_getupvalue = {
			exists = debug and debug.getupvalue ~= nil,
			type = debug and debug.getupvalue ~= nil and typeof_safe(debug.getupvalue) or "nil",
		},
		writefile = api_status("writefile"),
		readfile = api_status("readfile"),
	},
	services = {},
	nilInstances = nil,
	inference = nil,
	notes = {
		"ServerScriptService is server-only in normal Roblox replication. Empty output usually means it is not visible, not that it is empty on the server.",
		"This probe intentionally avoids memory byte editing and only uses exposed APIs.",
	},
}

for _, serviceName in {
	"ServerScriptService",
	"ServerStorage",
	"ReplicatedStorage",
	"ReplicatedFirst",
	"StarterPlayer",
	"StarterGui",
	"Workspace",
} do
	report.services[serviceName] = scan_service(serviceName)
end

report.nilInstances = scan_nil_instances()
report.inference = {
	gc = scan_gc_hints(),
	sourceHints = nil,
	inferredNames = {},
}
report.inference.sourceHints = scan_replicated_source_hints(report)

do
	local seen = {}
	for _, value in report.inference.gc.inferredNames or {} do
		add_unique(report.inference.inferredNames, seen, value, MAX_INFERRED_NAMES)
	end
	for _, value in report.inference.gc.envScripts or {} do
		add_unique(report.inference.inferredNames, seen, value, MAX_INFERRED_NAMES)
	end
	for _, value in report.inference.sourceHints.names or {} do
		add_unique(report.inference.inferredNames, seen, value, MAX_INFERRED_NAMES)
	end
end

local reportJson = HttpService:JSONEncode(report)
local placeholders = build_sss_placeholders(report.services.ServerScriptService, report.inference)

print("[VariableRetrieverProbe] executor:", report.executor)
print("[VariableRetrieverProbe] ServerScriptService descendants:", report.services.ServerScriptService.total)
print("[VariableRetrieverProbe] ServerScriptService scripts:", #report.services.ServerScriptService.scripts)
print("[VariableRetrieverProbe] inferred names:", #report.inference.inferredNames)

if writefile then
	writefile(REPORT_FILE, reportJson)
	writefile(PLACEHOLDER_FILE, placeholders)
	print("[VariableRetrieverProbe] wrote", REPORT_FILE, "and", PLACEHOLDER_FILE)
else
	warn("[VariableRetrieverProbe] writefile missing; printing report and placeholders.")
	print(reportJson)
	print(placeholders)
end

return report
