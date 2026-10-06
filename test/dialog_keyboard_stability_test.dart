import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stabilita dialogů při otevřené softwarové klávesnici.
///
/// Ověřuje architekturu „jediný vlastník keyboard insetu = frameworkový
/// Dialog" (viz `showAppDialog` v `lib/calculator_screen.dart`):
/// aplikační kód `viewInsets.bottom` znovu neodečítá, dialog se nemá
/// „vystřelit" k hornímu okraji, titulek zůstává fixní nad scrollovatelným
/// obsahem, focusovaný TextField a spodní tlačítka zůstávají nad klávesnicí
/// a po zavření klávesnice se dialog vrátí do normálního stavu.
///
/// Klávesnice se simuluje přes `tester.view.viewInsets` (stejně jako
/// v `dialog_keyboard_and_stats_focus_test.dart`), fokus pole přes
/// `tester.showKeyboard`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async => false,
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
    Size logicalSize = const Size(360, 640),
    double textScale = 1.0,
  }) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    addTearDown(() {
      tester.view.viewInsets = FakeViewPadding.zero;
    });
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  /// Otevře přes centrální showAppDialog zkušební editorový dialog
  /// ve struktuře předepsané pro všechny reálné editorové dialogy:
  /// fixní titulek + scrollovatelný pouze obsah (`scrollable: false`).
  void openProbeDialog(
    dynamic state,
    BuildContext ctx, {
    int fieldCount = 1,
    String title = 'Probe dialog',
  }) {
    state.showAppDialog<void>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        scrollable: false,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 24,
        ),
        title: Semantics(header: true, child: Text(title)),
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fieldCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  key: ValueKey('probe_field_$i'),
                  decoration: InputDecoration(labelText: 'Field $i'),
                ),
              ),
          ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('probe_cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('probe_ok'),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  BuildContext appContext(WidgetTester tester) =>
      tester.element(find.byType(CalculatorScreen));

  /// Společné aserce: dialog „nevystřelil" k hornímu okraji (titulek je
  /// v horní části nad klávesnicí), dané pole a obě akce jsou celé
  /// nad klávesnicí.
  ///
  /// Pozn.: `getRect(find.byType(AlertDialog))` se záměrně nepoužívá –
  /// vrací route-level box (celou obrazovku), ne kartu dialogu. Pozice
  /// karty se proto měří přes titulek (horní hrana) a akce (spodní hrana).
  /// Případný overflow těla aplikace za modální bariérou (malá obrazovka
  /// + vysoká klávesnice) je očekávaný a konzumuje ho volající přes
  /// `takeException`, stejně jako existující
  /// `dialog_keyboard_and_stats_focus_test.dart`.
  void expectStableAboveKeyboard(
    WidgetTester tester, {
    required double screenHeight,
    required double keyboardHeight,
    required ValueKey<String> fieldKey,
    required String titleText,
  }) {
    final limit = screenHeight - keyboardHeight;
    final titleRect = tester.getRect(find.text(titleText));
    expect(
      titleRect.top,
      greaterThanOrEqualTo(-1),
      reason: 'Titulek (a s ním dialog) se nesmí vystřelit nad horní okraj',
    );
    expect(
      titleRect.bottom,
      lessThanOrEqualTo(limit + 1),
      reason: 'Titulek musí zůstat nad klávesnicí',
    );
    final fieldRect = tester.getRect(find.byKey(fieldKey));
    expect(
      fieldRect.top,
      greaterThanOrEqualTo(-1),
      reason: 'Focusované pole nesmí zmizet nahoru',
    );
    expect(
      fieldRect.bottom,
      lessThanOrEqualTo(limit + 1),
      reason: 'Focusované pole musí zůstat nad klávesnicí',
    );
    for (final key in const [
      ValueKey('probe_cancel'),
      ValueKey('probe_ok'),
    ]) {
      final r = tester.getRect(find.byKey(key));
      expect(
        r.bottom,
        lessThanOrEqualTo(limit + 1),
        reason: 'Tlačítko $key nesmí být pod klávesnicí',
      );
    }
  }

  group('Stabilita dialogu s klávesnicí', () {
    testWidgets('1) dialog bez klávesnice se chová jako dřív', (tester) async {
      final state = await pumpApp(tester);
      openProbeDialog(state, appContext(tester));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      // Žádný globální workaround: dialog zůstává přesně tak, jak byl
      // autorem napsán (fixní titulek, scrollovatelný obsah).
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.scrollable, isFalse);
      expect(dialog.content, isA<SingleChildScrollView>());
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('probe_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('2) dialog s otevřenou klávesnicí zůstane stabilní', (
      tester,
    ) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_0')));
      await tester.pumpAndSettle();

      // Žádná globální konverze scrollable: struktura dialogu je daná
      // jeho autorem, framework sám řeší keyboard inset právě jednou.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.scrollable, isFalse);
      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_0'),
        titleText: 'Probe dialog',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('3) TextField nahoře zůstane viditelný', (tester) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester), fieldCount: 3);
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_0')));
      await tester.pumpAndSettle();

      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_0'),
        titleText: 'Probe dialog',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('4) TextField uprostřed zůstane viditelný', (tester) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester), fieldCount: 3);
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_1')));
      await tester.pumpAndSettle();

      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_1'),
        titleText: 'Probe dialog',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('5) TextField dole: titulek zůstane, pole i akce nad klávesnicí', (
      tester,
    ) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester), fieldCount: 3);
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_2')));
      await tester.pumpAndSettle();

      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_2'),
        titleText: 'Probe dialog',
      );
      // Titulek je fixní (není součástí scroll viewportu obsahu),
      // takže ensureVisible fokusovaného pole ho nevytlačí z viewportu.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final titleRect = tester.getRect(find.byWidget(dialog.title!));
      expect(
        titleRect.top,
        greaterThanOrEqualTo(-1),
        reason: 'Titulek dialogu musí zůstat v horní části',
      );
      expect(
        titleRect.bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight + 1),
        reason: 'Titulek nesmí být vytlačen pod klávesnici',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('6) malé zařízení 320x568 s klávesnicí', (tester) async {
      const screenHeight = 568.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(320, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_0')));
      await tester.pumpAndSettle();

      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_0'),
        titleText: 'Probe dialog',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('7) velké systémové písmo 2.0 s klávesnicí', (tester) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
        textScale: 2.0,
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_0')));
      await tester.pumpAndSettle();

      // Při 2.0× se dialog nesmí rozpadnout: pozice drží, akce dostupné,
      // pole viditelné (detaily měří expectStableAboveKeyboard níže).
      expectStableAboveKeyboard(
        tester,
        screenHeight: screenHeight,
        keyboardHeight: keyboardHeight,
        fieldKey: const ValueKey('probe_field_0'),
        titleText: 'Probe dialog',
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('8) po zavření klávesnice se dialog vrátí do normálu', (
      tester,
    ) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
      );
      tester.view.viewInsets = const FakeViewPadding(
        bottom: keyboardHeight,
      );
      await tester.pump();
      tester.takeException();

      openProbeDialog(state, appContext(tester));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byKey(const ValueKey('probe_field_0')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isFalse,
      );
      // Overflow těla aplikace za bariérou je očekávaný (viz helper).
      tester.takeException();

      // Klávesnice se zavře.
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.testTextInput.hide();
      await tester.pumpAndSettle();

      // Dialog zůstává ve své autorské struktuře (žádný globální
      // workaround, který by se musel vracet), je celý viditelný
      // a zavíratelný.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
        isFalse,
        reason: 'Struktura dialogu se zavřením klávesnice nemění',
      );
      final titleRect = tester.getRect(find.text('Probe dialog'));
      expect(titleRect.top, greaterThanOrEqualTo(-1));
      final cancelRect = tester.getRect(
        find.byKey(const ValueKey('probe_cancel')),
      );
      expect(cancelRect.bottom, lessThanOrEqualTo(screenHeight + 1));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('probe_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
