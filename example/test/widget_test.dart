import 'package:flutter_test/flutter_test.dart';
import 'package:wiro_ai_example/main.dart';

void main() {
  testWidgets('shows API key instructions', (tester) async {
    await tester.pumpWidget(const WiroAiExampleApp(apiKey: ''));

    expect(find.text('Tap the button to explore Wiro models.'), findsOneWidget);

    await tester.tap(find.text('Explore models'));
    await tester.pump();

    expect(
      find.text('Run with --dart-define=WIRO_API_KEY=your-key.'),
      findsOneWidget,
    );
  });
}
