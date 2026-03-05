# stt_tts

A Turn.io Lua app for composable Speech-to-Text and Text-to-Speech journey functions. Reference implementation uses OpenAI Whisper and TTS APIs.

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
stt_tts/
├── stt_tts.lua                    # Main app code
├── stt_tts/
│   ├── transcribe.lua             # STT: media → text
│   ├── speak.lua                  # TTS: text → audio
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
- Main Lua file (`stt_tts.lua`)
- `stt_tts/` directory (submodules)
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
