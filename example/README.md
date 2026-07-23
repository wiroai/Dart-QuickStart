# Wiro AI Flutter example

A minimal text-to-image Flutter application using `WiroClient.subscribe`.
Enter a prompt, follow the polled task status, and display the generated image.

Run the application locally:

```bash
flutter run --dart-define=WIRO_API_KEY=your-api-key
```

Projects using signature authentication can also provide
`--dart-define=WIRO_API_SECRET=your-api-secret`.

Run the image and video examples:

```bash
WIRO_API_KEY=your-api-key dart run bin/generate_image.dart
WIRO_API_KEY=your-api-key dart run bin/generate_video.dart
```

The image example uses `subscribe` with polling. The video example uses
`runModel` and `watchTaskSocket` to print realtime task events.

Do not embed long-lived API credentials in production mobile builds.
Route production requests through your backend and keep Wiro credentials
server-side.
