import 'package:flutter/material.dart';
import 'package:wiro_client_example/features/image_generation/image_generation_page.dart';

void main() {
  const apiKey = String.fromEnvironment('WIRO_API_KEY');
  const apiSecret = String.fromEnvironment('WIRO_API_SECRET');
  runApp(
    const WiroClientExampleApp(
      apiKey: apiKey,
      apiSecret: apiSecret,
    ),
  );
}

/// Root application for the Wiro Flutter example.
final class WiroClientExampleApp extends StatelessWidget {
  /// Creates the example application.
  const WiroClientExampleApp({
    required this.apiKey,
    required this.apiSecret,
    super.key,
  });

  /// API key used only for local demonstration.
  final String apiKey;

  /// Optional API secret used only for local demonstration.
  final String apiSecret;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wiro Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: ImageGenerationPage(
        apiKey: apiKey,
        apiSecret: apiSecret,
      ),
    );
  }
}
