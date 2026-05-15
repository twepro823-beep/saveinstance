-- Union/MeshPart investigation helper for improving saveinstance.luau.
-- Run this in your executor, then send union_investigation_report.txt or the console output.

local HttpService = game:GetService("HttpService")

local MAX_SAMPLES_PER_CLASS = 25
local MAX_BAD_PATHS = 80
local REPORT_FILE = "union_investigation_report.txt"

local PROPERTIES = {
	"MeshData2",
	"MeshData",
	"ChildData2",
	"ChildData",
	"PhysicsData",
	"PhysicalConfigData",
	"AeroMeshData",
	"SerializedOperationGraph",
	"ManifoldMesh_DEPRECATED",
	"MeshSize",
	"InitialSize",
	"CollisionFidelity",
	"RenderFidelity",
	"SmoothingAngle",
	"UsePartColor",
	"AssetId",
	"TriangleCount",
}

local function safe_call(fn, ...)
	local ok, result = pcall(fn, ...)
	if ok then
		return true, result
	end
	return false, tostring(result)
end

local function read_index(instance, propertyName)
	return safe_call(function()
		return instance[propertyName]
	end)
end

local function read_hidden(instance, propertyName)
	if not gethiddenproperty then
		return false, "missing gethiddenproperty"
	end

	return safe_call(gethiddenproperty, instance, propertyName)
end

local ugcValidationService
local function read_ugc(instance, propertyName)
	if not ugcValidationService then
		local ok, serviceOrErr = safe_call(game.GetService, game, "UGCValidationService")
		if not ok then
			return false, "missing UGCValidationService"
		end
		ugcValidationService = serviceOrErr
	end

	return safe_call(function()
		return ugcValidationService:GetPropertyValue(instance, propertyName)
	end)
end

local function classify(value)
	local valueType = typeof(value)
	if value == nil then
		return {
			type = "nil",
			length = 0,
			empty = true,
		}
	end

	if type(value) == "string" then
		local len = #value
		local hasNull = string.find(value, "\0", 1, true) ~= nil
		local printable = string.gsub(string.sub(value, 1, 80), "[%c]", ".")
		local looksBase64 = len > 0 and string.match(value, "^[A-Za-z0-9+/=]+$") ~= nil

		return {
			type = valueType,
			length = len,
			empty = len == 0,
			hasNull = hasNull,
			looksBase64 = looksBase64,
			prefix = printable,
		}
	end

	return {
		type = valueType,
		length = 0,
		empty = false,
		value = tostring(value),
	}
end

local function merge_count(target, key)
	target[key] = (target[key] or 0) + 1
end

local stats = {
	executor = identifyexecutor and table.concat({ identifyexecutor() }, " ") or getexecutorname and getexecutorname() or "unknown",
	version = version(),
	placeId = game.PlaceId,
	placeVersion = game.PlaceVersion,
	hasGetHiddenProperty = gethiddenproperty ~= nil,
	hasGetHiddenProp = gethiddenprop ~= nil,
	total = 0,
	classes = {},
	properties = {},
	badPaths = {},
	samples = {},
}

local function ensure_property_stats(propertyName)
	local prop = stats.properties[propertyName]
	if not prop then
		prop = {
			index = {},
			hidden = {},
			ugc = {},
		}
		stats.properties[propertyName] = prop
	end
	return prop
end

local function add_bad_path(instance, reason)
	if #stats.badPaths < MAX_BAD_PATHS then
		stats.badPaths[#stats.badPaths + 1] = {
			path = instance:GetFullName(),
			class = instance.ClassName,
			reason = reason,
		}
	end
end

local function add_sample(instance, propertyName, methodName, info)
	local className = instance.ClassName
	local classSamples = stats.samples[className]
	if not classSamples then
		classSamples = {}
		stats.samples[className] = classSamples
	end

	if #classSamples >= MAX_SAMPLES_PER_CLASS then
		return
	end

	if info.length and info.length > 0 then
		classSamples[#classSamples + 1] = {
			path = instance:GetFullName(),
			property = propertyName,
			method = methodName,
			info = info,
		}
	end
end

local function record_method(instance, propertyName, methodName, ok, value)
	local prop = ensure_property_stats(propertyName)
	local bucket = prop[methodName]

	if not ok then
		merge_count(bucket, "fail")
		return
	end

	local info = classify(value)
	merge_count(bucket, info.empty and "empty" or "nonempty")
	merge_count(bucket, "type_" .. info.type)

	if info.hasNull then
		merge_count(bucket, "binary")
	end
	if info.looksBase64 then
		merge_count(bucket, "base64ish")
	end

	add_sample(instance, propertyName, methodName, info)
end

local function has_readable_geometry(instance)
	for _, propertyName in { "MeshData2", "MeshData", "ChildData2", "ChildData", "SerializedOperationGraph" } do
		local ok, value = read_hidden(instance, propertyName)
		if ok and type(value) == "string" and #value > 0 then
			return true, propertyName, #value
		end

		ok, value = read_index(instance, propertyName)
		if ok and type(value) == "string" and #value > 0 then
			return true, propertyName, #value
		end

		ok, value = read_ugc(instance, propertyName)
		if ok and type(value) == "string" and #value > 0 then
			return true, propertyName, #value
		end
	end

	return false
end

for _, instance in game:GetDescendants() do
	if instance:IsA("TriangleMeshPart") then
		stats.total += 1
		merge_count(stats.classes, instance.ClassName)

		for _, propertyName in PROPERTIES do
			record_method(instance, propertyName, "index", read_index(instance, propertyName))
			record_method(instance, propertyName, "hidden", read_hidden(instance, propertyName))
			record_method(instance, propertyName, "ugc", read_ugc(instance, propertyName))
		end

		if instance:IsA("PartOperation") then
			local readable, propertyName, length = has_readable_geometry(instance)
			if not readable then
				add_bad_path(instance, "no readable union geometry")
			else
				add_bad_path(instance, "readable via " .. propertyName .. " len=" .. length)
			end
		end
	end
end

local report = HttpService:JSONEncode(stats)

print("[union investigator] scanned", stats.total, "TriangleMeshPart instances")
print("[union investigator] gethiddenproperty:", stats.hasGetHiddenProperty)
print("[union investigator] writing", REPORT_FILE, "length", #report)

if writefile then
	writefile(REPORT_FILE, report)
else
	warn("[union investigator] writefile is missing; copy this JSON manually:")
	print(report)
end

return stats
