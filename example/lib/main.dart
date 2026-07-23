import 'package:flutter/material.dart';
import 'package:wiro_ai/wiro_ai.dart';

void main() {
  const apiKey = String.fromEnvironment('WIRO_API_KEY');
  runApp(const WiroAiExampleApp(apiKey: apiKey));
}

final class WiroAiExampleApp extends StatelessWidget {
  const WiroAiExampleApp({required this.apiKey, super.key});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiro AI Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: ModelExplorerPage(apiKey: apiKey),
    );
  }
}

final class ModelExplorerPage extends StatefulWidget {
  const ModelExplorerPage({required this.apiKey, super.key});

  final String apiKey;

  @override
  State<ModelExplorerPage> createState() => _ModelExplorerPageState();
}

final class _ModelExplorerPageState extends State<ModelExplorerPage> {
  late final WiroClient? _client;
  final ValueNotifier<String> _result = ValueNotifier(
    'Tap the button to explore Wiro models.',
  );
  final ValueNotifier<bool> _isLoading = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _client = widget.apiKey.isEmpty ? null : WiroClient(apiKey: widget.apiKey);
  }

  @override
  void dispose() {
    _client?.close();
    _result.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _exploreModels() async {
    final client = _client;
    if (client == null) {
      _result.value = 'Run with --dart-define=WIRO_API_KEY=your-key.';
      return;
    }

    _isLoading.value = true;
    try {
      final categories = await client.explore();
      _result.value = categories
          .map((category) {
            final models = category.models
                .map((model) => '• ${model.identifier}')
                .join('\n');
            return '${category.title}\n$models';
          })
          .join('\n\n');
    } on Object catch (error) {
      _result.value = 'Request failed: $error';
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wiro AI Model Explorer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, child) {
                return FilledButton.icon(
                  onPressed: isLoading ? null : _exploreModels,
                  icon: isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Explore models'),
                );
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _result,
                builder: (context, result, child) {
                  return SingleChildScrollView(child: SelectableText(result));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
