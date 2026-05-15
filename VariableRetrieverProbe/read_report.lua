-- Plain Lua helper for summarizing VariableRetrieverProbe_Report.json.
-- Usage: lua VariableRetrieverProbe/read_report.lua VariableRetrieverProbe_Report.json

local path = arg and arg[1] or "VariableRetrieverProbe_Report.json"
local file, err = io.open(path, "rb")
if not file then
	error(err)
end

local content = file:read("*a")
file:close()

local function extract_number(key)
	return tonumber(content:match('"' .. key .. '"%s*:%s*(%d+)')) or 0
end

local function section(name)
	local startAt = content:find('"' .. name .. '"%s*:', 1)
	if not startAt then
		return ""
	end
	return content:sub(startAt, math.min(#content, startAt + 2500))
end

print("Report:", path)
print("placeId:", extract_number("placeId"))
print("placeVersion:", extract_number("placeVersion"))

local sss = section("ServerScriptService")
local total = tonumber(sss:match('"total"%s*:%s*(%d+)')) or 0
print("ServerScriptService descendants:", total)

local scriptCount = 0
for _ in sss:gmatch('"className"%s*:%s*"[A-Za-z]*Script"') do
	scriptCount = scriptCount + 1
end
print("Visible SSS script entries:", scriptCount)

print("")
print("Tip: if descendants is 0, the client/executor did not expose ServerScriptService.")

