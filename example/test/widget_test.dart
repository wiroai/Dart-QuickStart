import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wiro_client_example/main.dart';

void main() {
  testWidgets('shows the image-generation form', (tester) async {
    await tester.pumpWidget(
      const WiroClientExampleApp(apiKey: '', apiSecret: ''),
    );

    expect(find.text('FLUX.2 Pro'), findsOneWidget);
    expect(find.text('Imagine...'), findsOneWidget);
    expect(find.text('Generate image'), findsOneWidget);
  });

  testWidgets('shows API key instructions', (tester) async {
    await tester.pumpWidget(
      const WiroClientExampleApp(apiKey: '', apiSecret: ''),
    );

    await tester.enterText(
      find.byType(EditableText),
      'A cinematic mountain lake',
    );
    await tester.tap(find.text('Generate image'));
    await tester.pump();

    expect(
      find.text('Run with --dart-define=WIRO_API_KEY=your-key.'),
      findsOneWidget,
    );
  });
}
