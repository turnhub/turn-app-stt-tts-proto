local turn = require("turn")
local lester = require("lester")
local describe, it, expect = lester.describe, lester.it, lester.expect

describe("Multipart", function()
    local Multipart

    lester.before(function()
        package.loaded["stt_tts.multipart"] = nil
        Multipart = require("stt_tts.multipart")
    end)

    it("builds multipart body with field parts", function()
        local body, content_type = Multipart.build({
            { name = "model", value = "whisper-1" },
            { name = "language", value = "en" },
        })

        expect.truthy(body:find("model"))
        expect.truthy(body:find("whisper%-1"))
        expect.truthy(body:find("language"))
        expect.truthy(body:find("en"))
        expect.truthy(content_type:find("multipart/form%-data; boundary="))
    end)

    it("builds multipart body with file parts", function()
        local body, content_type = Multipart.build({
            { name = "file", filename = "audio.ogg", content_type = "audio/ogg", data = "fake-audio-data" },
            { name = "model", value = "whisper-1" },
        })

        expect.truthy(body:find('filename="audio.ogg"'))
        expect.truthy(body:find("Content%-Type: audio/ogg"))
        expect.truthy(body:find("fake%-audio%-data"))
        expect.truthy(body:find("whisper%-1"))
    end)

    it("includes closing boundary", function()
        local body, content_type = Multipart.build({
            { name = "key", value = "val" },
        })

        local boundary = content_type:match("boundary=(.*)")
        expect.truthy(body:find("--" .. boundary .. "--", 1, true))
    end)

    it("returns content_type with boundary", function()
        local _, ct = Multipart.build({ { name = "a", value = "b" } })
        local boundary = ct:match("boundary=(.*)")

        expect.truthy(boundary)
        expect.truthy(#boundary > 10)
    end)

    it("handles mixed file and field parts", function()
        local body, _ = Multipart.build({
            { name = "file", filename = "test.wav", content_type = "audio/wav", data = "wav-data" },
            { name = "model", value = "whisper-1" },
            { name = "language", value = "rw" },
        })

        expect.truthy(body:find('filename="test.wav"'))
        expect.truthy(body:find("wav%-data"))
        expect.truthy(body:find("whisper%-1"))
        expect.truthy(body:find("rw"))
    end)
end)

lester.report()
lester.exit()
