local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

describe("stt_tts app", function()
    local App
    local app_config
    local number

    lester.before(function()
        turn.test.reset()
        package.loaded["stt_tts"] = nil
        package.loaded["stt_tts.transcribe"] = nil
        package.loaded["stt_tts.speak"] = nil
        package.loaded["stt_tts.multipart"] = nil

        App = require("stt_tts")

        app_config = {
            uuid = "test-stt-tts-uuid",
            config = {}
        }

        number = {
            id = "123",
            uuid = "test-number-uuid"
        }

        turn.test.set_config({
            stt_api_url = "https://api.openai.com/v1/audio/transcriptions",
            stt_api_key = "test-key",
            stt_model = "whisper-1",
            tts_api_url = "https://api.openai.com/v1/audio/speech",
            tts_api_key = "test-key",
            tts_model = "tts-1",
            tts_voice = "alloy",
            default_language = "en",
        })
    end)

    describe("install event", function()
        it("returns true", function()
            local result = App.on_event(app_config, number, "install", {})
            expect.equal(result, true)
        end)

        it("seeds default config when none exists", function()
            turn.app.set_config({})

            App.on_event(app_config, number, "install", {})

            local config = turn.app.get_config()
            expect.equal(config.stt_api_url, "https://api.openai.com/v1/audio/transcriptions")
            expect.equal(config.stt_model, "whisper-1")
            expect.equal(config.tts_api_url, "https://api.openai.com/v1/audio/speech")
            expect.equal(config.tts_model, "tts-1")
            expect.equal(config.tts_voice, "alloy")
            expect.equal(config.default_language, "en")
        end)

        it("preserves existing config", function()
            turn.test.set_config({
                stt_api_url = "https://custom-stt.example.com",
                stt_api_key = "my-real-key",
                stt_model = "whisper-1",
                tts_api_url = "https://custom-tts.example.com",
                tts_api_key = "my-real-key",
                tts_model = "tts-1",
                tts_voice = "shimmer",
                default_language = "rw",
            })

            App.on_event(app_config, number, "install", {})

            local config = turn.app.get_config()
            expect.equal(config.stt_api_url, "https://custom-stt.example.com")
            expect.equal(config.tts_voice, "shimmer")
            expect.equal(config.default_language, "rw")
        end)

        it("returns false when manifest.json cannot be loaded", function()
            local original_load = turn.assets.load
            turn.assets.load = function() return nil end

            local result = App.on_event(app_config, number, "install", {})
            expect.equal(result, false)

            turn.assets.load = original_load
        end)
    end)

    describe("journey_event - transcribe", function()
        it("routes to transcribe function", function()
            local _, media_info = turn.media.save({
                data = "fake-audio",
                filename = "audio.ogg",
                content_type = "audio/ogg",
            })

            turn.test.mock_http("mock%-storage.turn.io/attachments/", {
                method = "GET",
                status = 200,
                body = "fake-audio",
            })

            turn.test.mock_http("api.openai.com/v1/audio/transcriptions", {
                method = "POST",
                status = 200,
                body = turn.json.encode({ text = "Hello" }),
            })

            local action, result = App.on_event(app_config, number, "journey_event", {
                function_name = "transcribe",
                args = { media_info.external_id },
            })

            expect.equal(action, "continue")
            expect.equal(result.text, "Hello")
        end)
    end)

    describe("journey_event - speak", function()
        it("routes to speak function", function()
            turn.test.mock_http("api.openai.com/v1/audio/speech", {
                method = "POST",
                status = 200,
                body = "fake-opus-audio",
            })

            local action, result = App.on_event(app_config, number, "journey_event", {
                function_name = "speak",
                args = { "Hello world" },
            })

            expect.equal(action, "continue")
            expect.truthy(result.media_id)
            expect.equal(result.content_type, "audio/opus")
        end)
    end)

    describe("journey_event - unknown function", function()
        it("returns error for unknown function", function()
            local action, result = App.on_event(app_config, number, "journey_event", {
                function_name = "unknown_function",
                args = {},
            })

            expect.equal(action, "error")
            expect.truthy(result:find("Unknown function"))
        end)
    end)

    describe("uninstall event", function()
        it("returns true", function()
            local result = App.on_event(app_config, number, "uninstall", {})
            expect.equal(result, true)
        end)

        it("returns true even when manifest.json is missing", function()
            local original_load = turn.assets.load
            turn.assets.load = function() return nil end

            local result = App.on_event(app_config, number, "uninstall", {})
            expect.equal(result, true)

            turn.assets.load = original_load
        end)
    end)

    describe("get_app_info_markdown", function()
        it("returns README content", function()
            local result = App.on_event(app_config, number, "get_app_info_markdown", {})
            expect.truthy(result)
            expect.truthy(type(result) == "string")
        end)

        it("returns fallback when README is missing", function()
            local original_load = turn.assets.load
            turn.assets.load = function() return nil end

            local result = App.on_event(app_config, number, "get_app_info_markdown", {})
            expect.equal(result, "# STT/TTS App")

            turn.assets.load = original_load
        end)
    end)

    describe("unknown events", function()
        it("returns true gracefully", function()
            local result = App.on_event(app_config, number, "some_future_event", {})
            expect.equal(result, true)
        end)
    end)
end)

lester.report()
lester.exit()
