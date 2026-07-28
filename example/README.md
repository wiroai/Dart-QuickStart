# Wiro AI Flutter example

Minimal examples for the local `wiro_client` package: a Flutter
text-to-image app and four CLI scripts that cover the main SDK paths.

## Flutter app

Enter a prompt, follow the polled task status, and display the image
produced by `Wiro.flux2Pro` through `subscribeRequest`.

```bash
flutter run --dart-define=WIRO_API_KEY=your-api-key
```

Projects using signature authentication can also provide
`--dart-define=WIRO_API_SECRET=your-api-secret`.

## CLI scripts

```bash
# Typed image factory + polling
WIRO_API_KEY=your-api-key dart run bin/generate_image.dart

# Typed video factory + WebSocket progress
WIRO_API_KEY=your-api-key dart run bin/generate_video.dart

# Any model via Wiro.model + schema.validate
WIRO_API_KEY=your-api-key dart run bin/generate_dynamic.dart

# File input: public URL (default) or local bytes auto-upload
WIRO_API_KEY=your-api-key dart run bin/upscale_image.dart
WIRO_API_KEY=your-api-key dart run bin/upscale_image.dart ./photo.jpg
```

| Script | Shows |
| --- | --- |
| `generate_image.dart` | `Wiro.flux2Pro` + `subscribeRequest` (poll) |
| `generate_video.dart` | `Wiro.runwayGen45` + WebSocket `onUpdate` |
| `generate_dynamic.dart` | `getModelSchema` → `validate` → `Wiro.model` |
| `upscale_image.dart` | `WiroFileInput.url` / `.bytes` + `Wiro.upscaler` |

All scripts handle the sealed `WiroTaskSuccess` / `WiroTaskFailure`
result. Optional `WIRO_API_SECRET` enables signature authentication.

Do not embed long-lived API credentials in production mobile builds.
Route production requests through your backend and keep Wiro credentials
server-side — see `WiroClient.proxied` in the package README.
