import 'package:flutter/material.dart';
import 'package:wiro_client/wiro_client.dart';
import 'package:wiro_client_example/core/constants/project_padding.dart';
import 'package:wiro_client_example/core/constants/project_spacing.dart';
import 'package:wiro_client_example/core/widgets/app_cached_image.dart';
import 'package:wiro_client_example/extension/media_query_extension.dart';
import 'package:wiro_client_example/extension/theme_extension.dart';
import 'package:wiro_client_example/features/image_generation/image_generation_state.dart';

/// Demonstrates text-to-image generation with [WiroClient.subscribe].
final class ImageGenerationPage extends StatefulWidget {
  /// Creates the image-generation example.
  const ImageGenerationPage({
    required this.apiKey,
    this.apiSecret = '',
    super.key,
  });

  /// API key used only for local demonstration.
  final String apiKey;

  /// Optional API secret used only for local demonstration.
  final String apiSecret;

  @override
  State<ImageGenerationPage> createState() {
    return _ImageGenerationPageState();
  }
}

final class _ImageGenerationPageState extends State<ImageGenerationPage> {
  final TextEditingController _promptController = TextEditingController();
  final ValueNotifier<ImageGenerationState> _state = ValueNotifier(
    const ImageGenerationIdle(),
  );

  late final WiroClient? _client;
  WiroCancellationToken? _activeCancellationToken;

  @override
  void initState() {
    super.initState();
    final apiKey = widget.apiKey.trim();
    final apiSecret = widget.apiSecret.trim();
    _client = apiKey.isEmpty
        ? null
        : WiroClient(
            apiKey: apiKey,
            apiSecret: apiSecret.isEmpty ? null : apiSecret,
          );
  }

  @override
  void dispose() {
    _activeCancellationToken?.cancel();
    _client?.close();
    _promptController.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _generateImage() async {
    if (_state.value is ImageGenerationLoading) {
      return;
    }

    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _state.value = const ImageGenerationFailure(
        'Enter a prompt before generating an image.',
      );
      return;
    }

    final client = _client;
    if (client == null) {
      _state.value = const ImageGenerationFailure(
        'Run with --dart-define=WIRO_API_KEY=your-key.',
      );
      return;
    }

    final cancellationToken = WiroCancellationToken();
    _activeCancellationToken = cancellationToken;
    _state.value = const ImageGenerationLoading('Submitting request');

    try {
      final task = await client.subscribe(
        'black-forest-labs/flux-2-pro',
        parameters: {
          'prompt': prompt,
          'width': 1024,
          'height': 1024,
          'outputFormat': 'png',
        },
        cancellationToken: cancellationToken,
        onTaskUpdate: (task) {
          if (mounted) {
            _state.value = ImageGenerationLoading(task.status.name);
          }
        },
      );
      final imageUrl = _firstOutputUrl(task);
      if (imageUrl == null) {
        throw StateError('The task completed without an image URL.');
      }
      if (mounted) {
        _state.value = ImageGenerationSuccess(imageUrl);
      }
    } on WiroTaskFailedException catch (error) {
      if (mounted) {
        _state.value = ImageGenerationFailure(
          error.task.debugOutput ?? error.message,
        );
      }
    } on WiroException catch (error) {
      if (mounted) {
        _state.value = ImageGenerationFailure(error.message);
      }
    } on Object catch (error) {
      if (mounted) {
        _state.value = ImageGenerationFailure(error.toString());
      }
    } finally {
      if (identical(_activeCancellationToken, cancellationToken)) {
        _activeCancellationToken = null;
      }
    }
  }

  Uri? _firstOutputUrl(WiroTask task) {
    for (final output in task.outputs) {
      if (output.url case final url?) {
        return url;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = context
        .dynamicWidth(ProjectPadding.page)
        .clamp(ProjectPadding.card, ProjectPadding.page * 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Wiro Image Generation')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: ProjectPadding.page,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'FLUX.2 Pro',
                          style: context.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: ProjectSpacing.small),
                        Text(
                          'Describe an image and generate it with Wiro.',
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: ProjectSpacing.large),
                        TextField(
                          controller: _promptController,
                          minLines: 2,
                          maxLines: 4,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _generateImage(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Imagine...',
                            hintText: 'A cinematic mountain lake at sunrise',
                          ),
                        ),
                        const SizedBox(height: ProjectSpacing.medium),
                        ValueListenableBuilder<ImageGenerationState>(
                          valueListenable: _state,
                          builder: (context, state, child) {
                            return _GenerationSection(
                              state: state,
                              onGenerate: _generateImage,
                            );
                          },
                        ),
                        const SizedBox(height: ProjectSpacing.large),
                        const _CredentialNotice(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GenerationSection extends StatelessWidget {
  const _GenerationSection({
    required this.state,
    required this.onGenerate,
  });

  final ImageGenerationState state;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final isLoading = state is ImageGenerationLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GenerateButton(
          isLoading: isLoading,
          onPressed: isLoading ? null : onGenerate,
        ),
        const SizedBox(height: ProjectSpacing.large),
        _GenerationResult(state: state),
      ],
    );
  }
}

final class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(isLoading ? 'Generating...' : 'Generate image'),
    );
  }
}

final class _GenerationResult extends StatelessWidget {
  const _GenerationResult({required this.state});

  final ImageGenerationState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ImageGenerationIdle() => const SizedBox.shrink(),
      ImageGenerationLoading(:final status) => _GenerationProgress(
        status: status,
      ),
      ImageGenerationSuccess(:final imageUrl) => _GeneratedImage(
        imageUrl: imageUrl,
      ),
      ImageGenerationFailure(:final message) => _GenerationError(
        message: message,
      ),
    };
  }
}

final class _GenerationProgress extends StatelessWidget {
  const _GenerationProgress({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ProjectPadding.card),
        child: Text(
          'Task status: $status',
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

final class _GeneratedImage extends StatelessWidget {
  const _GeneratedImage({required this.imageUrl});

  final Uri imageUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AppCachedImage(
        imageUrl: imageUrl,
        borderRadius: BorderRadius.circular(ProjectSpacing.medium),
      ),
    );
  }
}

final class _GenerationError extends StatelessWidget {
  const _GenerationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(ProjectPadding.card),
        child: Text(
          message,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

final class _CredentialNotice extends StatelessWidget {
  const _CredentialNotice();

  @override
  Widget build(BuildContext context) {
    return Text(
      'This direct credential setup is for local development only. '
      'Production mobile apps should call Wiro through your backend.',
      style: context.textTheme.bodySmall?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }
}
