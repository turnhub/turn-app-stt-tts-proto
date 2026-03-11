local turn = require("turn")
local base64 = require("stt_tts.base64")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

-- Capture original save before any overrides
local sdk_media_save = turn.media.save

describe("stt_tts app", function()
    local App
    local app_config
    local number
    local mock_media_ids  -- local Lua table avoids Luerl _stores key quirk

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
        package.loaded["stt_tts"] = nil
        package.loaded["stt_tts.transcribe"] = nil
        package.loaded["stt_tts.speak"] = nil
        package.loaded["stt_tts.multipart"] = nil
        package.loaded["stt_tts.base64"] = nil

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
            stt_api_url = "https://v3-api-develop.proto.cx/api/platform/v1/voice/01JTEST/asr",
            stt_api_key = "test-key",
            tts_api_url = "https://v3-api-develop.proto.cx/api/platform/v1/voice/01JTEST/tts",
            tts_api_key = "test-key",
            tts_gender = "female",
            default_language = "en",
            audio_convert_url = "https://your-worker.workers.dev",
            audio_convert_secret = "test-secret",
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
            expect.equal(config.tts_gender, "female")
            expect.equal(config.default_language, "en")
            expect.equal(config.audio_convert_url, "https://ogg-to-mp3.arjunkhoosal.workers.dev")
        end)

        it("preserves existing config", function()
            turn.test.set_config({
                stt_api_url = "https://custom-stt.example.com",
                stt_api_key = "my-real-key",
                tts_api_url = "https://custom-tts.example.com",
                tts_api_key = "my-real-key",
                tts_gender = "male",
                default_language = "rw",
                audio_convert_url = "https://my-converter.example.com",
            })

            App.on_event(app_config, number, "install", {})

            local config = turn.app.get_config()
            expect.equal(config.stt_api_url, "https://custom-stt.example.com")
            expect.equal(config.tts_gender, "male")
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

            turn.test.mock_http("your%-worker.workers.dev", {
                method = "POST",
                status = 200,
                body = "fake-mp3-binary",
            })

            turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
                method = "POST",
                status = 200,
                body = turn.json.encode({ transcription = { transcription = "Hello" }, lang = "en" }),
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
            turn.test.mock_http("v3%-api%-develop%.proto%.cx", {
                method = "POST",
                status = 200,
                body = turn.json.encode({ content = base64.encode("fake-mp3-audio") }),
            })

            local action, result = App.on_event(app_config, number, "journey_event", {
                function_name = "speak",
                args = { "Hello world" },
            })

            expect.equal(action, "continue")
            expect.truthy(result.media_id)
            expect.equal(result.content_type, "audio/mpeg")
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
