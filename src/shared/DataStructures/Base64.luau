local Base64 = {}
-- 自定义 Base64 字符表（大小写互换）
local chars = 'abcdefghijklmnopqrstuvwxyz+ABCDEFGHIJKLMNOPQRSTUVWXYZ/0123456789'

local function getCustomChars(userId)
    local _chars = chars
    if userId and userId > 0 then
        local seed = userId * 4 % 64
        _chars = string.sub(chars, seed + 1) .. string.sub(chars, 1, seed)
    end
    return _chars
end

function Base64.Encode(data, userId)
    local _chars = getCustomChars(userId)
    local bytes = {}
    for i = 1, #data do
        bytes[i] = string.byte(data, i)
    end

    local result = {}
    for i = 1, #bytes, 3 do
        local b1, b2, b3 = bytes[i], bytes[i+1], bytes[i+2]
        local chunk = (b1 or 0) * 0x10000 + (b2 or 0) * 0x100 + (b3 or 0)
        
        for j = 1, 4 do
            local index = bit32.rshift(chunk, 6 * (4 - j)) % 64 + 1
            table.insert(result, _chars:sub(index, index))
        end
    end

    -- 补位
    local padding = (#bytes % 3 == 1) and "==" or (#bytes % 3 == 2) and "=" or ""
    return table.concat(result) .. padding
end

function Base64.Decode(data, userId)
    local _chars = getCustomChars(userId)
    local map = {}
    for i = 1, #_chars do
        map[_chars:sub(i, i)] = i - 1
    end

    data = data:gsub("[^%w+/=]", "")
    local result = {}
    for i = 1, #data, 4 do
        local chunk = 0
        for j = 0, 3 do
            local c = data:sub(i + j, i + j)
            if c == "=" then break end
            chunk = chunk * 64 + (map[c] or 0)
        end

        for j = 2, 0, -1 do
            if i + j <= #data then
                table.insert(result, string.char(bit32.rshift(chunk, 8 * j) % 256))
            end
        end
    end
    return table.concat(result)
end

-- 测试
-- local original = "Hello, Roblox!"
-- local encoded = Base64.Encode(original, 6053628054)
-- print("自定义 Base64 编码:", encoded)

-- local decoded = Base64.Decode(encoded, 6053628054)
-- print("解码后:", decoded)

return Base64
