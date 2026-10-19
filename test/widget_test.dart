import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/main.dart';

void main() {
  testWidgets('App renders Game Hub successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await GameStorage.init();

    await tester.pumpWidget(KidsGamesApp(storage: storage, skipSplash: true));
    await tester.pumpAndSettle();

    expect(find.text('WonderPlay Arcade!'), findsOneWidget);
    expect(find.text('Math Bubble Pop'), findsOneWidget);
    expect(find.text('Animal Memory Match'), findsOneWidget);
    expect(find.text('Merge Blacksmith'), findsOneWidget);
  });

  testWidgets('Splash screen displays branding and transitions to hub on tap',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await GameStorage.init();

    await tester.pumpWidget(KidsGamesApp(storage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('WonderPlay Arcade'), findsOneWidget);
    expect(find.text('Fun & Learning Mini-Games!'), findsOneWidget);

    await tester.tap(find.text('WonderPlay Arcade'));
    await tester.pumpAndSettle();

    expect(find.text('WonderPlay Arcade!'), findsOneWidget);
  });
}
