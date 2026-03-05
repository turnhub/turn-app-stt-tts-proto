local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

describe("speak", function()
    local speak

    local config = {
        tts_api_url = "https://api.openai.com/v1/audio/speech",
        tts_api_key = "test-key",
        tts_model = "tts-1",
        tts_voice = "alloy",
    }

    lester.before(function()
        turn.test.reset()
        package.loaded["stt_tts.speak"] = nil
        speak = require("stt_tts.speak")
    end)

    it("converts text to audio and returns media_id", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 200,
            body = "fake-opus-audio-binary",
        })

        local action, result = speak({ "Hello world" }, config)

        expect.equal(action, "continue")
        expect.truthy(result.media_id)
        expect.equal(result.content_type, "audio/opus")
    end)

    it("uses voice from argument over config default", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Hello", "nova" }, config)

        local requests = turn.test.get_http_requests("api.openai.com")
        expect.equal(#requests, 1)
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.voice, "nova")
    end)

    it("uses config default voice when not specified", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Hello" }, config)

        local requests = turn.test.get_http_requests("api.openai.com")
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.voice, "alloy")
    end)

    it("sends correct request body to TTS API", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Say this" }, config)

        local requests = turn.test.get_http_requests("api.openai.com")
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.model, "tts-1")
        expect.equal(body.input, "Say this")
        expect.equal(body.response_format, "opus")
    end)

    it("returns error when text is missing", function()
        local action, result = speak({}, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "missing_argument")
    end)

    it("returns error when config is missing", function()
        local action, result = speak({ "Hello" }, {})

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "missing_config")
    end)

    it("returns error when media save fails", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        local original_save = turn.media.save
        turn.media.save = function() return false, "Storage unavailable" end

        local action, result = speak({ "Hello" }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "media_save_failed")

        turn.media.save = original_save
    end)

    it("returns error when TTS API fails", function()
        turn.test.mock_http("api.openai.com/v1/audio/speech", {
            method = "POST",
            status = 500,
            body = "Internal Server Error",
        })

        local action, result = speak({ "Hello" }, config)

        expect.equal(action, "continue")
        expect.equal(result.success, false)
        expect.equal(result.error, "tts_api_error")
        expect.truthy(result.message:find("500"))
    end)
end)

lester.report()
lester.exit()
