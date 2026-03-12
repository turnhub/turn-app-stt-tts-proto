# Speech-to-Text / Text-to-Speech [proto.cx]

This app provides two journey functions for converting between audio and text, using the [proto.cx](https://proto.cx) voice API for STT and TTS.

> **Note:** This is a fork of [turnhub/turn-app-stt-tts](https://github.com/turnhub/turn-app-stt-tts) ported to work with the proto.cx API instead of OpenAI. It also uses a temporary OGG-to-MP3 conversion worker (see `audio_convert_url` below) since WhatsApp sends voice notes as OGG/Opus and proto.cx only accepts MP3.

## Configuration

| Key | Description | Example |
|-----|-------------|---------|
| `stt_api_url` | proto.cx ASR endpoint | `https://v3-api-develop.proto.cx/api/platform/v1/voice/{teamspace_id}/asr` |
| `stt_api_key` | proto.cx API key | `...` |
| `tts_api_url` | proto.cx TTS endpoint | `https://v3-api-develop.proto.cx/api/platform/v1/voice/{teamspace_id}/tts` |
| `tts_api_key` | proto.cx API key | `...` |
| `tts_gender` | Default TTS voice gender | `female` or `male` |
| `default_language` | Language code for STT and TTS | `en`, `rw` |
| `audio_convert_url` | OGG→MP3 conversion worker URL | `https://ogg-to-mp3.arjunkhoosal.workers.dev` |
| `audio_convert_secret` | Secret for the conversion worker | `...` |

## Journey Functions

### `transcribe(media_id, [language])`

Converts audio to text. Pass the media ID from the incoming message — the app resolves a signed download URL internally, converts the OGG to MP3, then sends it to the proto.cx ASR API.

```elixir
card TranscribeInput do
  result = app("stt_tts", "transcribe", ["@event.message.audio.id", "en"])
  transcribed_text = result.result.text
end
```

Returns: `{text = "...", language = "..."}`

### `speak(text, [gender])`

Converts text to audio using proto.cx TTS. Returns a media_id that can be sent with `audio()`.

```elixir
card SpeakAnswer do
  result = app("stt_tts", "speak", ["Hello!"])
  audio("@result.result.media_id")
end
```

Returns: `{media_id = "...", content_type = "audio/mpeg"}`

## Complete Voice-FAQ Example

```elixir
card AskVoiceNote do
  ask("Send me a voice note with your question")
end

card TranscribeInput do
  stt_result = app("stt_tts", "transcribe", ["@event.message.audio.id"])
  user_question = stt_result.result.text
end

card AnswerWithAI, code_generator: "AI_TEXT" do
  ai = ai_assistant("<your-assistant-uuid>")
  ai = ai_add_message(ai, "system", "Answer this FAQ: @user_question")
  ref_AnswerWithAI_completion = ai_chat_completion(ai)
  ref_AnswerWithAI = ref_AnswerWithAI_completion.response
end

card SpeakAnswer do
  tts_result = app("stt_tts", "speak", ["@ref_AnswerWithAI"])
  audio("@tts_result.result.media_id")
  text("@stt_result.result.text")
end
```
