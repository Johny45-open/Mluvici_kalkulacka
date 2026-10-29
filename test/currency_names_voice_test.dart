import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Lokalizovane nazvy men: stejne popisky „KOD — nazev" v seznamech,
// pristupnych popiscich i hlasovem potvrzeni; interni kody zustavaji.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];

  setUp(() {
    ttsLog.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
      if (call.method == 'speak') {
        ttsLog.add(call.arguments as String? ?? '');
      }
      return 1;
    });
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
  });

  Future<dynamic> pumpCurrency(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    state.switchModeForTest(CalculatorMode.currency);
    await tester.pumpAndSettle();
    return state;
  }

  group('nazvy men v cestine', () {
    testWidgets('seznam zobrazuje KOD — nazev', (tester) async {
      await pumpCurrency(tester);
      await tester.tap(find.byKey(const ValueKey('currency_from_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('CZK — česká koruna'), findsWidgets);
      expect(find.text('EUR — euro'), findsWidgets);
      expect(find.text('USD — americký dolar'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('zmena meny se ohlasi nazvem a prevod funguje', (tester) async {
      final state = await pumpCurrency(tester);
      ttsLog.clear();
      // zmenit cil na USD
      await tester.tap(find.byKey(const ValueKey('currency_to_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD — americký dolar').last);
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('USD — americký dolar')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      // prevod 10 CZK -> USD probehne s internimi kody
      state.setDisplayForTest('10', 2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('currency_convert_button')));
      await tester.pumpAndSettle();
      final res = state.lastResultForTest as String;
      expect(res.isNotEmpty, isTrue);
      expect(res, isNot('10'));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('obousmerny prevod CZK->EUR a EUR->CZK', (tester) async {
      final state = await pumpCurrency(tester);
      state.setDisplayForTest('100', 3);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('currency_convert_button')));
      await tester.pumpAndSettle();
      final czkToEur = state.lastResultForTest as String;
      expect(czkToEur.isNotEmpty, isTrue);
      // prohodit smer: z EUR do CZK
      await tester.tap(find.byKey(const ValueKey('currency_from_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EUR — euro').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('currency_to_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CZK — česká koruna').last);
      await tester.pumpAndSettle();
      state.setDisplayForTest('10', 2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('currency_convert_button')));
      await tester.pumpAndSettle();
      final eurToCzk = state.lastResultForTest as String;
      expect(eurToCzk.isNotEmpty, isTrue);
      // 10 EUR v CZK je vice nez 100 CZK v EUR (kurz EUR ~24.5)
      expect(
        double.parse(eurToCzk.replaceAll(',', '.')) >
            double.parse(czkToEur.replaceAll(',', '.')),
        isTrue,
        reason: '$eurToCzk vs $czkToEur',
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('nazvy men v anglictine', () {
    testWidgets('seznam zobrazuje KOD — name', (tester) async {
      await pumpCurrency(tester, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('currency_from_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('CZK — Czech koruna'), findsWidgets);
      expect(find.text('USD — US dollar'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('zmena meny se ohlasi anglickym nazvem', (tester) async {
      await pumpCurrency(tester, locale: const Locale('en'));
      ttsLog.clear();
      await tester.tap(find.byKey(const ValueKey('currency_to_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD — US dollar').last);
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('USD — US dollar')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
