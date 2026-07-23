# Contributing

Thank you for improving the Wiro Dart SDK.

## Requirements

- Flutter 3.32.8 or newer
- Dart 3.8.0 or newer
- Git

Puro is not required.

## Setup

```bash
git clone https://github.com/wiroai/wiro-dart.git
cd wiro-dart
flutter pub get
```

## Development checks

Run these checks before opening a pull request:

```bash
dart format lib test tool example/lib example/test example/bin
dart analyze
dart test

cd example
flutter analyze
flutter test
```

Measure SDK coverage:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json \
  --report-on=lib
dart run tool/check_coverage.dart coverage/lcov.info 90
```

## Public API changes

- Keep the SDK core independent of Flutter.
- Use typed responses; model-specific input parameters may remain dynamic.
- Document every public member with DartDoc.
- Add tests for success, failure, cancellation, and serialization behavior.
- Preserve backward compatibility unless a major version is planned.

## Pull requests

- Keep changes focused.
- Add a changelog entry for developer-visible behavior.
- Never commit API keys, API secrets, private prompts, or generated media.
- Ensure CI passes on the minimum and current supported Flutter versions.

## Releases

This project follows [Semantic Versioning](https://semver.org/):

- Patch: backward-compatible fixes
- Minor: backward-compatible functionality
- Major: breaking public API changes

Maintainers update `CHANGELOG.md` and `pubspec.yaml`, create a `vX.Y.Z`
GitHub release, and trusted publishing sends the package to pub.dev.
