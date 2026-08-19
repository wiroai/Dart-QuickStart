## Unreleased

### Removed

- Remove the typed `Wiro.upscaler` / `WiroUpscalerRequest` binding.
  Use `Wiro.model('google/upscaler', parameters: ...)` instead.

## 0.1.0 - 2026-07-24

- Replace string model arguments with the validated
  `WiroModelId` extension type and expose `WiroModel.modelId`.
- Replace string task tokens and IDs with `WiroTaskToken` and
  `WiroTaskId`; split task lookup into `getTask` and `getTaskById`.
- Replace the nullable `WiroTaskUpdate` container with sealed
  snapshot, event, and binary update variants.
- Parse ISO-8601 and Unix task/model timestamps as `DateTime`;
  parse task exit codes and output sizes as `int`.
- Normalize `WiroApiError.code` and
  `WiroApiResultException.code` to `String`.
- Replace model search sort and order strings with
  `WiroModelSort` and `WiroSortOrder`.
- Replace `WiroModelParameter` with sealed select, number, text,
  file, and forward-compatible unknown parameter variants.
- Add `WiroModelSchema.validate` and `WiroSchemaValidationException` for
  required, select-option, and numeric-bound validation.
- Replace dynamic WebSocket messages with sealed log, progress,
  outputs, and unknown payload variants.
- Make `subscribe` return `WiroTaskSuccess` or
  `WiroTaskFailure`; remove `throwOnTaskFailure` and
  `WiroTaskFailedException`.
- Add `subscribeStream` for `await for` task update consumption.
- Add ±20% retry jitter with an injectable `Random` for deterministic tests.
- Add the mock-friendly `WiroClientBase` interface.
- Add observable diagnostics for malformed nested JSON that remains lenient.
- Add image, video, audio, and text convenience getters to task outputs.
- Make server-derived model IDs, task IDs, task tokens, and socket tokens
  nullable so incomplete responses remain safe to parse.
- Restore progress parsing for JSON-encoded WebSocket message strings.
- Route malformed nested JSON diagnostics through each client's logger instead
  of global mutable state.
- Stop polling or WebSocket tracking when a `subscribeStream` listener cancels.
- Make `WiroSchemaValidationException` a local SDK exception with structured
  validation issues.
- Avoid a redundant binary-frame copy when normalizing socket task updates.
- Verify model-sort wire values against the Wiro `search_models` schema.
- Move model parameter defaults onto typed parameter variants.
- Replace `WiroTask.elapsedSeconds` with `Duration? elapsed`.
- Add typed `WiroTaskFailureReason` values to failed subscription results.
- Parse socket message IDs as nullable, validated `WiroTaskId` values.
- Remove redundant cancellation handling from `subscribeStream`.
- Add the `WiroModelRequest` interface with `runRequest` and
  `subscribeRequest` client methods for compile-time checked model inputs.
- Add typed `WiroFlux2ProRequest` and `WiroRunwayGen45Request` bindings
  generated from the live Wiro model schemas.
- Add `WiroClient.proxied` for credential-free clients that route requests
  through a backend proxy, with custom per-request headers.
- Add the `Wiro` namespace so every model request is discoverable from a
  single IDE autocomplete entry point: typed factories such as
  `Wiro.flux2Pro`, plus `Wiro.model` for any model without a typed
  binding.
- Add typed requests generated from the live Wiro schemas for GPT Image 2,
  Nano Banana Pro, Seedream v4, Grok Imagine Image, Google Upscaler,
  Seedance 2.0, Kling V3, Veo 3.1, Sora 2 Pro, Hailuo 2.3 Fast,
  Grok Imagine Video, and Lyria 3.
- Add an internal `tool/generate.dart` code generator that produces typed
  request classes from live Wiro model schemas.
- Add `WiroFileInput` for file parameters: `WiroFileInput.url` wraps hosted
  files and `WiroFileInput.bytes` wraps device files, which the client
  uploads automatically before the model runs.
- Add the initial Wiro API client.
- Add model discovery, execution, file upload, and task operations.
- Add API key and signature authentication.
- Add typed models, schemas, tasks, run results, and upload results.
- Add typed authentication, validation, rate-limit, network, timeout, and
  cancellation exceptions.
- Add request cancellation, configurable retries, backoff, timeouts, and
  structured logging.
- Add task progress streams.
- Add typed task WebSocket events, progress payloads, and binary frames.
- Add `subscribe` for one-call model execution and task polling.
- Allow `subscribe` to select polling or WebSocket task tracking.
- Normalize both transports through `WiroTaskUpdate`.
- Add explicit `callbackUrl` support for completion webhooks.
- Add Flutter, image-generation, and video-generation examples.
- Add strict analysis, 90% coverage enforcement, CI, and trusted publishing.
- Handle application-level API failures with a typed exception.
- Avoid automatic retries for model runs and file uploads.
- Add streaming uploads and stronger public input validation.
