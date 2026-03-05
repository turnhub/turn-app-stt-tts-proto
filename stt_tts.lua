local App = {}
local turn = require("turn")

function App.on_event(app, number, event, data)
    if event == "install" then
        -- Seed default config if none exists yet
        local config = turn.app.get_config()
        if not config or not config.stt_api_url then
            turn.app.set_config({
                stt_api_url = "https://api.openai.com/v1/audio/transcriptions",
                stt_api_key = "",
                stt_model = "whisper-1",
                tts_api_url = "https://api.openai.com/v1/audio/speech",
                tts_api_key = "",
                tts_model = "tts-1",
                tts_voice = "alloy",
                default_language = "en",
            })
            turn.logger.info("STT/TTS: Seeded default config — set stt_api_key and tts_api_key to activate")
        end

        -- Install journeys and other manifest resources
        local manifest_json = turn.assets.load("manifest.json")
        if not manifest_json then
            turn.logger.error("STT/TTS: Failed to load manifest.json")
            return false
        end

        local manifest = turn.json.decode(manifest_json)
        if not manifest then
            turn.logger.error("STT/TTS: Failed to decode manifest.json")
            return false
        end

        local ok, results = pcall(turn.manifest.install, manifest)
        if not ok then
            turn.logger.error("STT/TTS: Installation error: " .. tostring(results))
            return false
        end

        if results.journeys then
            turn.logger.info("STT/TTS: Journeys installed: " .. results.journeys.created .. "/" .. results.journeys.total)
        end

        return results.success

    elseif event == "uninstall" then
        local manifest_json = turn.assets.load("manifest.json")
        if not manifest_json then
            return true
        end

        local manifest = turn.json.decode(manifest_json)
        if not manifest then
            return true
        end

        local ok, results = pcall(turn.manifest.uninstall, manifest)
        if ok and results then
            turn.logger.info("STT/TTS: Uninstall complete")
        end

        return true

    elseif event == "journey_event" then
        local config = turn.app.get_config() or {}

        if data.function_name == "transcribe" then
            local transcribe = require("stt_tts.transcribe")
            return transcribe(data.args, config)
        elseif data.function_name == "speak" then
            local speak = require("stt_tts.speak")
            return speak(data.args, config)
        else
            return "error", "Unknown function: " .. tostring(data.function_name)
        end

    elseif event == "get_app_info_markdown" then
        local readme = turn.assets.load("README.md")
        return readme or "# STT/TTS App"

    else
        return true
    end
end

return App
