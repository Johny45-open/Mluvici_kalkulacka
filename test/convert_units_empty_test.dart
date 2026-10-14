import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Prevody jednotek: prazdny vstup bez platneho vysledku nesmi vratit uspesny
// prevod nuly; desetinná cárka v _lastResult se zpracuje; platna nula projde;
// tlacitko Prevest a klavesa = volaji touz logiku.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
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

  Future<dynamic> pumpApp(
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
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<dynamic> pumpUnitMode(WidgetTester tester) async {
    final state = await pumpApp(tester);
    state.switchModeForTest(CalculatorMode.unitConversion);
    await tester.pumpAndSettle();
    return state;
  }

  Finder convertButton() => find.byKey(const ValueKey('unit_convert_button'));

  bool hasConversionError() {
    return find.text('Chyba převodu').evaluate().isNotEmpty ||
        find.text('Conversion error').evaluate().isNotEmpty;
  }

  group('prevod jednotek po vymazani a prazdny vstup', () {
    testWidgets('po clear() prevod selze, nevraci uspesnou nulu', (
      tester,
    ) async {
      final state = await pumpUnitMode(tester);
      state.clearForTest();
      await tester.pump();
      expect(state.displayForTest, '');
      await tester.tap(convertButton());
      await tester.pumpAndSettle();
      // zadny uspesny prevod: _lastResult zustava '0.' z clear(), chyba viditelna
      expect(state.lastResultForTest, '0.');
      expect(hasConversionError(), isTrue);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('desetinna carka v _lastResult se spravne precte', (
      tester,
    ) async {
      final state = await pumpUnitMode(tester);
      state.setDisplayForTest('', 0);
      state.setLastResultForTest('24,55');
      state.setHasResultForTest(true);
      await tester.pump();
      await tester.tap(convertButton());
      await tester.pumpAndSettle();
      // 24.55 m -> km = 0.02455
      expect(state.lastResultForTest, '0.02455');
      expect(hasConversionError(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('platna vstupni nula se prevede uspesne', (tester) async {
      final state = await pumpUnitMode(tester);
      state.setDisplayForTest('0', 1);
      await tester.pump();
      await tester.tap(convertButton());
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, '0');
      expect(hasConversionError(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('zastarily vysledek Error se nepouzije', (tester) async {
      final state = await pumpUnitMode(tester);
      state.setDisplayForTest('', 0);
      state.setLastResultForTest('Error');
      state.setHasResultForTest(true);
      await tester.pump();
      await tester.tap(convertButton());
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, 'Error');
      expect(hasConversionError(), isTrue);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Prevest a = vrati stejny vysledek', (tester) async {
      final state = await pumpUnitMode(tester);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await tester.tap(convertButton());
      await tester.pumpAndSettle();
      final viaButton = state.lastResultForTest as String;
      expect(hasConversionError(), isFalse);
      // znovu stejny vstup, tentokrat klavesou =
      state.setDisplayForTest('5', 1);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, viaButton);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tap na = v rezimu prevodu prevede (5 m -> km)', (
      tester,
    ) async {
      final state = await pumpUnitMode(tester);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      // 5 m -> km = 0.005
      expect(state.lastResultForTest, '0.005');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
