local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

describe("transcribe", function()
    local transcribe

    local config = {
        stt_api_url = "https://api.openai.com/v1/audio/transcriptions",
        stt_api_key = "test-key",
        stt_model = "whisper-1",
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
        turn.test.reset()
        package.loaded["stt_tts.transcribe"] = nil
        package.loaded["stt_tts.multipart"] = nil
        transcribe = require("stt_tts.transcribe")
    end)

    it("transcribes audio from a media attachment", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio-binary",
        })

        turn.test.mock_http("api.openai.com/v1/audio/transcriptions", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ text = "Hello world" }),
        })

        local action, result = transcribe({ media_id }, config)

        expect.equal(action, "continue")
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

        turn.test.mock_http("api.openai.com/v1/audio/transcriptions", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ text = "Muraho" }),
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

    it("returns error when STT API fails", function()
        local media_id = create_mock_media()

        turn.test.mock_http("mock%-storage.turn.io/attachments/", {
            method = "GET",
            status = 200,
            body = "fake-audio",
        })

        turn.test.mock_http("api.openai.com/v1/audio/transcriptions", {
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

        turn.test.mock_http("api.openai.com/v1/audio/transcriptions", {
            method = "POST",
            status = 200,
            body = turn.json.encode({ text = "test" }),
        })

        transcribe({ media_id }, config)

        local requests = turn.test.get_http_requests("api.openai.com")
        expect.equal(#requests, 1)
        expect.equal(requests[1].headers["Authorization"], "Bearer test-key")
        expect.truthy(requests[1].headers["Content-Type"]:find("multipart/form%-data"))
    end)
end)

lester.report()
lester.exit()
