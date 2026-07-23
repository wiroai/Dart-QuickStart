# Wiro AI Flutter example

A minimal iOS and Android application that explores the models available on
Wiro using the `wiro_client` package.

Run the application locally:

```bash
flutter run --dart-define=WIRO_API_KEY=your-api-key
```

Run the image and video examples:

```bash
WIRO_API_KEY=your-api-key dart run bin/generate_image.dart
WIRO_API_KEY=your-api-key dart run bin/generate_video.dart
```

The video example allows up to ten minutes for long-running generation tasks
and treats a terminal task as successful only when its exit code is `0`.

Do not embed long-lived API credentials in production mobile builds.
