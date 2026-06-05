-- Exact Terrain grid dumper for executors that can safely read Terrain internals.
-- If Roblox closes while this runs, check terrain_grid_dump_progress.txt.

local WRITE_BASE64 = false
local PROGRESS_FILE = "terrain_grid_dump_progress.txt"
local CHUNK_SIZE = 4 * 1024 * 1024

local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64chars = table.create(64)
for i = 1, 64 do
	b64chars[i] = string.sub(b, i, i)
end

local function toBase64Chunk(data)
	local len = #data
	local out = table.create(math.ceil(len / 3) * 4)
	local outSize = 1

	for i = 1, len, 3 do
		local byte1, byte2, byte3 = string.byte(data, i, i + 2)
		local triplet = byte1 * 0x10000 + (byte2 or 0) * 0x100 + (byte3 or 0)

		out[outSize] = b64chars[math.floor(triplet / 0x40000) % 64 + 1]
		out[outSize + 1] = b64chars[math.floor(triplet / 0x1000) % 64 + 1]
		out[outSize + 2] = byte2 and b64chars[math.floor(triplet / 0x40) % 64 + 1] or "="
		out[outSize + 3] = byte3 and b64chars[triplet % 64 + 1] or "="
		outSize += 4
	end

	return table.concat(out)
end

local function assertFunction(name, value)
	assert(type(value) == "function", name .. " is missing")
	return value
end

local writefile = assertFunction("writefile", writefile)
local appendfile = assertFunction("appendfile", appendfile)
local gethiddenproperty = assertFunction("gethiddenproperty", gethiddenproperty)

local function log(message)
	print("[terrain grid dump] " .. message)
	pcall(writefile, PROGRESS_FILE, message)
end

local function writeLarge(path, data)
	writefile(path, "")
	for offset = 1, #data, CHUNK_SIZE do
		appendfile(path, string.sub(data, offset, offset + CHUNK_SIZE - 1))
		task.wait()
	end
end

local function writeLargeBase64(path, data)
	writefile(path, "")

	local carry = ""
	for offset = 1, #data, CHUNK_SIZE do
		local chunk = carry .. string.sub(data, offset, offset + CHUNK_SIZE - 1)
		local usable = #chunk - (#chunk % 3)
		if usable ~= 0 then
			appendfile(path, toBase64Chunk(string.sub(chunk, 1, usable)))
		end
		carry = string.sub(chunk, usable + 1)
		task.wait()
	end

	if #carry ~= 0 then
		appendfile(path, toBase64Chunk(carry))
	end
end

local function dumpProperty(propertyName)
	log("about to read " .. propertyName)

	-- If this native call crashes the Roblox process, Lua cannot recover.
	local data = gethiddenproperty(workspace.Terrain, propertyName)
	assert(type(data) == "string", propertyName .. " returned " .. typeof(data))

	log("read " .. propertyName .. " bytes=" .. #data .. "; writing raw file")
	writeLarge(propertyName .. ".bin", data)

	if WRITE_BASE64 then
		log("writing " .. propertyName .. " base64")
		writeLargeBase64(propertyName .. ".base64.txt", data)
	end

	log("finished " .. propertyName .. " bytes=" .. #data)
end

log("starting exact Terrain grid dump")
dumpProperty("SmoothGrid")
dumpProperty("PhysicsGrid")
log("done; wrote SmoothGrid.bin and PhysicsGrid.bin")

return true
