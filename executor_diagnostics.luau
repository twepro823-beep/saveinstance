-- saveinstance executor compatibility diagnostics
-- Safe by default: risky native calls are only executed when RUN_RISKY_TESTS is true.

local RUN_RISKY_TESTS = false
local HTTP_TIMEOUT = 8
local TEST_FILE = "saveinstance_executor_diagnostics.txt"

local lines = {}

local function push(level, message)
	local line = "[" .. level .. "] " .. message
	lines[#lines + 1] = line
	print("[saveinstance diagnostics] " .. line)
end

local function getFunction(name)
	local value = getgenv and getgenv()[name] or _G[name]
	return type(value) == "function" and value or nil
end

local function getNestedFunction(rootName, childName)
	local root = getgenv and getgenv()[rootName] or _G[rootName]
	return type(root) == "table" and type(root[childName]) == "function" and root[childName] or nil
end

local function try(label, fn)
	local started = os.clock()
	local ok, result = pcall(fn)
	local elapsed = math.floor((os.clock() - started) * 1000)

	if ok then
		push("PASS", label .. " (" .. elapsed .. "ms)")
		return true, result
	end

	push("FAIL", label .. " (" .. elapsed .. "ms): " .. tostring(result))
	return false, result
end

local function withTimeout(timeout, fn)
	local thread = coroutine.running()
	local done = false

	task.spawn(function()
		local ok, result = pcall(fn)
		if done then
			return
		end
		done = true
		coroutine.resume(thread, ok, result)
	end)

	task.delay(timeout, function()
		if done then
			return
		end
		done = true
		coroutine.resume(thread, false, "timed out after " .. tostring(timeout) .. "s")
	end)

	return coroutine.yield()
end

local function markFunction(name, fn)
	if fn then
		push("PASS", name .. " exists")
	else
		push("WARN", name .. " missing")
	end
end

local identify = identifyexecutor or getexecutorname or whatexecutor
local executorName = "unknown"
if identify then
	try("identify executor", function()
		executorName = tostring(identify())
	end)
end

push("INFO", "executor: " .. executorName)
push("INFO", "placeId: " .. tostring(game.PlaceId))
push("INFO", "risky tests: " .. tostring(RUN_RISKY_TESTS))

local writefileFn = getFunction("writefile")
local readfileFn = getFunction("readfile")
local appendfileFn = getFunction("appendfile")
local delfileFn = getFunction("delfile")
local isfileFn = getFunction("isfile")
local gethiddenpropertyFn = getFunction("gethiddenproperty")
local getscriptbytecodeFn = getFunction("getscriptbytecode")
local decompileFn = getFunction("decompile")
local base64encodeFn = getFunction("base64encode") or getNestedFunction("crypt", "base64encode")
local hashFn = getFunction("hash") or getNestedFunction("crypt", "hash")
local requestFn = getFunction("request") or getFunction("http_request") or getNestedFunction("syn", "request")

markFunction("writefile", writefileFn)
markFunction("readfile", readfileFn)
markFunction("appendfile", appendfileFn)
markFunction("base64encode/crypt.base64encode", base64encodeFn)
markFunction("hash/crypt.hash", hashFn)
markFunction("request/http_request/syn.request", requestFn)
markFunction("gethiddenproperty", gethiddenpropertyFn)
markFunction("getscriptbytecode", getscriptbytecodeFn)
markFunction("decompile", decompileFn)

if writefileFn and readfileFn then
	try("small writefile/readfile", function()
		writefileFn(TEST_FILE, "saveinstance diagnostics\n")
		local content = readfileFn(TEST_FILE)
		assert(string.find(content, "saveinstance diagnostics", 1, true), "readfile returned unexpected content")
	end)
else
	push("FAIL", "file saving is not compatible: writefile/readfile missing")
end

if appendfileFn and readfileFn then
	try("small appendfile", function()
		appendfileFn(TEST_FILE, "append ok\n")
		local content = readfileFn(TEST_FILE)
		assert(string.find(content, "append ok", 1, true), "appendfile content missing")
	end)
end

if base64encodeFn then
	try("base64 sanity", function()
		assert(base64encodeFn("\1\0\0\0\1") == "AQAAAAE=", "base64 output mismatch")
	end)
end

if hashFn then
	try("hash sanity", function()
		local digest = hashFn("saveinstance", "sha384")
		assert(type(digest) == "string" and #digest > 0, "hash returned empty result")
	end)
end

try("game HttpGet small request", function()
	local ok, result = withTimeout(HTTP_TIMEOUT, function()
		return game:HttpGet("https://setup.rbxcdn.com/version", true)
	end)
	assert(ok, result)
	assert(type(result) == "string" and #result > 0, "empty HttpGet response")
end)

try("basic readable property access", function()
	assert(workspace.Name ~= nil, "workspace.Name unavailable")
	assert(game:GetService("HttpService") ~= nil, "HttpService unavailable")
end)

if RUN_RISKY_TESTS then
	push("WARN", "running risky native tests; these can close Roblox on incompatible executors")

	if gethiddenpropertyFn then
		try("RISKY gethiddenproperty workspace.StreamOutBehavior", function()
			local value = gethiddenpropertyFn(workspace, "StreamOutBehavior")
			assert(value == nil or typeof(value) == "EnumItem", "unexpected gethiddenproperty return: " .. typeof(value))
		end)
	end

	if getscriptbytecodeFn or decompileFn then
		local scriptTarget
		try("find one client LuaSourceContainer", function()
			for _, instance in ipairs(game:GetDescendants()) do
				if instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
					scriptTarget = instance
					break
				end
			end
			assert(scriptTarget, "no LocalScript/ModuleScript found")
		end)

		if scriptTarget and getscriptbytecodeFn then
			try("RISKY getscriptbytecode one script", function()
				local ok, result = withTimeout(3, function()
					return getscriptbytecodeFn(scriptTarget)
				end)
				assert(ok, result)
				assert(type(result) == "string", "bytecode is not a string")
			end)
		end

		if scriptTarget and decompileFn then
			try("RISKY decompile one script", function()
				local ok, result = withTimeout(5, function()
					return decompileFn(scriptTarget)
				end)
				assert(ok, result)
				assert(type(result) == "string", "decompile is not a string")
			end)
		end
	end
else
	push("INFO", "skipped risky gethiddenproperty/getscriptbytecode/decompile calls")
end

local recommended = {
	IgnoreSpecialProperties = true,
	IgnoreSharedStrings = true,
	SaveTerrainGrids = false,
	TreatUnreadableUnionsAsParts = true,
	TreatUnionsAsParts = true,
	AlternativeWritefile = appendfileFn ~= nil,
	LowMemory = true,
	noscripts = not RUN_RISKY_TESTS or not (decompileFn or getscriptbytecodeFn),
}

if not writefileFn then
	push("FAIL", "recommended action: use a different executor or a Callback option; writefile is missing")
end

if not base64encodeFn then
	push("FAIL", "recommended action: use an executor with base64 support; saveinstance needs base64encode")
end

if not hashFn then
	push("FAIL", "recommended action: use an executor with sha384/hash support; script cache may fail")
end

push("INFO", "recommended saveinstance options:")
for key, value in recommended do
	push("INFO", "  " .. key .. " = " .. tostring(value))
end

local report = table.concat(lines, "\n")
if writefileFn then
	pcall(writefileFn, TEST_FILE, report)
	push("INFO", "report written to " .. TEST_FILE)
end

return {
	executor = executorName,
	riskyTests = RUN_RISKY_TESTS,
	recommended = recommended,
	report = report,
}
