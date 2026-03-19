local Multipart = require("stt_tts_proto.multipart")
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

--- Create a scoped logger that prepends a function name and random request ID to every message.
-- @param func_name string The name of the function being logged
-- @return table Logger with info() and error() methods
local function make_logger(func_name)
    local request_id = math.random(100000, 999999)
    local prefix = "[" .. func_name .. "][" .. request_id .. "] "
    return {
        info = function(msg) turn.logger.info(prefix .. msg) end,
        error = function(msg) turn.logger.error(prefix .. msg) end,
    }
end

--- Estimate duration (seconds) of a CBR MP3 from its raw bytes by reading the frame header.
-- Returns nil if the data doesn't look like a valid MP3 frame.
local function estimate_mp3_duration(data)
    if not data or #data < 4 then return nil end
    local b0, b1, b2 = data:byte(1), data:byte(2), data:byte(3)
    if b0 ~= 0xFF or b1 < 0xE0 then return nil end  -- sync word check
    local bitrate_index = math.floor(b2 / 16)  -- upper 4 bits of byte 3
    local bitrates = {0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320}
    local bitrate_kbps = bitrates[bitrate_index + 1]
    if not bitrate_kbps or bitrate_kbps == 0 then return nil end
    return (#data * 8) / (bitrate_kbps * 1000)
end

--- Transcribe audio from a media attachment using a configured STT API.
-- @param args table Journey function arguments: {media_id, [language]}
-- @param config table App configuration with stt_api_url, stt_api_key, audio_convert_url, default_language
-- @return string Action signal ("continue")
-- @return table Result with text and language, or error details
local function transcribe(args, config)
    local log = make_logger("transcribe")
    log.info("starting")
    log.info("args = " .. turn.json.encode(args))

    local media_id = args[1]
    local language = args[2] or config.default_language

    log.info("media_id = " .. tostring(media_id))
    log.info("language = " .. tostring(language))
    log.info("stt_api_url = " .. tostring(config.stt_api_url))
    log.info("audio_convert_url = " .. tostring(config.audio_convert_url))
    log.info("stt_api_key present = " .. tostring(config.stt_api_key ~= nil))

    if not media_id then
        log.error("missing media_id argument")
        return "continue", {
            success = false,
            error = "missing_argument",
            message = "media_id is required"
        }
    end

    if not config.stt_api_url or not config.stt_api_key then
        log.error("missing config - stt_api_url=" .. tostring(config.stt_api_url) .. " stt_api_key present=" .. tostring(config.stt_api_key ~= nil))
        return "continue", {
            success = false,
            error = "missing_config",
            message = "stt_api_url and stt_api_key must be configured"
        }
    end

    -- 1. Get a signed URL for the media attachment
    log.info("step 1 - getting signed URL for media_id=" .. tostring(media_id))
    local audio_url, url_ok = turn.media.signed_url(media_id)
    log.info("signed_url result - url_ok=" .. tostring(url_ok) .. " audio_url=" .. tostring(audio_url))
    if not url_ok then
        log.error("failed to get signed URL - " .. tostring(audio_url))
        return "continue", {
            success = false,
            error = "signed_url_failed",
            message = "Failed to get signed URL: " .. tostring(audio_url)
        }
    end

    -- 2. Download audio from the signed URL
    log.info("step 2 - downloading audio from signed URL")
    local audio_data, download_status = http_with_retry({
        url = audio_url,
        method = "GET",
        timeout = 15000,
    }, config.number_of_retries, log.error)
    log.info("download result - status=" .. tostring(download_status) .. " data_length=" .. tostring(audio_data and #audio_data or "nil"))

    if download_status ~= 200 then
        log.error("audio download failed - HTTP " .. tostring(download_status) .. " response=" .. tostring(audio_data))
        return "continue", {
            success = false,
            error = "download_failed",
            message = "Failed to download audio: HTTP " .. tostring(download_status)
        }
    end

    -- 3. Convert Opus to MP3 via conversion worker
    local convert_url = config.audio_convert_url .. "?to=mp3" .. (config.audio_convert_secret and ("&secret=" .. config.audio_convert_secret) or "")
    log.info("step 3 - converting audio via " .. tostring(config.audio_convert_url) .. " (input size=" .. tostring(#audio_data) .. " bytes)")
    local mp3_data, convert_status = http_with_retry({
        url = convert_url,
        method = "POST",
        body = audio_data,
        timeout = 15000,
    }, config.number_of_retries, log.error)
    local mp3_len = mp3_data and #mp3_data or 0
    local ogg_len = #audio_data
    local mp3_estimated_secs = estimate_mp3_duration(mp3_data)
    log.info("conversion result - status=" .. tostring(convert_status) .. " ogg_bytes=" .. tostring(ogg_len) .. " mp3_bytes=" .. tostring(mp3_len) .. " mp3_estimated_secs=" .. (mp3_estimated_secs and string.format("%.2f", mp3_estimated_secs) or "nil") .. " ratio=" .. string.format("%.2f", mp3_len > 0 and (mp3_len / ogg_len) or 0))
    if mp3_data and #mp3_data >= 3 then
        log.info("mp3 header bytes (hex) = " .. string.format("%02X %02X %02X", mp3_data:byte(1), mp3_data:byte(2), mp3_data:byte(3)))
    end

    if convert_status ~= 200 then
        log.error("audio conversion failed - HTTP " .. tostring(convert_status) .. " response=" .. tostring(mp3_data))
        return "continue", {
            success = false,
            error = "convert_failed",
            message = "Audio conversion failed: HTTP " .. tostring(convert_status)
        }
    end

    -- 4. Build multipart body for STT API
    log.info("step 4 - building multipart body")
    local parts = {
        { name = "file", filename = "audio.mp3", content_type = "audio/mpeg", data = mp3_data },
    }

    if language then
        log.info("adding language part - lang=" .. tostring(language))
        table.insert(parts, { name = "lang", value = language })
    end

    local body, content_type = Multipart.build(parts)
    log.info("multipart body built - content_type=" .. tostring(content_type) .. " body_length=" .. tostring(body and #body or "nil"))

    -- 5. POST to STT API
    log.info("step 5 - posting to STT API at " .. tostring(config.stt_api_url))
    local response, stt_status = http_with_retry({
        url = config.stt_api_url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. config.stt_api_key,
            ["Content-Type"] = content_type,
        },
        body = body,
        timeout = 15000,
    }, config.number_of_retries, log.error)
    log.info("STT API result - status=" .. tostring(stt_status) .. " response_length=" .. tostring(response and #response or "nil"))

    if stt_status ~= 200 then
        log.error("STT API error: HTTP " .. tostring(stt_status) .. " - " .. tostring(response))
        return "continue", {
            success = false,
            error = "stt_api_error",
            message = "STT API returned HTTP " .. tostring(stt_status)
        }
    end

    log.info("step 6 - decoding JSON response")
    log.info("raw response = " .. tostring(response))
    local result = turn.json.decode(response)
    log.info("decoded result = " .. turn.json.encode(result))

    local transcription_text = result.transcription.transcription
    local audio_length = result.transcription.audio_length
    log.info("audio durations - ogg_download_bytes=" .. tostring(ogg_len) .. " mp3_bytes=" .. tostring(mp3_len) .. " audio_length_secs=" .. tostring(audio_length) .. " file_size_reported=" .. tostring(result.file_size))
    log.info("success - transcription chars=" .. tostring(transcription_text and #transcription_text or "nil") .. " language=" .. tostring(language))
    log.info("transcription text = " .. tostring(transcription_text))

    return "continue", {
        success = true,
        text = transcription_text,
        language = language,
    }
end

return transcribe
