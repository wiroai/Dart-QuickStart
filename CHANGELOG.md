## 0.1.0 - 2026-07-23

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
- Add explicit `callbackUrl` support for completion webhooks.
- Add `WiroTaskFailedException` for unsuccessful terminal tasks.
- Add Flutter, image-generation, and video-generation examples.
- Add strict analysis, 90% coverage enforcement, CI, and trusted publishing.
- Handle application-level API failures with a typed exception.
- Avoid automatic retries for model runs and file uploads.
- Add streaming uploads and stronger public input validation.
