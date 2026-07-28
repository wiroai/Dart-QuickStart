/// A file passed to a model parameter.
///
/// Wiro models receive files by URL. Wrap an already-hosted file with
/// [WiroFileInput.url], or wrap raw bytes from the device (a gallery pick,
/// a camera shot, a downloaded file) with [WiroFileInput.bytes] and the
/// client uploads them automatically before the model runs:
///
/// ```dart
/// // Already hosted somewhere:
/// WiroFileInput.url(Uri.parse('https://example.com/photo.png'))
///
/// // Picked from the device; uploaded by the client on run:
/// WiroFileInput.bytes(await picked.readAsBytes(), fileName: picked.name)
/// ```
sealed class WiroFileInput {
  const WiroFileInput();

  /// A file that is already reachable at [url].
  const factory WiroFileInput.url(Uri url) = WiroUrlInput;

  /// A device-local file that the client uploads before the model runs.
  ///
  /// [fileName] must keep its extension (for example `photo.png`) so Wiro
  /// can serve the upload with the right content type.
  factory WiroFileInput.bytes(
    List<int> bytes, {
    required String fileName,
  }) = WiroBytesInput;

  /// Value placed in the request JSON.
  ///
  /// URL inputs become their URL string. Bytes inputs stay as-is; the
  /// client uploads them and swaps in the URL right before the model runs.
  Object get wireValue => switch (this) {
    WiroUrlInput(:final url) => url.toString(),
    WiroBytesInput() => this,
  };
}

/// A file input that is already hosted at a URL.
final class WiroUrlInput extends WiroFileInput {
  /// Creates a file input from an already-hosted [url].
  const WiroUrlInput(this.url);

  /// Address the model downloads the file from.
  final Uri url;
}

/// A file input holding device-local bytes.
///
/// The client uploads the bytes with [fileName] right before the model
/// runs and sends the resulting URL to the model.
final class WiroBytesInput extends WiroFileInput {
  /// Creates a file input from raw [bytes].
  WiroBytesInput(this.bytes, {required this.fileName}) {
    if (fileName.trim().isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'Cannot be empty');
    }
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Cannot be empty');
    }
  }

  /// Raw file contents.
  final List<int> bytes;

  /// Name used for the upload, including the file extension.
  final String fileName;
}
