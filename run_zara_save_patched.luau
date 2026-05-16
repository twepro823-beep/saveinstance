-- Runs the patched saveinstance with a cache-busted URL and a fixed output file,
-- then inspects that exact file so old saves do not confuse the diagnosis.

local SAVE_FILE = "ZaraBundleStatic_PATCHED_TEST.rbxmx"
local TARGET = workspace.MAP.MAPPARTS.PhotoBooth.ZaraBundleStatic
local CACHE_BUST = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999))

local saveUrl = "https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/saveinstance.luau?cb=" .. CACHE_BUST
local inspectUrl = "https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/investigate_zara_save_failure.luau?cb=" .. CACHE_BUST

print("[zara patched test] loading saveinstance:", saveUrl)

for _, descendant in TARGET:GetDescendants() do
	if descendant:IsA("MeshPart") then
		descendant:SetAttribute("_SSI_BackupMeshId", descendant.MeshId)
		descendant:SetAttribute("_SSI_BackupTextureID", descendant.TextureID)
		descendant:SetAttribute("_SSI_BackupSize", descendant.Size)
		descendant:SetAttribute("_SSI_BackupMeshSize", descendant.MeshSize)
	end
end

local synsaveinstance = loadstring(game:HttpGet(saveUrl, true), "saveinstance")()

synsaveinstance({
	Object = TARGET,
	IsModel = true,
	FilePath = SAVE_FILE,
	IgnoreSpecialProperties = false,
	IgnoreSharedStrings = false,
	SavePlayerCharacters = true,
	ReadMe = false,
	ScriptSourceHeader = false,
	LinkedSourceComment = false,
})

print("[zara patched test] saved:", SAVE_FILE)

local inspectSource = game:HttpGet(inspectUrl, true)
inspectSource = string.gsub(
	inspectSource,
	"local SAVED_FILE_NAME = nil",
	"local SAVED_FILE_NAME = " .. string.format("%q", SAVE_FILE),
	1
)

loadstring(inspectSource, "investigate_zara_save_failure")()
