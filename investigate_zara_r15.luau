-- Investigates workspace.MAP.MAPPARTS.PhotoBooth.ZaraBundleStatic for R15/Rthro save issues.
-- Run this in the same client/executor where saveinstance is failing, then check console/output.

local TARGET_PATH = "workspace.MAP.MAPPARTS.PhotoBooth.ZaraBundleStatic"
local WRITE_REPORT = true
local REPORT_FILE = "ZaraBundleStatic_R15_Report.txt"

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
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	lines[#lines + 1] = table.concat(parts, "")
end

local function getByPath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		if token == "game" then
			current = game
		elseif token == "workspace" then
			current = workspace
		else
			current = current:FindFirstChild(token)
		end

		if not current then
			return nil
		end
	end
	return current
end

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

	local okService, ugc = pcall(function()
		return game:GetService("UGCValidationService")
	end)
	if okService and ugc then
		ok, value = pcall(function()
			return ugc:GetPropertyValue(instance, propertyName)
		end)
		if ok then
			return true, value, "UGCValidationService"
		end
	end

	return false, nil, "unreadable"
end

local function valueToString(value)
	local valueType = typeof(value)
	if value == nil then
		return "nil"
	elseif valueType == "Instance" then
		return value:GetFullName()
	elseif valueType == "Content" then
		local okSourceType, sourceType = pcall(function()
			return value.SourceType
		end)
		if not okSourceType then
			return "<Content unreadable>"
		end

		if sourceType == Enum.ContentSourceType.Uri then
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
	elseif valueType == "Vector3" then
		return string.format("%.4f, %.4f, %.4f", value.X, value.Y, value.Z)
	elseif valueType == "CFrame" then
		local pos = value.Position
		return string.format("pos %.4f, %.4f, %.4f", pos.X, pos.Y, pos.Z)
	elseif valueType == "table" then
		return "<table>"
	end
	return tostring(value)
end

local function inspectProperties(lines, instance, properties)
	append(lines, "    properties:")
	for _, propertyName in properties do
		local ok, value, source = safeRead(instance, propertyName)
		if ok then
			append(lines, "      ", propertyName, " [", source, "] = ", valueToString(value))
		else
			append(lines, "      ", propertyName, " = <unreadable>")
		end
	end
end

local function collectByClass(root)
	local buckets = {}
	for _, descendant in root:GetDescendants() do
		local className = descendant.ClassName
		local bucket = buckets[className]
		if not bucket then
			bucket = {}
			buckets[className] = bucket
		end
		bucket[#bucket + 1] = descendant
	end
	return buckets
end

local function isRigPart(instance)
	return instance:IsA("BasePart") and table.find(expectedR15Parts, instance.Name) ~= nil
end

local function main()
	local lines = {}
	local root = getByPath(TARGET_PATH)

	append(lines, "R15/Rthro investigation report")
	append(lines, "Target: ", TARGET_PATH)
	append(lines, "Generated at: ", os.date("%Y-%m-%d %H:%M:%S"))
	append(lines, "")

	if not root then
		append(lines, "ERROR: target was not found.")
		warn(table.concat(lines, "\n"))
		return
	end

	append(lines, "Root: ", root:GetFullName(), " [", root.ClassName, "]")
	append(lines, "Root Archivable: ", root.Archivable)
	append(lines, "Descendant count: ", #root:GetDescendants())
	append(lines, "")

	local humanoid = root:FindFirstChildOfClass("Humanoid") or root:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		append(lines, "Humanoid: ", humanoid:GetFullName())
		inspectProperties(lines, humanoid, {
			"RigType",
			"Health",
			"MaxHealth",
			"BodyTypeScale",
			"BodyDepthScale",
			"BodyHeightScale",
			"BodyWidthScale",
			"HeadScale",
			"AutomaticScalingEnabled",
			"AvatarPartScaleType",
		})
	else
		append(lines, "Humanoid: MISSING")
	end
	append(lines, "")

	local description = root:FindFirstChildOfClass("HumanoidDescription")
		or root:FindFirstChildWhichIsA("HumanoidDescription", true)
	if description then
		append(lines, "HumanoidDescription: ", description:GetFullName())
		inspectProperties(lines, description, {
			"Head",
			"Torso",
			"LeftArm",
			"RightArm",
			"LeftLeg",
			"RightLeg",
			"GraphicTShirt",
			"Shirt",
			"Pants",
			"BodyTypeScale",
			"DepthScale",
			"HeightScale",
			"ProportionScale",
			"WidthScale",
		})
	else
		append(lines, "HumanoidDescription: not found")
	end
	append(lines, "")

	append(lines, "Expected R15 body parts:")
	for _, partName in expectedR15Parts do
		local part = root:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") then
			append(lines, "  OK ", partName, " -> ", part:GetFullName(), " [", part.ClassName, "] Archivable=", part.Archivable)
		elseif part then
			append(lines, "  WRONG_CLASS ", partName, " -> ", part:GetFullName(), " [", part.ClassName, "]")
		else
			append(lines, "  MISSING ", partName)
		end
	end
	append(lines, "")

	local buckets = collectByClass(root)
	append(lines, "Class counts:")
	local classNames = {}
	for className in buckets do
		classNames[#classNames + 1] = className
	end
	table.sort(classNames)
	for _, className in classNames do
		append(lines, "  ", className, ": ", #buckets[className])
	end
	append(lines, "")

	append(lines, "MeshPart/body-part details:")
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("MeshPart") or descendant:IsA("Part") and isRigPart(descendant) then
			append(lines, "  ", descendant:GetFullName(), " [", descendant.ClassName, "]")
			inspectProperties(lines, descendant, {
				"Archivable",
				"Size",
				"MeshId",
				"MeshContent",
				"TextureID",
				"TextureContent",
				"RenderFidelity",
				"CollisionFidelity",
				"MeshSize",
			})
		end
	end
	append(lines, "")

	append(lines, "Wrap/layered clothing objects:")
	local wrapClasses = {
		BaseWrap = true,
		WrapLayer = true,
		WrapTarget = true,
	}
	local foundWrap = false
	for _, descendant in root:GetDescendants() do
		if wrapClasses[descendant.ClassName] or descendant:IsA("BaseWrap") then
			foundWrap = true
			append(lines, "  ", descendant:GetFullName(), " [", descendant.ClassName, "] Parent=", descendant.Parent and descendant.Parent.ClassName or "nil")
			inspectProperties(lines, descendant, {
				"Archivable",
				"CageMeshId",
				"CageMeshContent",
				"CageOrigin",
				"ImportOrigin",
				"ReferenceMeshId",
				"ReferenceMeshContent",
				"ReferenceOrigin",
				"HSRMeshIdData",
				"ShrinkFactor",
				"Order",
				"Puffiness",
				"AutoSkin",
				"Enabled",
			})
		end
	end
	if not foundWrap then
		append(lines, "  none found")
	end
	append(lines, "")

	append(lines, "Accessories and handles:")
	local accessories = buckets.Accessory or {}
	if #accessories == 0 then
		append(lines, "  none found")
	end
	for _, accessory in accessories do
		append(lines, "  ", accessory:GetFullName(), " Archivable=", accessory.Archivable)
		local handle = accessory:FindFirstChild("Handle")
		if handle then
			append(lines, "    Handle: ", handle.ClassName, " Archivable=", handle.Archivable)
			inspectProperties(lines, handle, { "Size", "MeshId", "MeshContent", "TextureID", "TextureContent", "MeshSize" })
		else
			append(lines, "    Handle: MISSING")
		end
	end
	append(lines, "")

	append(lines, "SurfaceAppearance details:")
	local surfaceAppearances = buckets.SurfaceAppearance or {}
	if #surfaceAppearances == 0 then
		append(lines, "  none found")
	end
	for _, surfaceAppearance in surfaceAppearances do
		append(lines, "  ", surfaceAppearance:GetFullName(), " Archivable=", surfaceAppearance.Archivable)
		inspectProperties(lines, surfaceAppearance, {
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
	append(lines, "")

	append(lines, "Attachments, joints, constraints summary:")
	for _, className in { "Attachment", "Bone", "Motor6D", "Weld", "WeldConstraint", "AccessoryWeld" } do
		local list = buckets[className] or {}
		append(lines, "  ", className, ": ", #list)
		for i = 1, math.min(#list, 30) do
			local item = list[i]
			append(lines, "    ", item:GetFullName(), " Parent=", item.Parent and item.Parent.ClassName or "nil")
		end
		if #list > 30 then
			append(lines, "    ... ", #list - 30, " more")
		end
	end
	append(lines, "")

	append(lines, "Non-archivable descendants:")
	local nonArchivableCount = 0
	for _, descendant in root:GetDescendants() do
		if not descendant.Archivable then
			nonArchivableCount += 1
			append(lines, "  ", descendant:GetFullName(), " [", descendant.ClassName, "]")
		end
	end
	if nonArchivableCount == 0 then
		append(lines, "  none")
	end
	append(lines, "")

	append(lines, "Saveinstance options to test with this rig:")
	append(lines, "  SavePlayerCharacters = true")
	append(lines, "  IgnoreSharedStrings = false")
	append(lines, "  IgnoreSpecialProperties = false")
	append(lines, "  Object = workspace.MAP.MAPPARTS.PhotoBooth.ZaraBundleStatic")

	local report = table.concat(lines, "\n")
	print(report)

	if WRITE_REPORT and writefile then
		local ok, err = pcall(writefile, REPORT_FILE, report)
		if ok then
			print("[investigate_zara_r15] wrote report to " .. REPORT_FILE)
		else
			warn("[investigate_zara_r15] failed to write report: " .. tostring(err))
		end
	end
end

main()
