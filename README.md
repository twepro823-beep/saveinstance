all credits to USSI, i only did some changes

# LIST OF WORKING GETHIDDENPROPERTY EXEC: madium,yubx,velocity and others
# https://github.com/luau/UniversalSynSaveInstance

# Loadstring

```lua
local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/saveinstance.luau", true), "saveinstance")();
local SaveinstanceOptions = {
    TreatUnionsAsParts = false,
    TreatUnreadableUnionsAsParts = false,
    IgnoreSpecialProperties = true,
    IgnoreSharedStrings = true,
    ReadMe = true,
    ScriptSourceHeader = false,
    LinkedSourceComment = false,
}
synsaveinstance(SaveinstanceOptions);
```

# Decompile prepass

This preloads script decompilation through an external API before running saveinstance. It sends readable client bytecode to `https://api.lua.expert/decompile`.

```lua
local saveWithPrepass = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/decompile_prepass.luau", true), "decompile_prepass")()

saveWithPrepass({
    IgnoreSpecialProperties = true,
    IgnoreSharedStrings = true,
}, {
    MaxInFlight = 30,
    RequestsPerMinute = 1400,
    RequestTimeout = 20,
})
```

To only warm the decompile cache without saving:

```lua
saveWithPrepass(nil, {
    SkipSaveInstance = true,
})
```

# manual version

```lua
https://www.youtube.com/watch?v=ZDZdmhqLLeM&t=6s
```

# Export and restore Terrain in Studio

Run this in the executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/terrain_region_export.luau", true), "terrain_region_export")()
```

It writes:

```text
<placeId> <placeName> SmoothGrid.bin
<placeId> <placeName> PhysicsGrid.bin
<placeId> <placeName> TerrainRegion.rbxmx
<placeId> <placeName> terrain_region_export_progress.txt
```

For Roblox Studio, install `studio_terrain_region_importer.plugin.luau` as a local plugin. Then open your place, click `Plugins -> Terrain Importer -> Import TerrainRegion`, and select the file ending with `TerrainRegion.rbxmx`.

The plugin uses `SerializationService:DeserializeInstancesAsync()` to load the `TerrainRegion`, then `workspace.Terrain:PasteRegion()` to write it into the map. The two raw `.bin` files are saved as backup/debug data; Studio plugins cannot directly set `Terrain.PhysicsGrid` or `Terrain.SmoothGrid` because those properties are hidden and not scriptable.

# 💖 Support Their & Their Work

<a href='https://ko-fi.com/M4M1JNH5G' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi2.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' title='KO-FI' /></a>
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M1JNH5G "KO-FI")
<br />
[![ko-fi](https://user-images.githubusercontent.com/95628489/231759262-25661006-b7ca-4967-a79d-2b465cd9575a.png)](https://ko-fi.com/M4M1JNH5G "KO-FI QR-CODE")

# DISCORD SERVER:<br />

<https://discord.com/invite/wx4ThpAsmw> **/** <https://discord.gg/wx4ThpAsmw><br />
[<img src="https://discordapp.com/api/guilds/1022465460517740654/widget.png?style=banner2" alt="Our Official Discord Server!"></img>](https://discord.com/invite/wx4ThpAsmw)<br />
