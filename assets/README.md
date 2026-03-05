# Speech-to-Text / Text-to-Speech

This app provides two journey functions for converting between audio and text.

## Configuration

| Key | Description | Example |
|-----|-------------|---------|
| `stt_api_url` | STT endpoint URL | `https://api.openai.com/v1/audio/transcriptions` |
| `stt_api_key` | STT API key | `sk-...` |
| `stt_model` | STT model name | `whisper-1` |
| `tts_api_url` | TTS endpoint URL | `https://api.openai.com/v1/audio/speech` |
| `tts_api_key` | TTS API key | `sk-...` |
| `tts_model` | TTS model name | `tts-1` |
| `tts_voice` | Default TTS voice | `alloy` |
| `default_language` | Default language for STT | `en` |

## Journey Functions

### `transcribe(media_id, [language])`

Converts audio to text. Pass the media ID from the incoming message — the app
resolves a signed download URL internally via `turn.media.signed_url()`.

```elixir
card TranscribeInput do
  result = app("stt_tts", "transcribe", ["@event.message.audio.id", "en"])
  transcribed_text = result.result.text
end
```

Returns: `{text = "...", language = "..."}`

### `speak(text, [voice])`

Converts text to audio. Returns a media_id that can be sent with `audio()`.

```elixir
card SpeakAnswer do
  result = app("stt_tts", "speak", ["Hello!", "alloy"])
  audio("@result.result.media_id")
end
```

Returns: `{media_id = "...", content_type = "audio/opus"}`

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

## Vendor Porting

To use a different STT/TTS provider (e.g., Proto for Kinyarwanda), edit
`stt_tts/transcribe.lua` and `stt_tts/speak.lua`. Change the HTTP request
shape to match your vendor's API. Configuration keys stay the same.

Vendors accepting JSON with base64 audio can drop `multipart.lua`:

```lua
local audio_b64 = turn.encoding.base64_encode(audio_data)
turn.http.request({
  url = config.stt_api_url,
  method = "POST",
  headers = { ["Content-Type"] = "application/json", ... },
  body = turn.json.encode({ audio = audio_b64, language = language }),
})
```
