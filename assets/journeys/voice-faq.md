<!-- { section: "a1b52c90-0001-4dbd-8335-d565086c0001", x: 0, y: 0} -->

```stack
trigger(on: "MESSAGE RECEIVED") when has_only_phrase(event.message.text.body, "voice faq")

```

<!-- { section: "a1b52c90-0001-4dbd-8335-d565086c0002", x: 488, y: 0} -->

```stack
card AskVoiceNote, "AskVoiceNote",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0001",
  code_generator: "QUESTION" do
  ref_AskVoiceNote = ask("Send me a voice note with your question and I'll answer it.")
  then(Transcribe)
end

```

<!-- { section: "a1b52c90-0001-4dbd-8335-d565086c0003", x: 976, y: 0} -->

```stack
card Transcribe, "Transcribe",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0003",
  code_generator: "APP" do
  ref_Transcribe = app("stt_tts_proto", "transcribe", ["@event.message.audio.id"])
  then(ShowTranscription when ref_Transcribe.success == true)
  then(ErrorCard when ref_Transcribe.success == false)
end

```

<!-- { section: "1f22284c-c4bb-4ee7-b626-e21478caee81", x: 1464, y: 192} -->

```stack
card ShowTranscription, "ShowTranscription",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0005",
  code_generator: "TEXT_MESSAGE" do
  text("I heard: @ref_Transcribe.result.text")
  then(AnswerWithAI)
end

```

<!-- { section: "87eaaf17-d6da-480b-87c3-47a20ab5bea2", x: 1848, y: 264} -->

```stack
card AnswerWithAI, "AnswerWithAI",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0002",
  code_generator: "AI_TEXT" do
  ai = ai_assistant("assistant:stt_tts_assistant")
  ai = ai_add_message(ai, "system", "Answer this question concisely: @ref_Transcribe.result.text")
  ref_AnswerWithAI_completion = ai_chat_completion(ai)
  ref_AnswerWithAI = ref_AnswerWithAI_completion.response
  then(SpeakAnswer)
end

```

<!-- { section: "a5a5375d-59fb-49d9-af8d-1f06c291ccaf", x: 2208, y: 312} -->

```stack
card SpeakAnswer, "SpeakAnswer",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0004",
  code_generator: "APP" do
  ref_SpeakAnswer = app("stt_tts_proto", "speak", ["@ref_AnswerWithAI"])
  then(SendAudio when ref_SpeakAnswer.success == true)
  then(TextFallback when ref_SpeakAnswer.success == false)
end

```

<!-- { section: "bfcc9cf7-6a2c-4cf9-aa4f-70d150c2ad3c", x: 2688, y: 720} -->

```stack
card TextFallback, "TextFallback",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0007",
  code_generator: "TEXT_MESSAGE" do
  text("Something went wrong while converting \"@ref_AnswerWithAI\" to speech.")
end

```

<!-- { section: "be03efe6-4c26-4f76-bc91-cf02cc484f93", x: 1440, y: 432} -->

```stack
card ErrorCard, "ErrorCard",
  version: "1",
  uuid: "b2c63d80-0001-4e43-b87e-636c744a0008",
  code_generator: "TEXT_MESSAGE" do
  text("Sorry, I couldn't process that voice note. Please try again.")
  then(AskVoiceNote)
end

```

<!-- { section: "71a1f181-cd4c-49c2-a032-176a37dc0f1a", x: 2640, y: 312} -->

```stack
card SendAudio, "SendAudio" do
  audio("@ref_SpeakAnswer.result.media_id")
end

```

<!-- { section: "e343dcf7-0001-4370-aefe-3c67cea6c001", x: -1000, y: 0} -->

```stack
card RESERVED_DEFAULT_CARD, "RESERVED_DEFAULT_CARD", code_generator: "RESERVED_DEFAULT_CARD" do
  # RESERVED_DEFAULT_CARD
end

```

<!-- { section: "INTERACTION_TIMEOUT_CELL", x: 0, y: 0} -->

```stack
interaction_timeout(300)

```
