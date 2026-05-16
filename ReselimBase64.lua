--!native
--!optimize 2

local buffer_create = buffer.create
local buffer_len = buffer.len
local buffer_readu8 = buffer.readu8
local buffer_readu32 = buffer.readu32
local buffer_writeu8 = buffer.writeu8
local bit32_band = bit32.band
local bit32_bor = bit32.bor
local bit32_byteswap = bit32.byteswap
local bit32_lshift = bit32.lshift
local bit32_rshift = bit32.rshift

local lookupValueToCharacter = buffer_create(64)
local lookupCharacterToValue = buffer_create(256)

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local padding = string.byte("=")

for index = 1, 64 do
	local value = index - 1
	local character = string.byte(alphabet, index)
	
	buffer_writeu8(lookupValueToCharacter, value, character)
	buffer_writeu8(lookupCharacterToValue, character, value)
end

local function encode(input: buffer): buffer
	local inputLength = buffer_len(input)
	local inputChunks = (inputLength + 2) // 3
	
	local outputLength = inputChunks * 4
	local output = buffer_create(outputLength)
	
	-- Since we use readu32 and chunks are 3 bytes large, we can't read the last chunk here
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 3
		local outputIndex = (chunkIndex - 1) * 4
		
		local chunk = bit32_byteswap(buffer_readu32(input, inputIndex))
		
		-- 8 + 24 - (6 * index)
		local value1 = bit32_rshift(chunk, 26)
		local value2 = bit32_band(bit32_rshift(chunk, 20), 0b111111)
		local value3 = bit32_band(bit32_rshift(chunk, 14), 0b111111)
		local value4 = bit32_band(bit32_rshift(chunk, 8), 0b111111)
		
		buffer_writeu8(output, outputIndex, buffer_readu8(lookupValueToCharacter, value1))
		buffer_writeu8(output, outputIndex + 1, buffer_readu8(lookupValueToCharacter, value2))
		buffer_writeu8(output, outputIndex + 2, buffer_readu8(lookupValueToCharacter, value3))
		buffer_writeu8(output, outputIndex + 3, buffer_readu8(lookupValueToCharacter, value4))
	end
	
	local inputRemainder = inputLength % 3
	
	if inputRemainder == 1 then
		local chunk = buffer_readu8(input, inputLength - 1)
		
		local value1 = bit32_rshift(chunk, 2)
		local value2 = bit32_band(bit32_lshift(chunk, 4), 0b111111)

		buffer_writeu8(output, outputLength - 4, buffer_readu8(lookupValueToCharacter, value1))
		buffer_writeu8(output, outputLength - 3, buffer_readu8(lookupValueToCharacter, value2))
		buffer_writeu8(output, outputLength - 2, padding)
		buffer_writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 2 then
		local chunk = bit32_bor(
			bit32_lshift(buffer_readu8(input, inputLength - 2), 8),
			buffer_readu8(input, inputLength - 1)
		)

		local value1 = bit32_rshift(chunk, 10)
		local value2 = bit32_band(bit32_rshift(chunk, 4), 0b111111)
		local value3 = bit32_band(bit32_lshift(chunk, 2), 0b111111)
		
		buffer_writeu8(output, outputLength - 4, buffer_readu8(lookupValueToCharacter, value1))
		buffer_writeu8(output, outputLength - 3, buffer_readu8(lookupValueToCharacter, value2))
		buffer_writeu8(output, outputLength - 2, buffer_readu8(lookupValueToCharacter, value3))
		buffer_writeu8(output, outputLength - 1, padding)
	elseif inputRemainder == 0 and inputLength ~= 0 then
		local chunk = bit32_bor(
			bit32_lshift(buffer_readu8(input, inputLength - 3), 16),
			bit32_lshift(buffer_readu8(input, inputLength - 2), 8),
			buffer_readu8(input, inputLength - 1)
		)

		local value1 = bit32_rshift(chunk, 18)
		local value2 = bit32_band(bit32_rshift(chunk, 12), 0b111111)
		local value3 = bit32_band(bit32_rshift(chunk, 6), 0b111111)
		local value4 = bit32_band(chunk, 0b111111)

		buffer_writeu8(output, outputLength - 4, buffer_readu8(lookupValueToCharacter, value1))
		buffer_writeu8(output, outputLength - 3, buffer_readu8(lookupValueToCharacter, value2))
		buffer_writeu8(output, outputLength - 2, buffer_readu8(lookupValueToCharacter, value3))
		buffer_writeu8(output, outputLength - 1, buffer_readu8(lookupValueToCharacter, value4))
	end
	
	return output
end

local function decode(input: buffer): buffer
	local inputLength = buffer_len(input)
	local inputChunks = (inputLength + 3) // 4
	
	-- TODO: Support input without padding
	local inputPadding = 0
	if inputLength ~= 0 then
		if buffer_readu8(input, inputLength - 1) == padding then inputPadding += 1 end
		if buffer_readu8(input, inputLength - 2) == padding then inputPadding += 1 end
	end

	local outputLength = inputChunks * 3 - inputPadding
	local output = buffer_create(outputLength)
	
	for chunkIndex = 1, inputChunks - 1 do
		local inputIndex = (chunkIndex - 1) * 4
		local outputIndex = (chunkIndex - 1) * 3
		
		local value1 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, inputIndex))
		local value2 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, inputIndex + 1))
		local value3 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, inputIndex + 2))
		local value4 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, inputIndex + 3))
		
		local chunk = bit32_bor(
			bit32_lshift(value1, 18),
			bit32_lshift(value2, 12),
			bit32_lshift(value3, 6),
			value4
		)
		
		local character1 = bit32_rshift(chunk, 16)
		local character2 = bit32_band(bit32_rshift(chunk, 8), 0b11111111)
		local character3 = bit32_band(chunk, 0b11111111)
		
		buffer_writeu8(output, outputIndex, character1)
		buffer_writeu8(output, outputIndex + 1, character2)
		buffer_writeu8(output, outputIndex + 2, character3)
	end
	
	if inputLength ~= 0 then
		local lastInputIndex = (inputChunks - 1) * 4
		local lastOutputIndex = (inputChunks - 1) * 3
		
		local lastValue1 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, lastInputIndex))
		local lastValue2 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, lastInputIndex + 1))
		local lastValue3 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, lastInputIndex + 2))
		local lastValue4 = buffer_readu8(lookupCharacterToValue, buffer_readu8(input, lastInputIndex + 3))

		local lastChunk = bit32_bor(
			bit32_lshift(lastValue1, 18),
			bit32_lshift(lastValue2, 12),
			bit32_lshift(lastValue3, 6),
			lastValue4
		)
		
		if inputPadding <= 2 then
			local lastCharacter1 = bit32_rshift(lastChunk, 16)
			buffer_writeu8(output, lastOutputIndex, lastCharacter1)
			
			if inputPadding <= 1 then
				local lastCharacter2 = bit32_band(bit32_rshift(lastChunk, 8), 0b11111111)
				buffer_writeu8(output, lastOutputIndex + 1, lastCharacter2)
				
				if inputPadding == 0 then
					local lastCharacter3 = bit32_band(lastChunk, 0b11111111)
					buffer_writeu8(output, lastOutputIndex + 2, lastCharacter3)
				end
			end
		end
	end
	
	return output
end

return {
	encode = encode,
	decode = decode,
}
