import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cílené testy pro řádek verze v Nastavení přístupnosti a 7-tap aktivaci
/// vývojářského režimu (obnova vazby smazané v 3b554d3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const packageChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  void mockChannels({Future<Map<String, Object>> Function()? packageInfo}) {
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
    messenger.setMockMethodCallHandler(packageChannel, (MethodCall call) async {
      if (packageInfo != null) return packageInfo();
      return <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      };
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(packageChannel, null);
    });
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> openAccessibility(WidgetTester tester, dynamic state) async {
    state.showAccessibilityDialogForTest();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsWidgets);
  }

  Finder versionText() => find.text('v6.2.0+1');

  /// 7 aktivací řádku verze uvnitř 2s okna čítače.
  Future<void> tapVersionSevenTimes(WidgetTester tester) async {
    for (var i = 0; i < 7; i++) {
      await tester.tap(versionText());
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<void> enterPinAndConfirm(
    WidgetTester tester,
    List<String> pins,
  ) async {
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(pins.length));
    for (var i = 0; i < pins.length; i++) {
      await tester.enterText(fields.at(i), pins[i]);
      await tester.pump();
    }
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
  }

  group('Version row', () {
    // POZOR: package_info_plus staticky cachuje fromPlatform v rámci
    // izolátu – tento test MUSÍ běžet jako první v souboru, jinak by
    // cache z předchozího testu delayed-load znemožnila.
    testWidgets('opens safely before PackageInfo loads, then updates', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      final completer = Completer<Map<String, Object>>();
      mockChannels(packageInfo: () => completer.future);
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pump();

      final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      state.showAccessibilityDialogForTest();
      // Obsah dialogu (profily…) se dostaví během pár framů.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Bez pádu (žádný LateInitializationError), zatím stav načítání.
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsWidgets);
      expect(find.text('Loading version…'), findsOneWidget);
      expect(versionText(), findsNothing);

      completer.complete(<String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      });
      await tester.pumpAndSettle();

      // Otevřený dialog se překreslil na skutečnou verzi.
      expect(tester.takeException(), isNull);
      expect(versionText(), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('shows version including build number', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      expect(versionText(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('single accessible button with version in label', (
      tester,
    ) async {
      final semHandle = tester.ensureSemantics();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      // Přístupný popisek obsahuje číslo verze i instrukci.
      final labeled = find.bySemanticsLabel(
        'App version v6.2.0+1, tap 7 times for developer mode',
      );
      expect(labeled, findsOneWidget);

      // Právě jeden Semantics uzel nese verzi v popisku a je tlačítko:
      // žádný duplicitní popisek/akce.
      final semWidgets = tester.widgetList<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics && (w.properties.label ?? '').contains('6.2.0+1'),
        ),
      );
      expect(semWidgets, hasLength(1));
      expect(semWidgets.single.properties.button, isTrue);
      semHandle.dispose();
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Seven-tap dev activation', () {
    testWidgets('fewer than seven taps opens nothing', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      for (var i = 0; i < 6; i++) {
        await tester.tap(versionText());
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump();
      expect(find.text('Set PIN'), findsNothing);
      expect(find.text('Enter PIN'), findsNothing);
      expect(find.text('Developer mode'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('seven taps without PIN opens PIN creation', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      await tapVersionSevenTimes(tester);
      expect(find.text('Set PIN'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('created PIN activates dev mode without extra dialog', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      await tapVersionSevenTimes(tester);
      await enterPinAndConfirm(tester, ['1234', '1234']);

      // Stávající chování create-flow: PIN uložen, režim aktivován,
      // jediné oznámení snackbarem – dialog vývojáře se sám neotevírá
      // (ten patří až verify-flow / již aktivnímu režimu).
      expect(find.text('Developer mode'), findsNothing);
      expect(find.text('PIN set'), findsOneWidget);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('devPinCode'), '1234');
      expect(prefs.getBool('devModeEnabled'), isTrue);

      // Následná aktivace jde rovnou do dialogu vývojáře bez PINu.
      await tapVersionSevenTimes(tester);
      expect(find.text('Developer mode'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('seven taps with PIN asks verification; wrong PIN fails', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'devPinCode': '1234',
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      await tapVersionSevenTimes(tester);
      expect(find.text('Enter PIN'), findsOneWidget);

      await enterPinAndConfirm(tester, ['0000']);
      expect(find.text('Incorrect PIN'), findsOneWidget);
      expect(find.text('Developer mode'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('correct PIN activates dev mode and opens its dialog', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'devPinCode': '1234',
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      await tapVersionSevenTimes(tester);
      await enterPinAndConfirm(tester, ['1234']);

      expect(find.text('Developer mode'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('devModeEnabled'), isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('active dev mode opens dev dialog without PIN', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'devPinCode': '1234',
        'devModeEnabled': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      await tapVersionSevenTimes(tester);
      expect(find.text('Developer mode'), findsOneWidget);
      expect(find.text('Enter PIN'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('repeated failures keep lockout protection', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'devPinCode': '1234',
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openAccessibility(tester, state);

      for (var attempt = 0; attempt < 5; attempt++) {
        await tapVersionSevenTimes(tester);
        expect(find.text('Enter PIN'), findsOneWidget);
        await enterPinAndConfirm(tester, ['0000']);
        expect(find.text('Incorrect PIN'), findsOneWidget);
        // Zavřít verify dialog pro další pokus.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }

      // 6. aktivace během 30s locku: žádný PIN dialog, jen lock hláška.
      await tapVersionSevenTimes(tester);
      expect(find.text('Enter PIN'), findsNothing);
      expect(find.text('Set PIN'), findsNothing);
      expect(find.text('Developer mode'), findsNothing);
      expect(find.text('Too many attempts, try later.'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('devModeEnabled'), isNot(true));
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
