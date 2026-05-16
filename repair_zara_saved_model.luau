-- Run this in Roblox Studio Command Bar after opening/importing the saved ZaraBundleStatic model.
-- It restores MeshPart asset ids from backup attributes written by run_zara_save_patched.luau.

local TARGET_NAME = "ZaraBundleStatic"

local function repairModel(model)
	local repaired = 0
	local missing = 0

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("MeshPart") then
			local meshId = descendant:GetAttribute("_SSI_BackupMeshId")
			local textureId = descendant:GetAttribute("_SSI_BackupTextureID")
			local size = descendant:GetAttribute("_SSI_BackupSize")

			if type(meshId) == "string" and meshId ~= "" then
				descendant.MeshId = meshId
				repaired += 1
			else
				missing += 1
			end

			if type(textureId) == "string" then
				descendant.TextureID = textureId
			end

			if typeof(size) == "Vector3" then
				descendant.Size = size
			end
		end
	end

	print(("[repair_zara_saved_model] %s repaired MeshParts=%d missingBackup=%d"):format(model:GetFullName(), repaired, missing))
end

local count = 0
for _, descendant in game:GetDescendants() do
	if descendant:IsA("Model") and descendant.Name == TARGET_NAME then
		count += 1
		repairModel(descendant)
	end
end

if count == 0 then
	warn("[repair_zara_saved_model] No model named " .. TARGET_NAME .. " found.")
end
