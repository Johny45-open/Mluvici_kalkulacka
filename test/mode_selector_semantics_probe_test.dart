import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sémantika fokusu u přepínače režimů. Chip má vlastní Semantics uzel
/// (`excludeSemantics`), takže příznak `focused` musí odpovídat skutečnému
/// klávesnicovému fokusu – jinak čtečka (NVDA/TalkBack) vidí zaměřený chip
/// jako nezaměřený.
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

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  /// Sémantický uzel chipu přepínače režimů podle popisku.
  SemanticsNode chipNode(WidgetTester tester, String label) {
    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    SemanticsNode? found;
    void visit(SemanticsNode node) {
      final d = node.getSemanticsData();
      if (d.hasFlag(SemanticsFlag.isButton) && d.label == label) {
        found = node;
      }
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(owner.rootSemanticsNode!);
    expect(found, isNotNull, reason: 'Chip "$label" musí být v sémantice');
    return found!;
  }

  /// Focus uvnitř prvního chipu přepínače režimů.
  FocusNode firstChipFocusNode(WidgetTester tester) {
    final chip = find.byType(ChoiceChip).first;
    final text = find.descendant(of: chip, matching: find.byType(Text)).first;
    return Focus.of(tester.element(text));
  }

  testWidgets('zaměřený chip hlásí isFocused, nezaměřený ne', (tester) async {
    final handle = tester.ensureSemantics();
    final state = await pumpApp(tester);

    // Výchozí stav: fokus je mimo přepínač, žádný chip není zaměřený.
    expect(chipNode(tester, 'Základní').getSemanticsData().flagsCollection
            .isFocused,
        isNot(Tristate.isTrue));

    // Fokus na chip.
    final chipFocus = firstChipFocusNode(tester);
    chipFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(chipFocus.hasPrimaryFocus, isTrue);

    // Právě zaměřený chip hlásí isFocused, ostatní chipy ne.
    expect(
      chipNode(tester, 'Základní')
          .getSemanticsData()
          .flagsCollection
          .isFocused,
      Tristate.isTrue,
      reason: 'Zaměřený chip musí mít příznak isFocused',
    );
    expect(
      chipNode(tester, 'Vědecká').getSemanticsData().flagsCollection.isFocused,
      isNot(Tristate.isTrue),
      reason: 'Nezaměřený chip nesmí být označen jako isFocused',
    );

    // Fokus jinam (displejová proxy): chip přestává být zaměřený.
    (state.a11yProxyFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    expect(
      chipNode(tester, 'Základní')
          .getSemanticsData()
          .flagsCollection
          .isFocused,
      isNot(Tristate.isTrue),
      reason: 'Po odchodu fokusu chip přestává být isFocused',
    );

    handle.dispose();
  });

  testWidgets('po přepnutí režimu Enterem chip zůstává zaměřený a vybraný', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final state = await pumpApp(tester);

    final chipFocus = firstChipFocusNode(tester);
    chipFocus.requestFocus();
    await tester.pumpAndSettle();

    // Výchozí režim je scientific, první chip je „Základní".
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(state.currentModeForTest, CalculatorMode.basic);

    // Fokus zůstává na čipu a sémantika to potvrzuje.
    expect(identical(FocusManager.instance.primaryFocus, chipFocus), isTrue);
    expect(
      chipNode(tester, 'Základní').getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
      reason: 'Po přepnutí režimu chip zůstává isFocused',
    );

    // Výběr se v sémantice přesunul: nový chip selected, starý ne.
    expect(
      chipNode(tester, 'Základní')
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    expect(
      chipNode(tester, 'Vědecká')
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );

    handle.dispose();
  });
}
