local turn = require("turn")

--- Perform an HTTP request with up to max_retries retries and exponential backoff.
-- Retries on Lua errors (e.g. timeout) or HTTP 5xx/429 responses.
-- Re-raises the error after all retries are exhausted so the platform fallback triggers.
-- @param params table turn.http.request params
-- @param max_retries number number of retries (default 0 = no retries)
-- @param log_err function optional function(msg) for error logging
-- @return response, status
local function http_with_retry(params, max_retries, log_err)
    max_retries = max_retries or 0
    local attempt = 0
    while true do
        attempt = attempt + 1
        if log_err then log_err("HTTP " .. params.method .. " " .. params.url .. " attempt " .. attempt .. " starting") end
        local t0 = os.clock()
        local ok, response, status = pcall(turn.http.request, params)
        local elapsed_ms = string.format("%.2f", (os.clock() - t0) * 1000)
        if not ok then
            local err_msg = tostring(response)
            if log_err then log_err("[retry] HTTP " .. params.method .. " " .. params.url .. " attempt " .. attempt .. " caught error: " .. err_msg) end
            if attempt > max_retries then
                error(err_msg)
            end
            local delay = 2 ^ (attempt - 1)
            if log_err then log_err("HTTP error (attempt " .. attempt .. "/" .. max_retries .. "): " .. err_msg .. " - retrying in " .. delay .. "s") end
            local t = os.time()
            while os.time() < t + delay do end
        elseif status == 429 or status >= 500 then
            if attempt > max_retries then
                if log_err then log_err("HTTP failed after " .. attempt .. " attempts - HTTP " .. status) end
                return response, status
            end
            local delay = 2 ^ (attempt - 1)
            if log_err then log_err("HTTP " .. status .. " (attempt " .. attempt .. "/" .. max_retries .. ") - retrying in " .. delay .. "s") end
            local t = os.time()
            while os.time() < t + delay do end
        else
            return response, status
        end
    end
end

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
    local response, status = http_with_retry({
        url = config.tts_api_url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. config.tts_api_key,
            ["Content-Type"] = "application/json",
        },
        body = turn.json.encode(request_body),
        timeout = 15000,
    }, config.number_of_retries, turn.logger.error)

    if status ~= 200 then
        turn.logger.error("TTS API error: HTTP " .. tostring(status) .. " - " .. tostring(response))
        return "continue", {
            success = false,
            error = "tts_api_error",
            message = "TTS API returned HTTP " .. tostring(status)
        }
    end

    -- 3. Use raw binary audio from response
    local audio_data = response

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
        success = true,
        media_id = media_info.external_id,
        content_type = "audio/mpeg",
    }
end

return speak
