local Multipart = {}

--- Build a multipart/form-data request body.
-- @param parts table Array of parts. Each part is a table with:
--   For file parts: { name, filename, content_type, data }
--   For field parts: { name, value }
-- @return body string The multipart body
-- @return content_type string The Content-Type header with boundary
function Multipart.build(parts)
    local boundary = "----TurnBoundary" .. tostring(math.random(1000000000))
    local segments = {}

    for _, part in ipairs(parts) do
        local lines = {}
        table.insert(lines, "--" .. boundary)

        if part.filename then
            table.insert(lines, string.format(
                'Content-Disposition: form-data; name="%s"; filename="%s"',
                part.name, part.filename
            ))
            table.insert(lines, "Content-Type: " .. part.content_type)
            table.insert(lines, "")
            table.insert(lines, part.data)
        else
            table.insert(lines, string.format(
                'Content-Disposition: form-data; name="%s"',
                part.name
            ))
            table.insert(lines, "")
            table.insert(lines, part.value)
        end

        table.insert(segments, table.concat(lines, "\r\n"))
    end

    table.insert(segments, "--" .. boundary .. "--")
    local body = table.concat(segments, "\r\n") .. "\r\n"
    local content_type = "multipart/form-data; boundary=" .. boundary

    return body, content_type
end

return Multipart
