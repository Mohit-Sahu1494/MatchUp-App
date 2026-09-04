import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unimatch_app/main.dart';

void main() {
  testWidgets('MatchUpApp launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MatchUpApp()));
    expect(find.byType(MatchUpApp), findsOneWidget);
  });
}
