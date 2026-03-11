-- Pure-Lua base64 encoder/decoder
local base64 = {}

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function base64.encode(data)
    local result = {}
    local len = #data
    local i = 1
    while i <= len do
        local b0 = string.byte(data, i) or 0
        local b1 = string.byte(data, i + 1) or 0
        local b2 = string.byte(data, i + 2) or 0
        local n = b0 * 65536 + b1 * 256 + b2
        result[#result + 1] = string.sub(CHARS, math.floor(n / 262144) + 1, math.floor(n / 262144) + 1)
        result[#result + 1] = string.sub(CHARS, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        result[#result + 1] = i + 1 <= len and string.sub(CHARS, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        result[#result + 1] = i + 2 <= len and string.sub(CHARS, n % 64 + 1, n % 64 + 1) or "="
        i = i + 3
    end
    return table.concat(result)
end

local DECODE = {}
for i = 1, #CHARS do
    DECODE[string.sub(CHARS, i, i)] = i - 1
end

function base64.decode(data)
    -- strip padding and whitespace
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local result = {}
    local i = 1
    while i <= #data do
        local c0 = DECODE[string.sub(data, i, i)] or 0
        local c1 = DECODE[string.sub(data, i + 1, i + 1)] or 0
        local c2 = DECODE[string.sub(data, i + 2, i + 2)]
        local c3 = DECODE[string.sub(data, i + 3, i + 3)]
        local n = c0 * 262144 + c1 * 4096
        result[#result + 1] = string.char(math.floor(n / 65536) % 256)
        if c2 ~= nil then
            n = n + (c2 or 0) * 64
            result[#result + 1] = string.char(math.floor(n / 256) % 256)
        end
        if c3 ~= nil then
            n = n + (c3 or 0)
            result[#result + 1] = string.char(n % 256)
        end
        i = i + 4
    end
    return table.concat(result)
end

return base64
