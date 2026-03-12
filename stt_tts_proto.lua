local App = {}
local turn = require("turn")

function App.on_event(app, number, event, data)
    if event == "install" then
        -- Always call set_config on install so the platform registers field definitions.
        -- Existing user-set values are preserved; only missing keys get defaults.
        local config = turn.app.get_config() or {}
        turn.app.set_config({
            stt_api_url = config.stt_api_url or "",
            stt_api_key = config.stt_api_key or "",
            tts_api_url = config.tts_api_url or "",
            tts_api_key = config.tts_api_key or "",
            tts_gender = config.tts_gender or "female",
            default_language = config.default_language or "en",
            audio_convert_url = config.audio_convert_url or "https://ogg-to-mp3.arjunkhoosal.workers.dev",
            audio_convert_secret = config.audio_convert_secret or "",
        })
        turn.logger.info("STT/TTS: Config initialised")

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
            local transcribe = require("stt_tts_proto.transcribe")
            return transcribe(data.args, config)
        elseif data.function_name == "speak" then
            local speak = require("stt_tts_proto.speak")
            return speak(data.args, config)
        else
            return "error", "Unknown function: " .. tostring(data.function_name)
        end

    elseif event == "upgrade" then
        turn.logger.info("STT/TTS: Upgrading from " .. tostring(data.from_version) .. " to " .. tostring(data.to_version))
        return true

    elseif event == "downgrade" then
        turn.logger.info("STT/TTS: Downgrading from " .. tostring(data.from_version) .. " to " .. tostring(data.to_version))
        return true

    elseif event == "get_app_info_markdown" then
        local readme = turn.assets.load("README.md")
        return readme or "# STT/TTS App"

    else
        return true
    end
end

return App
