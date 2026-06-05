all credits to USSI, i only did some changes

# LIST OF WORKING GETHIDDENPROPERTY EXEC: madium,yubx,velocity and others
# https://github.com/luau/UniversalSynSaveInstance

# Loadstring

```lua
local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/saveinstance.luau", true), "saveinstance")();
local SaveinstanceOptions = {
    -- Safer crash-avoidance defaults. Disable these only after a successful test save.
    IgnoreSpecialProperties = true,
    IgnoreSharedStrings = true,
    SaveTerrainGrids = false,
    SaveTerrainVoxels = true,
    TerrainVoxelChunkSize = 32,
    TreatUnreadableUnionsAsParts = true,
    TreatUnionsAsParts = true,
    ReadMe = true,
    ScriptSourceHeader = false,
    LinkedSourceComment = false,
}
synsaveinstance(SaveinstanceOptions);
```

# Debug crash

If Roblox closes instead of showing an error in F9, the crash is probably native inside the executor or Roblox while reading hidden properties, SharedStrings, union geometry, decompiling, or writing a huge file.

Run the executor diagnostics first:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/executor_diagnostics.luau", true), "executor_diagnostics")()
```

Start with this minimal run:

```lua
local synsaveinstance = loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/saveinstance.luau", true), "saveinstance")()

synsaveinstance({
    mode = "scripts",
    noscripts = true,
    IgnoreSpecialProperties = true,
    IgnoreSharedStrings = true,
    SaveTerrainGrids = false,
    SaveTerrainVoxels = true,
    TerrainVoxelChunkSize = 32,
    TreatUnionsAsParts = true,
    AlternativeWritefile = true,
    LowMemory = true,
    timeout = 1,
    __DEBUG_MODE = true,
})
```

Then enable one feature at a time:

1. Change `mode` from `"scripts"` to `"optimized"`.
2. Change `noscripts` to `false`.
3. Change `TreatUnionsAsParts` to `false`.
4. Change `TerrainVoxelChunkSize` to `48` or `64` if terrain works and you want faster saving.
5. Change `SaveTerrainGrids` to `true`.
6. Change `IgnoreSharedStrings` to `false`.
7. Change `IgnoreSpecialProperties` to `false`.

The last option changed before Roblox closes is the crash source for your executor/game combination.

When `SaveTerrainVoxels = true`, the saved file will include a `Restore Terrain Voxels` Script. In Studio, move that Script to `ServerScriptService`, run the place once, then save the place again to bake the terrain.

# Exact terrain grid dump

If your executor can safely read Terrain internals, this dumps the exact `SmoothGrid` and `PhysicsGrid` strings to files:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twepro823-beep/saveinstance/main/terrain_grid_dump.luau", true), "terrain_grid_dump")()
```

It writes:

```text
SmoothGrid.bin
PhysicsGrid.bin
terrain_grid_dump_progress.txt
```

If Roblox closes, open `terrain_grid_dump_progress.txt` after relaunching. The last line tells which grid was being read. A crash during `gethiddenproperty(workspace.Terrain, "...Grid")` is native executor/client behavior and cannot be caught by Lua.

# manual version

```lua
https://www.youtube.com/watch?v=ZDZdmhqLLeM&t=6s
```

# 💖 Support Their & Their Work

<a href='https://ko-fi.com/M4M1JNH5G' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi2.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' title='KO-FI' /></a>
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M1JNH5G "KO-FI")
<br />
[![ko-fi](https://user-images.githubusercontent.com/95628489/231759262-25661006-b7ca-4967-a79d-2b465cd9575a.png)](https://ko-fi.com/M4M1JNH5G "KO-FI QR-CODE")

# DISCORD SERVER:<br />

<https://discord.com/invite/wx4ThpAsmw> **/** <https://discord.gg/wx4ThpAsmw><br />
[<img src="https://discordapp.com/api/guilds/1022465460517740654/widget.png?style=banner2" alt="Our Official Discord Server!"></img>](https://discord.com/invite/wx4ThpAsmw)<br />
