-- Deep investigation for ZaraBundleStatic R15/Rthro save failures.
-- Run after the failed save. If you know the generated file name, put it in SAVED_FILE_NAME.

local TARGET_PATH = "workspace.MAP.MAPPARTS.PhotoBooth.ZaraBundleStatic"
local SAVED_FILE_NAME = nil -- Example: "model ZaraBundleStatic.rbxlx" or "MyPlace.rbxl"
local REPORT_FILE = "ZaraBundleStatic_SaveFailure_Report.txt"

local expectedR15Parts = {
	"Head",
	"HumanoidRootPart",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local function append(lines, ...)
	local values = table.pack(...)
	for i = 1, values.n do
		values[i] = tostring(values[i])
	end
	lines[#lines + 1] = table.concat(values, "")
end

local function getByPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if token == "game" then
			current = game
		elseif token == "workspace" then
			current = workspace
		else
			current = current and current:FindFirstChild(token)
		end
		if not current then
			return nil
		end
	end
	return current
end

local cachedUGCValidationService
local function safeRead(instance, propertyName)
	local ok, value = pcall(function()
		return instance[propertyName]
	end)
	if ok then
		return true, value, "normal"
	end

	if gethiddenproperty then
		ok, value = pcall(gethiddenproperty, instance, propertyName)
		if ok then
			return true, value, "gethiddenproperty"
		end
	end

	if cachedUGCValidationService == nil then
		local okService, service = pcall(function()
			return game:GetService("UGCValidationService")
		end)
		cachedUGCValidationService = okService and service or false
	end

	if cachedUGCValidationService then
		ok, value = pcall(function()
			return cachedUGCValidationService:GetPropertyValue(instance, propertyName)
		end)
		if ok then
			return true, value, "UGCValidationService"
		end
	end

	return false, nil, "unreadable"
end

local function summarize(value)
	local valueType = typeof(value)
	if value == nil then
		return "nil"
	elseif valueType == "Instance" then
		return value:GetFullName() .. " [" .. value.ClassName .. "]"
	elseif valueType == "Vector3" then
		return string.format("%.5f, %.5f, %.5f", value.X, value.Y, value.Z)
	elseif valueType == "CFrame" then
		local p = value.Position
		return string.format("pos %.5f, %.5f, %.5f", p.X, p.Y, p.Z)
	elseif valueType == "Content" then
		local okSource, sourceType = pcall(function()
			return value.SourceType
		end)
		if not okSource then
			return "Content(<unreadable>)"
		elseif sourceType == Enum.ContentSourceType.Uri then
			local okUri, uri = pcall(function()
				return value.Uri
			end)
			return "Content.Uri(" .. tostring(okUri and uri or "<unreadable>") .. ")"
		elseif sourceType == Enum.ContentSourceType.Object then
			local okObject, object = pcall(function()
				return value.Object
			end)
			return "Content.Object(" .. tostring(okObject and object and object:GetFullName() or object) .. ")"
		end
		return "Content.None"
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif type(value) == "string" then
		if #value > 180 then
			return string.sub(value, 1, 180) .. "... <len=" .. #value .. ">"
		end
		return value
	end
	return tostring(value)
end

local function readLine(lines, instance, propertyName)
	local ok, value, source = safeRead(instance, propertyName)
	if ok then
		append(lines, "      ", propertyName, " [", source, "] = ", summarize(value))
	else
		append(lines, "      ", propertyName, " = <unreadable>")
	end
	return ok, value
end

local function readProperties(lines, instance, properties)
	for _, propertyName in properties do
		readLine(lines, instance, propertyName)
	end
end

local function getChildrenByClass(root, className)
	local found = {}
	for _, descendant in root:GetDescendants() do
		if descendant.ClassName == className then
			found[#found + 1] = descendant
		end
	end
	return found
end

local function bodyPartMap(root)
	local map = {}
	for _, name in expectedR15Parts do
		local part = root:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			map[name] = part
		end
	end
	return map
end

local function inspectHumanoid(lines, root)
	local humanoid = root:FindFirstChildOfClass("Humanoid") or root:FindFirstChildWhichIsA("Humanoid", true)
	append(lines, "Humanoid:")
	if not humanoid then
		append(lines, "  MISSING")
		return
	end

	append(lines, "  ", humanoid:GetFullName())
	readProperties(lines, humanoid, {
		"RigType",
		"AutomaticScalingEnabled",
		"RequiresNeck",
		"BreakJointsOnDeath",
		"HipHeight",
		"Health",
		"MaxHealth",
	})

	append(lines, "  Humanoid scale NumberValues:")
	for _, child in humanoid:GetChildren() do
		if child:IsA("NumberValue") then
			append(lines, "    ", child.Name, " = ", child.Value, " Archivable=", child.Archivable)
		end
	end
end

local function inspectBodyParts(lines, root)
	local map = bodyPartMap(root)
	append(lines, "R15 body MeshPart/Part details:")
	for _, name in expectedR15Parts do
		local part = map[name]
		if not part then
			append(lines, "  MISSING ", name)
			continue
		end

		append(lines, "  ", name, " -> ", part:GetFullName(), " [", part.ClassName, "]")
		readProperties(lines, part, {
			"Archivable",
			"Transparency",
			"LocalTransparencyModifier",
			"Size",
			"CFrame",
			"Anchored",
			"CanCollide",
			"Massless",
			"RootPriority",
			"MeshId",
			"MeshID",
			"MeshContent",
			"TextureID",
			"TextureContent",
			"MeshSize",
			"InitialSize",
			"HasSkinnedMesh",
			"RenderFidelity",
			"CollisionFidelity",
			"DoubleSided",
		})
	end
end

local function inspectJoints(lines, root)
	local map = bodyPartMap(root)
	local bodySet = {}
	for _, part in map do
		bodySet[part] = true
	end

	append(lines, "Motor6D body graph:")
	for _, motor in root:GetDescendants() do
		if motor:IsA("Motor6D") then
			local part0 = motor.Part0
			local part1 = motor.Part1
			local touchesBody = bodySet[part0] or bodySet[part1]
			append(
				lines,
				"  ",
				motor:GetFullName(),
				touchesBody and " [body]" or "",
				" Part0=",
				part0 and part0.Name or "nil",
				" Part1=",
				part1 and part1.Name or "nil"
			)
			readProperties(lines, motor, { "C0", "C1", "Transform", "Enabled" })
		end
	end
end

local function inspectWraps(lines, root)
	append(lines, "Wrap data:")
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BaseWrap") or descendant.ClassName == "WrapLayer" or descendant.ClassName == "WrapTarget" then
			append(lines, "  ", descendant:GetFullName(), " [", descendant.ClassName, "] Parent=", descendant.Parent and descendant.Parent:GetFullName() or "nil")
			readProperties(lines, descendant, {
				"Archivable",
				"CageMeshId",
				"CageMeshContent",
				"CageOrigin",
				"ImportOrigin",
				"ReferenceMeshId",
				"ReferenceMeshContent",
				"ReferenceOrigin",
				"HSRMeshIdData",
				"Enabled",
				"Order",
				"Puffiness",
				"ShrinkFactor",
				"AutoSkin",
			})
		end
	end
end

local function inspectSurfaceAppearance(lines, root)
	append(lines, "SurfaceAppearance data:")
	local items = getChildrenByClass(root, "SurfaceAppearance")
	if #items == 0 then
		append(lines, "  none")
	end
	for _, item in items do
		append(lines, "  ", item:GetFullName(), " Parent=", item.Parent and item.Parent:GetFullName() or "nil")
		readProperties(lines, item, {
			"Archivable",
			"AlphaMode",
			"ColorMap",
			"ColorMapContent",
			"MetalnessMap",
			"MetalnessMapContent",
			"NormalMap",
			"NormalMapContent",
			"RoughnessMap",
			"RoughnessMapContent",
			"TexturePack",
		})
	end
end

local function inspectCloneBehavior(lines, root)
	append(lines, "Clone() behavior:")
	local ok, clone = pcall(function()
		return root:Clone()
	end)
	if not ok or not clone then
		append(lines, "  Clone failed: ", clone)
		return
	end

	append(lines, "  Clone created. Descendants=", #clone:GetDescendants())
	local cloneMap = bodyPartMap(clone)
	for _, name in expectedR15Parts do
		local part = cloneMap[name]
		if part then
			local meshOk, meshId = safeRead(part, "MeshId")
			local sizeOk, size = safeRead(part, "Size")
			append(
				lines,
				"  ",
				name,
				" clone OK [",
				part.ClassName,
				"] MeshId=",
				meshOk and summarize(meshId) or "<unreadable>",
				" Size=",
				sizeOk and summarize(size) or "<unreadable>"
			)
		else
			append(lines, "  ", name, " clone MISSING")
		end
	end
	clone:Destroy()
end

local function findLikelySavedFiles()
	if not listfiles then
		return {}
	end

	local ok, files = pcall(listfiles, "")
	if not ok or type(files) ~= "table" then
		return {}
	end

	local candidates = {}
	for _, file in files do
		local lower = string.lower(file)
		if string.find(lower, "%.rbxl") or string.find(lower, "%.rbxmx") or string.find(lower, "%.xml") then
			candidates[#candidates + 1] = file
		end
	end
	table.sort(candidates)
	return candidates
end

local function inspectSavedFileContent(lines, fileName)
	local ok, content = pcall(readfile, fileName)
	if not ok or type(content) ~= "string" then
		append(lines, "  Failed to read ", fileName, ": ", content)
		return
	end

	append(lines, "  File: ", fileName, " bytes=", #content)
	for _, name in expectedR15Parts do
		local namePattern = '<string name="Name"><![CDATA[' .. name .. ']]></string>'
		local hasName = string.find(content, namePattern, 1, true) ~= nil
		local hasMeshIdNearby = false
		if hasName then
			local nameAt = string.find(content, namePattern, 1, true)
			local startAt = math.max(1, nameAt - 12000)
			local endAt = math.min(#content, nameAt + 12000)
			local chunk = string.sub(content, startAt, endAt)
			hasMeshIdNearby = string.find(chunk, 'name="MeshId"', 1, true) ~= nil
				or string.find(chunk, 'name="MeshID"', 1, true) ~= nil
			local hasMeshContentNearby = string.find(chunk, 'name="MeshContent"', 1, true) ~= nil
			local hasHasSkinnedMeshNearby = string.find(chunk, 'name="HasSkinnedMesh"', 1, true) ~= nil
			local hasInitialSizeNearby = string.find(chunk, 'name="InitialSize"', 1, true) ~= nil
			append(
				lines,
				"  ",
				name,
				": name=",
				hasName,
				" meshIdNearby=",
				hasMeshIdNearby,
				" meshContentNearby=",
				hasMeshContentNearby,
				" hasSkinnedMeshNearby=",
				hasHasSkinnedMeshNearby,
				" initialSizeNearby=",
				hasInitialSizeNearby
			)
		else
			append(lines, "  ", name, ": name=false")
		end
	end
end

local function inspectSavedFile(lines)
	append(lines, "Saved file inspection:")
	if not readfile then
		append(lines, "  readfile is not available in this executor.")
		return
	end

	if SAVED_FILE_NAME then
		inspectSavedFileContent(lines, SAVED_FILE_NAME)
		return
	end

	local candidates = findLikelySavedFiles()
	append(lines, "  SAVED_FILE_NAME is nil. Candidate files:")
	for i = 1, math.min(#candidates, 25) do
		append(lines, "    ", candidates[i])
	end

	local inspected = 0
	append(lines, "  Auto-inspecting ZaraBundleStatic candidates:")
	for _, fileName in candidates do
		local lower = string.lower(fileName)
		if string.find(lower, "zarabundlestatic", 1, true) then
			inspected += 1
			inspectSavedFileContent(lines, fileName)
			if inspected >= 5 then
				break
			end
		end
	end
	if inspected == 0 then
		append(lines, "    none matched ZaraBundleStatic; set SAVED_FILE_NAME manually.")
	end
end

local function main()
	local lines = {}
	append(lines, "ZaraBundleStatic deep save failure report")
	append(lines, "Target: ", TARGET_PATH)
	append(lines, "Generated at: ", os.date("%Y-%m-%d %H:%M:%S"))
	append(lines, "")

	local root = getByPath(TARGET_PATH)
	if not root then
		append(lines, "ERROR: target not found")
	else
		append(lines, "Root: ", root:GetFullName(), " [", root.ClassName, "] Archivable=", root.Archivable)
		append(lines, "Descendants: ", #root:GetDescendants())
		append(lines, "")
		inspectHumanoid(lines, root)
		append(lines, "")
		inspectBodyParts(lines, root)
		append(lines, "")
		inspectJoints(lines, root)
		append(lines, "")
		inspectWraps(lines, root)
		append(lines, "")
		inspectSurfaceAppearance(lines, root)
		append(lines, "")
		inspectCloneBehavior(lines, root)
		append(lines, "")
	end

	inspectSavedFile(lines)

	local report = table.concat(lines, "\n")
	print(report)
	if writefile then
		local ok, err = pcall(writefile, REPORT_FILE, report)
		if ok then
			print("[investigate_zara_save_failure] wrote " .. REPORT_FILE)
		else
			warn("[investigate_zara_save_failure] write failed: " .. tostring(err))
		end
	end
end

main()
