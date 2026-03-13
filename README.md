# stt_tts [proto.cx fork]

A Turn.io Lua app for composable Speech-to-Text and Text-to-Speech journey functions, ported to use the [proto.cx](https://proto.cx) voice API.

This is a fork of [turnhub/turn-app-stt-tts](https://github.com/turnhub/turn-app-stt-tts). The original used OpenAI Whisper (STT) and OpenAI TTS. This version targets proto.cx and includes an OGG-to-MP3 conversion step via a temporary Cloudflare Worker (`ogg-to-mp3.arjunkhoosal.workers.dev`), since WhatsApp delivers voice notes as OGG/Opus and proto.cx only accepts MP3.

## Quick Start

```bash
# Run tests
make test

# Watch mode (auto-run tests on file changes)
make watch

# Build ZIP for deployment
make build
```

## Using turn-app command

If you have the `turn-app` alias set up:

```bash
turn-app test       # Run tests
turn-app watch      # Watch mode
turn-app build      # Build ZIP
```

## Project Structure

```
stt_tts_proto/
├── stt_tts_proto.lua              # Main app code
├── stt_tts_proto/
│   ├── transcribe.lua             # STT: media → text (via proto.cx ASR)
│   ├── speak.lua                  # TTS: text → audio (via proto.cx TTS)
│   └── multipart.lua              # Multipart form builder
├── spec/
│   ├── stt_tts_spec.lua           # Integration tests
│   ├── transcribe_spec.lua        # Transcribe unit tests
│   ├── speak_spec.lua             # Speak unit tests
│   └── multipart_spec.lua         # Multipart unit tests
├── assets/
│   ├── manifest.json              # App metadata (required)
│   ├── README.md                  # App documentation (for UI)
│   └── journeys/                  # Journey templates
│       └── voice-faq.md           # Voice FAQ demo journey
├── Makefile                       # Build commands
└── README.md                      # This file
```

## Testing

Tests use the [lester](https://github.com/edubart/lester) testing framework (Busted-compatible API).

See `spec/` for examples.

## Building

The build process creates a ZIP file with:
- Main Lua file (`stt_tts_proto.lua`)
- `stt_tts_proto/` directory (submodules)
- `assets/` directory (including manifest.json and README.md for UI display)

Excludes:
- Test files (`spec/`)
- This README.md (developer documentation)
- Makefile

## App Documentation

When users view your app in the Turn.io UI, they see `assets/README.md`. Edit that file to provide user-facing documentation, configuration instructions, and usage examples.

## Learn More

- [Turn.io Apps Documentation](https://whatsapp.turn.io/docs)
- [Lester Testing Framework](https://github.com/edubart/lester)
- [Lua 5.3 Reference](https://www.lua.org/manual/5.3/)
