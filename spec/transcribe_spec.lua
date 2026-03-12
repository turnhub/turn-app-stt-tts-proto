local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

-- Capture original save before any overrides
local sdk_media_save = turn.media.save

describe("transcribe", function()
    local transcribe
    local mock_media_ids  -- local Lua table avoids Luerl _stores key quirk

    local config = {
        stt_api_url = "https://v3-api-develop.proto.cx/api/platform/v1/voice/01JTEST/asr",
        stt_api_key = "test-key",
        audio_convert_url = "https://your-worker.workers.dev",
        audio_convert_secret = "test-secret",
        default_language = "en",
    }

    --- Save a mock media entry and return the external_id for use with signed_url.
    local function create_mock_media()
        local ok, info = turn.media.save({
            data = "fake-audio-binary",
            filename = "audio.ogg",
            content_type = "audio/ogg",
        })
        return info.external_id
    end

    lester.before(function()
        mock_media_ids = {}
        turn.media.save = function(request)
            local ok, info = sdk_media_save(request)
            if ok and info then mock_media_ids[info.external_id] = true end
            return ok, info
        end
        turn.media.signed_url = function(external_id)
            if not mock_media_ids[external_id] then
                return "Media not found: " .. tostring(external_id), false
            end
            return "https://mock-storage.turn.io/attachments/1", true
        end
        turn.test.reset()
        package.loaded["stt_tts_proto.transcribe"] = nil
        package.loaded["stt_tts_proto.multipart"] = nil
        transcribe = require("stt_tts_proto.transcribe")
    end)

    it("transcribes audio from a media attachment", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio-binary",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 200,
            body = "fake-mp3-binary",
        })

        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ transcription = { transcription = "Hello world" }, lang = "en" }),
        })

        local action, result = transcribe({ media_id }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, true)
        expect.equal(result.text, "Hello world")
        expect.equal(result.language, "en")
    end)

    it("passes explicit language parameter", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 200,
            body = "fake-mp3-binary",
        })

        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ transcription = { transcription = "Muraho" }, lang = "rw" }),
        })

        local action, result = transcribe({ media_id, "rw" }, config)

        expect.equal(result.text, "Muraho")
        expect.equal(result.language, "rw")
    end)

    it("returns error when media_id is missing", function()
        local action, result = transcribe({}, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "missing_argument")
    end)

    it("returns error when config is missing", function()
        local media_id = create_mock_media()
        local action, result = transcribe({ media_id }, {})

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "missing_config")
    end)

    it("returns error when media attachment is not found", function()
        local action, result = transcribe({ "nonexistent-media-id" }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "signed_url_failed")
    end)

    it("returns error when audio download fails", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 404,
            body = "Not Found",
        })

        local action, result = transcribe({ media_id }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "download_failed")
    end)

    it("returns error when audio conversion fails", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 500,
            body = "Internal Server Error",
        })

        local action, result = transcribe({ media_id }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "convert_failed")
        expect.truthy(result.message:find("500"))
    end)

    it("returns error when STT API fails", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 200,
            body = "fake-mp3-binary",
        })

        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 429,
            body = "Rate limited",
        })

        local action, result = transcribe({ media_id }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "stt_api_error")
        expect.truthy(result.message:find("429"))
    end)

    it("sends correct headers to STT API", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 200,
            body = "fake-mp3-binary",
        })

        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ transcription = { transcription = "test" }, lang = "en" }),
        })

        transcribe({ media_id }, config)

        local requests = turn.test.get_http_requests("v3%-api%-develop%.proto%.cx")
        expect.equal(#requests, 1)
        expect.equal(requests[1].headers["Authorization"], "Bearer test-key")
        expect.truthy(requests[1].headers["Content-Type"]:find("multipart/form%-data"))
    end)

    it("includes secret in conversion worker URL", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("your%-worker.workers.dev", {
            method = "POST",
            status = 200,
            body = "fake-mp3-binary",
        })

        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ transcription = { transcription = "test" }, lang = "en" }),
        })

        transcribe({ media_id }, config)

        local requests = turn.test.get_http_requests("your%-worker%.workers%.dev")
        expect.equal(#requests, 1)
        expect.truthy(requests[1].url:find("secret=test-secret", 1, true))
    end)
end)

lester.report()
lester.exit()
