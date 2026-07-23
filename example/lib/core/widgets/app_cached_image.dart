import 'package:flutter/material.dart';
import 'package:wiro_client_example/extension/theme_extension.dart';

/// Displays a network image through Flutter's in-memory image cache.
final class AppCachedImage extends StatelessWidget {
  /// Creates a cached network image.
  const AppCachedImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  /// Remote image URL.
  final Uri imageUrl;

  /// Requested image width.
  final double? width;

  /// Requested image height.
  final double? height;

  /// How the image should fit its bounds.
  final BoxFit fit;

  /// Image clipping radius.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl.toString(),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return ColoredBox(
            color: context.colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return ColoredBox(
            color: context.colorScheme.errorContainer,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: context.colorScheme.onErrorContainer,
                size: 48,
              ),
            ),
          );
        },
      ),
    );
  }
}
