import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/update_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async {
        if (call.method == 'isTalkBackEnabled' ||
            call.method == 'isScreenReaderEnabled') {
          return false;
        }
        return false;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall call) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  setUp(() {
    CalculatorScreen.skipNetworkUpdatesForTest = true;
    mockChannels();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });
  });

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  testWidgets('Update dialog displays correctly with short content', (tester) async {
    final state = await pumpApp(tester);

    final release = GitHubReleaseInfo(
      tagName: 'v6.3.0',
      htmlUrl: 'https://github.com/Johny45-open/Mluvici_kalkulacka/releases/tag/v6.3.0',
      body: 'Krátké novinky.',
    );

    state.showUpdateDialogForTest(release);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Show release'), findsOneWidget);

    // Zavřeme dialog
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Update dialog with long release summary is scrollable and does not overflow', (tester) async {
    // Test s velmi malou výškou okna, aby se dlouhý obsah nevešel naráz a vyžadoval scroll
    tester.view.physicalSize = const Size(400, 350);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = await pumpApp(tester);

    final longSummary = List.generate(30, (i) => 'Bod novinek číslo $i: Oprava chyby a vylepšení stability.').join('\n');

    final release = GitHubReleaseInfo(
      tagName: 'v6.3.0',
      htmlUrl: 'https://github.com/Johny45-open/Mluvici_kalkulacka/releases/tag/v6.3.0',
      body: longSummary,
    );

    state.showUpdateDialogForTest(release);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );

    // Ověříme, že začátek textu je viditelný
    expect(find.textContaining('Bod novinek číslo 0'), findsOneWidget);

    // Posuneme obsah dolů (scrollování)
    await tester.drag(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    // Tlačítka musí zůstat dosažitelná a funkční
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Show release'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
