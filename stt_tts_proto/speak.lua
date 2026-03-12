local turn = require("turn")

--- Convert text to speech using a configured TTS API.
-- @param args table Journey function arguments: {text, [gender]}
-- @param config table App configuration with tts_api_url, tts_api_key, tts_gender, default_language
-- @return string Action signal ("continue")
-- @return table Result with media_id and content_type, or error details
local function speak(args, config)
    local text = args[1]
    local gender = args[2] or config.tts_gender or "female"

    if not text then
        return "continue", {
            success = false,
            error = "missing_argument",
            message = "text is required"
        }
    end

    if not config.tts_api_url or not config.tts_api_key then
        return "continue", {
            success = false,
            error = "missing_config",
            message = "tts_api_url and tts_api_key must be configured"
        }
    end

    -- 1. Build request body
    local request_body = {
        text = text,
        lang = config.default_language or "en",
        response_format = "mp3",
        gender = gender,
    }

    if config.tts_speed then
        request_body.speed = config.tts_speed
    end

    -- 2. POST text to TTS API
    local response, status = turn.http.request({
        url = config.tts_api_url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. config.tts_api_key,
            ["Content-Type"] = "application/json",
        },
        body = turn.json.encode(request_body),
    })

    if status ~= 200 then
        turn.logger.error("TTS API error: HTTP " .. tostring(status) .. " - " .. tostring(response))
        return "continue", {
            success = false,
            error = "tts_api_error",
            message = "TTS API returned HTTP " .. tostring(status)
        }
    end

    -- 3. Decode base64 audio from JSON response
    local response_json = turn.json.decode(response)
    local audio_data = turn.encoding.base64_decode(response_json.content)

    -- 4. Save audio as platform media
    local save_success, media_info = turn.media.save({
        data = audio_data,
        filename = "speech.mp3",
        content_type = "audio/mpeg",
    })

    if not save_success then
        return "continue", {
            success = false,
            error = "media_save_failed",
            message = "Failed to save audio: " .. tostring(media_info)
        }
    end

    return "continue", {
        media_id = media_info.external_id,
        content_type = "audio/mpeg",
    }
end

return speak
