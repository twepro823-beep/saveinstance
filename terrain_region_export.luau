-- Exports exact Terrain data for Roblox Studio restoration.
-- Outputs:
--   SmoothGrid.bin
--   PhysicsGrid.bin
--   TerrainRegion.rbxmx

local RAW_CHUNK_SIZE = 4 * 1024 * 1024
local B64_CHUNK_SIZE = 3 * 1024 * 1024
local PROGRESS_FILE = "terrain_region_export_progress.txt"

local b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64chars = table.create(64)
for i = 1, 64 do
	b64chars[i] = string.sub(b64, i, i)
end

local function requireFunction(name, value)
	assert(type(value) == "function", name .. " is missing")
	return value
end

local writefile = requireFunction("writefile", writefile)
local appendfile = requireFunction("appendfile", appendfile)
local gethiddenproperty = requireFunction("gethiddenproperty", gethiddenproperty)

local function log(message)
	print("[terrain export] " .. message)
	pcall(writefile, PROGRESS_FILE, message)
end

local function encodeBase64(data)
	local len = #data
	local result = table.create(math.ceil(len / 3) * 4)
	local resultSize = 1

	for i = 1, len, 3 do
		local byte1, byte2, byte3 = string.byte(data, i, i + 2)
		local triplet = byte1 * 0x10000 + (byte2 or 0) * 0x100 + (byte3 or 0)

		result[resultSize] = b64chars[math.floor(triplet / 0x40000) % 64 + 1]
		result[resultSize + 1] = b64chars[math.floor(triplet / 0x1000) % 64 + 1]
		result[resultSize + 2] = byte2 and b64chars[math.floor(triplet / 0x40) % 64 + 1] or "="
		result[resultSize + 3] = byte3 and b64chars[triplet % 64 + 1] or "="
		resultSize += 4
	end

	return table.concat(result)
end

local function appendRaw(path, data)
	writefile(path, "")
	for offset = 1, #data, RAW_CHUNK_SIZE do
		appendfile(path, string.sub(data, offset, offset + RAW_CHUNK_SIZE - 1))
		task.wait()
	end
end

local function appendBase64Property(path, propertyName, data)
	appendfile(path, '<BinaryString name="' .. propertyName .. '"><![CDATA[')
	for offset = 1, #data, B64_CHUNK_SIZE do
		appendfile(path, encodeBase64(string.sub(data, offset, offset + B64_CHUNK_SIZE - 1)))
		task.wait()
	end
	appendfile(path, "]]></BinaryString>")
end

local function vector3int16Tag(name, value)
	return "<Vector3int16 name=\""
		.. name
		.. "\"><X>"
		.. value.X
		.. "</X><Y>"
		.. value.Y
		.. "</Y><Z>"
		.. value.Z
		.. "</Z></Vector3int16>"
end

local terrain = workspace.Terrain

log("reading Terrain SmoothGrid")
local terrainSmoothGrid = gethiddenproperty(terrain, "SmoothGrid")
assert(type(terrainSmoothGrid) == "string", "Terrain SmoothGrid did not return string")
appendRaw("SmoothGrid.bin", terrainSmoothGrid)

log("reading Terrain PhysicsGrid")
local terrainPhysicsGrid = gethiddenproperty(terrain, "PhysicsGrid")
assert(type(terrainPhysicsGrid) == "string", "Terrain PhysicsGrid did not return string")
appendRaw("PhysicsGrid.bin", terrainPhysicsGrid)

log("reading Terrain MaxExtents")
local maxExtents = gethiddenproperty(terrain, "MaxExtents")
assert(typeof(maxExtents) == "Region3int16", "Terrain MaxExtents did not return Region3int16")

log("copying TerrainRegion")
local region = terrain:CopyRegion(maxExtents)
assert(region and region:IsA("TerrainRegion"), "CopyRegion did not return TerrainRegion")

log("reading TerrainRegion hidden data")
local regionSmoothGrid = gethiddenproperty(region, "SmoothGrid")
local okGridV3, regionGridV3 = pcall(gethiddenproperty, region, "GridV3")
if not okGridV3 then
	regionGridV3 = nil
end
local extentsMin = gethiddenproperty(region, "ExtentsMin")
local extentsMax = gethiddenproperty(region, "ExtentsMax")

assert(type(regionSmoothGrid) == "string", "TerrainRegion SmoothGrid did not return string")
if typeof(extentsMin) ~= "Vector3int16" or typeof(extentsMax) ~= "Vector3int16" then
	log("TerrainRegion extents unavailable; using Terrain MaxExtents fallback")
	extentsMin = maxExtents.Min
	extentsMax = maxExtents.Max
end

assert(typeof(extentsMin) == "Vector3int16", "ExtentsMin fallback did not return Vector3int16")
assert(typeof(extentsMax) == "Vector3int16", "ExtentsMax fallback did not return Vector3int16")

log("writing TerrainRegion.rbxmx")
writefile(
	"TerrainRegion.rbxmx",
	'<roblox version="4"><Item class="TerrainRegion" referent="RBX0"><Properties>'
		.. '<string name="Name">ImportedTerrainRegion</string>'
		.. vector3int16Tag("ExtentsMin", extentsMin)
		.. vector3int16Tag("ExtentsMax", extentsMax)
)

appendBase64Property("TerrainRegion.rbxmx", "SmoothGrid", regionSmoothGrid)
if type(regionGridV3) == "string" and regionGridV3 ~= "" then
	appendBase64Property("TerrainRegion.rbxmx", "GridV3", regionGridV3)
end
appendfile("TerrainRegion.rbxmx", "</Properties></Item></roblox>")

log(
	"done; wrote SmoothGrid.bin, PhysicsGrid.bin, TerrainRegion.rbxmx; region cells "
		.. tostring(extentsMin)
		.. " -> "
		.. tostring(extentsMax)
)

return true
