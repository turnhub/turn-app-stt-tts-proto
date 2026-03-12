local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

describe("speak", function()
    local speak

    local config = {
        tts_api_url = "https://v3-api-develop.proto.cx/api/platform/v1/voice/01JTEST/tts",
        tts_api_key = "test-key",
        tts_gender = "female",
        default_language = "en",
    }

    lester.before(function()
        turn.test.reset()
        package.loaded["stt_tts_proto.speak"] = nil
        speak = require("stt_tts_proto.speak")
    end)

    it("converts text to audio and returns media_id", function()
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = "fake-audio-binary",
        })

        local action, result = speak({ "Hello world" }, config)

        expect.equal(action, "continue")
        expect.truthy(result.media_id)
        expect.equal(result.content_type, "audio/mpeg")
    end)

    it("uses gender from argument over config default", function()
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Hello", "male" }, config)

        local requests = turn.test.get_http_requests("v3%-api%-develop%.proto%.cx")
        expect.equal(#requests, 1)
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.gender, "male")
    end)

    it("uses config default gender when not specified", function()
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Hello" }, config)

        local requests = turn.test.get_http_requests("v3%-api%-develop%.proto%.cx")
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.gender, "female")
    end)

    it("sends correct request body to TTS API", function()
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
            method = "POST",
            status = 200,
            body = "fake-audio",
        })

        speak({ "Say this" }, config)

        local requests = turn.test.get_http_requests("v3%-api%-develop%.proto%.cx")
        local body = turn.json.decode(requests[1].body)
        expect.equal(body.text, "Say this")
        expect.equal(body.lang, "en")
        expect.equal(body.gender, "female")
        expect.equal(body.response_format, "mp3")
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
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
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
        turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
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
