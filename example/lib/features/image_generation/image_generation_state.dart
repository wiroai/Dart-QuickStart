/// State of the image-generation example.
sealed class ImageGenerationState {
  const ImageGenerationState();
}

/// No generation has been requested.
final class ImageGenerationIdle extends ImageGenerationState {
  /// Creates the idle state.
  const ImageGenerationIdle();
}

/// A generation task is running.
final class ImageGenerationLoading extends ImageGenerationState {
  /// Creates a loading state with the latest task [status].
  const ImageGenerationLoading(this.status);

  /// Latest Wiro task status.
  final String status;
}

/// Image generation completed successfully.
final class ImageGenerationSuccess extends ImageGenerationState {
  /// Creates a successful state.
  const ImageGenerationSuccess(this.imageUrl);

  /// Generated image URL.
  final Uri imageUrl;
}

/// Image generation failed.
final class ImageGenerationFailure extends ImageGenerationState {
  /// Creates a failed state.
  const ImageGenerationFailure(this.message);

  /// Human-readable failure message.
  final String message;
}
