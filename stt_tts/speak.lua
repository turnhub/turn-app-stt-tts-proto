local turn = require("turn")

--- Convert text to speech using a configured TTS API.
-- @param args table Journey function arguments: {text, [voice]}
-- @param config table App configuration with tts_api_url, tts_api_key, tts_model, tts_voice
-- @return string Action signal ("continue")
-- @return table Result with media_id and content_type, or error details
local function speak(args, config)
    local text = args[1]
    local voice = args[2] or config.tts_voice or "alloy"

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

    -- 1. POST text to TTS API
    local audio_data, status = turn.http.request({
        url = config.tts_api_url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. config.tts_api_key,
            ["Content-Type"] = "application/json",
        },
        body = turn.json.encode({
            model = config.tts_model or "tts-1",
            input = text,
            voice = voice,
            response_format = "opus",
        }),
    })

    if status ~= 200 then
        turn.logger.error("TTS API error: HTTP " .. tostring(status) .. " - " .. tostring(audio_data))
        return "continue", {
            success = false,
            error = "tts_api_error",
            message = "TTS API returned HTTP " .. tostring(status)
        }
    end

    -- 2. Save audio as platform media
    local save_success, media_info = turn.media.save({
        data = audio_data,
        filename = "speech.opus",
        content_type = "audio/opus",
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
        content_type = "audio/opus",
    }
end

return speak
