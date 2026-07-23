import 'dart:io';

import 'package:wiro_client/wiro_client.dart';

Future<void> main() async {
  final apiKey = Platform.environment['WIRO_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set WIRO_API_KEY before running the contract smoke test.');
    exitCode = 64;
    return;
  }
  final apiSecret = Platform.environment['WIRO_API_SECRET'];

  final client = WiroClient(
    apiKey: apiKey,
    apiSecret: apiSecret == null || apiSecret.isEmpty ? null : apiSecret,
  );

  try {
    final search = await client.searchModels(limit: 1);
    if (search.items.isEmpty) {
      throw StateError('Model search returned no models.');
    }

    final model = search.items.single;
    final schema = await client.getModelSchema(model.identifier);
    if (schema.model.identifier != model.identifier) {
      throw StateError('Model detail did not match the search result.');
    }

    final categories = await client.explore();
    stdout
      ..writeln('Model: ${model.identifier}')
      ..writeln('Parameters: ${schema.parameters.length}')
      ..writeln('Explore categories: ${categories.length}');
  } finally {
    client.close();
  }
}
