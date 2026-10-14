import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Panely prevodu na hlavni obrazovce: dosazitelnost a poradek pri malych
// velikostech a zvetsenem textu. Rastr klavesnice 7x4 zustava nedotcen
// (hlida keypad_spatial_stability_test.dart).
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

  Future<dynamic> pumpSized(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    Locale locale = const Locale('cs'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> checkUnitPanel(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    final category = find.byKey(const ValueKey('unit_category_dropdown'));
    final from = find.byKey(const ValueKey('unit_from_dropdown'));
    final to = find.byKey(const ValueKey('unit_to_dropdown'));
    final convert = find.byKey(const ValueKey('unit_convert_button'));
    for (final f in [category, from, to, convert]) {
      expect(f, findsOneWidget);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }
    // smysluplne poradi: kategorie nahore, Prevest dole
    final catDy = tester.getCenter(category).dy;
    final fromDy = tester.getCenter(from).dy;
    final toDy = tester.getCenter(to).dy;
    final convDy = tester.getCenter(convert).dy;
    expect(catDy, lessThan(fromDy));
    expect(fromDy, lessThanOrEqualTo(toDy));
    expect(toDy, lessThan(convDy));
    // vodorovne usporadani: Z vlevo, Na vpravo (uzka obrazovka: pod sebou)
    final fromDx = tester.getCenter(from).dx;
    final toDx = tester.getCenter(to).dx;
    if ((fromDy - toDy).abs() < 1.0) {
      expect(fromDx, lessThan(toDx));
    }
    // vsechny prvky vystupuji jako tlacitka (ovladatelne klavesnici i cteckou)
    for (final f in [category, from, to]) {
      expect(
        tester
            .getSemantics(f)
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
        reason: '$f',
      );
    }
    semantics.dispose();
  }

  Future<void> checkCurrencyPanel(WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    final from = find.byKey(const ValueKey('currency_from_dropdown'));
    final to = find.byKey(const ValueKey('currency_to_dropdown'));
    final convert = find.byKey(const ValueKey('currency_convert_button'));
    for (final f in [from, to, convert]) {
      expect(f, findsOneWidget);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
    }
    final fromDy = tester.getCenter(from).dy;
    final toDy = tester.getCenter(to).dy;
    final convDy = tester.getCenter(convert).dy;
    expect(fromDy, lessThanOrEqualTo(toDy));
    expect(toDy, lessThan(convDy));
    final fromDx = tester.getCenter(from).dx;
    final toDx = tester.getCenter(to).dx;
    if ((fromDy - toDy).abs() < 1.0) {
      expect(fromDx, lessThan(toDx));
    }
    for (final f in [from, to]) {
      expect(
        tester
            .getSemantics(f)
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
        reason: '$f',
      );
    }
    semantics.dispose();
  }

  group('panely prevodu pri malych obrazovkach', () {
    for (final size in const [Size(320, 640), Size(360, 640)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('$size text $scale: panel jednotek dosazitelny', (
          tester,
        ) async {
          final state = await pumpSized(
            tester,
            size: size,
            textScale: scale,
          );
          state.switchModeForTest(CalculatorMode.unitConversion);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await checkUnitPanel(tester);
          // vyber kategorie funguje i zde
          await tester.tap(
            find.byKey(const ValueKey('unit_category_dropdown')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hmotnost').last);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 1));
        });

        testWidgets('$size text $scale: panel men dosazitelny', (
          tester,
        ) async {
          final state = await pumpSized(
            tester,
            size: size,
            textScale: scale,
          );
          state.switchModeForTest(CalculatorMode.currency);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await checkCurrencyPanel(tester);
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }

    testWidgets('360x740: vyber jednotek a Prevest funguje', (tester) async {
      final state = await pumpSized(
        tester,
        size: const Size(360, 740),
        textScale: 1.0,
      );
      state.switchModeForTest(CalculatorMode.unitConversion);
      await tester.pumpAndSettle();
      await checkUnitPanel(tester);
      // zmena kategorie nastavi platne vychozi jednotky
      await tester.tap(find.byKey(const ValueKey('unit_category_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hmotnost').last);
      await tester.pumpAndSettle();
      // prevod 2 kg -> g = 2000
      state.setDisplayForTest('2', 1);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('unit_convert_button')));
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, '2000');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
