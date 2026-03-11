local Multipart = require("stt_tts.multipart")
local turn = require("turn")

--- Transcribe audio from a media attachment using a configured STT API.
-- @param args table Journey function arguments: {media_id, [language]}
-- @param config table App configuration with stt_api_url, stt_api_key, audio_convert_url, default_language
-- @return string Action signal ("continue")
-- @return table Result with text and language, or error details
local function transcribe(args, config)
    local media_id = args[1]
    local language = args[2] or config.default_language

    if not media_id then
        return "continue", {
            success = false,
            error = "missing_argument",
            message = "media_id is required"
        }
    end

    if not config.stt_api_url or not config.stt_api_key then
        return "continue", {
            success = false,
            error = "missing_config",
            message = "stt_api_url and stt_api_key must be configured"
        }
    end

    -- 1. Get a signed URL for the media attachment
    local audio_url, url_ok = turn.media.signed_url(media_id)
    if not url_ok then
        return "continue", {
            success = false,
            error = "signed_url_failed",
            message = "Failed to get signed URL: " .. tostring(audio_url)
        }
    end

    -- 2. Download audio from the signed URL
    local audio_data, download_status = turn.http.request({
        url = audio_url,
        method = "GET"
    })

    if download_status ~= 200 then
        return "continue", {
            success = false,
            error = "download_failed",
            message = "Failed to download audio: HTTP " .. tostring(download_status)
        }
    end

    -- 3. Convert OGG to MP3 via conversion worker
    local mp3_data, convert_status = turn.http.request({
        url = config.audio_convert_url .. "?to=mp3" .. (config.audio_convert_secret and ("&secret=" .. config.audio_convert_secret) or ""),
        method = "POST",
        body = audio_data,
    })

    if convert_status ~= 200 then
        return "continue", {
            success = false,
            error = "convert_failed",
            message = "Audio conversion failed: HTTP " .. tostring(convert_status)
        }
    end

    -- 4. Build multipart body for STT API
    local parts = {
        { name = "file", filename = "audio.mp3", content_type = "audio/mpeg", data = mp3_data },
    }

    if language then
        table.insert(parts, { name = "lang", value = language })
    end

    local body, content_type = Multipart.build(parts)

    -- 5. POST to STT API
    local response, stt_status = turn.http.request({
        url = config.stt_api_url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. config.stt_api_key,
            ["Content-Type"] = content_type,
        },
        body = body,
    })

    if stt_status ~= 200 then
        turn.logger.error("STT API error: HTTP " .. tostring(stt_status) .. " - " .. tostring(response))
        return "continue", {
            success = false,
            error = "stt_api_error",
            message = "STT API returned HTTP " .. tostring(stt_status)
        }
    end

    local result = turn.json.decode(response)

    return "continue", {
        text = result.transcription.transcription,
        language = language,
    }
end

return transcribe
