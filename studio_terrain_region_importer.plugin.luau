-- Local Roblox Studio plugin.
-- Put this file in your Studio local plugins folder, then use the Plugins tab.

local StudioService = game:GetService("StudioService")
local SerializationService = game:GetService("SerializationService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local toolbar = plugin:CreateToolbar("Terrain Importer")
local importButton = toolbar:CreateButton(
	"Import TerrainRegion",
	"Open TerrainRegion.rbxmx and paste it into workspace.Terrain",
	""
)

local function parseVector3int16(xml, propertyName)
	local body = string.match(xml, '<Vector3int16 name="' .. propertyName .. '">(.-)</Vector3int16>')
	assert(body, "Missing " .. propertyName .. " in TerrainRegion.rbxmx")

	local x = tonumber(string.match(body, "<X>(%-?%d+)</X>"))
	local y = tonumber(string.match(body, "<Y>(%-?%d+)</Y>"))
	local z = tonumber(string.match(body, "<Z>(%-?%d+)</Z>"))
	assert(x and y and z, "Invalid " .. propertyName .. " in TerrainRegion.rbxmx")

	return Vector3int16.new(x, y, z)
end

local function findTerrainRegion(instances)
	for _, instance in ipairs(instances) do
		if instance:IsA("TerrainRegion") then
			return instance
		end
		local found = instance:FindFirstChildWhichIsA("TerrainRegion", true)
		if found then
			return found
		end
	end
end

local function promptFile()
	if StudioService.PromptImportFileAsync then
		return StudioService:PromptImportFileAsync({ "rbxmx" })
	end
	return StudioService:PromptImportFile({ "rbxmx" })
end

local function importTerrainRegion()
	local file = promptFile()
	if not file then
		warn("[Terrain Importer] No file selected")
		return
	end

	local xml = file:GetBinaryContents()
	assert(type(xml) == "string" and #xml ~= 0, "Selected file is empty")

	local extentsMin = parseVector3int16(xml, "ExtentsMin")
	local instances = SerializationService:DeserializeInstancesAsync(buffer.fromstring(xml))
	local region = findTerrainRegion(instances)
	assert(region, "Could not deserialize a TerrainRegion from the selected file")

	local recording = ChangeHistoryService:TryBeginRecording("Import TerrainRegion")
	workspace.Terrain:PasteRegion(region, extentsMin, true)
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end

	print("[Terrain Importer] Imported TerrainRegion at " .. tostring(extentsMin))
end

importButton.Click:Connect(function()
	local ok, err = xpcall(importTerrainRegion, debug.traceback)
	if not ok then
		warn("[Terrain Importer] Failed to import TerrainRegion:")
		warn(err)
	end
end)
