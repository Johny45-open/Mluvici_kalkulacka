import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// DOČASNÁ AUDITOVÁ SONDA – maže se po vyhodnocení.
// Vypíše sémantické uzly kolem zlomkových ovládačů pro rozhodnutí B1.
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
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  testWidgets('PROBE – výpis stromu', (tester) async {
    final handle = tester.ensureSemantics();
    final state = await pumpApp(tester);
    state.setDisplayForTest('1/3', 3);
    await tester.pump();
    state.calculateForTest();
    await tester.pumpAndSettle();

    // Widgetová očekávání
    String widgetLabel(String key) {
      final f = find.ancestor(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label ?? '').isNotEmpty,
        ),
      );
      if (f.evaluate().isEmpty) return '<žádný vnější Semantics>';
      return tester.widget<Semantics>(f.first).properties.label ?? '<null>';
    }

    debugPrint('PROBE widget insert label: ${widgetLabel('fraction_insert')}');
    debugPrint('PROBE widget toggle label: ${widgetLabel('fraction_toggle')}');

    final insertNode = tester.getSemantics(
      find.byKey(const ValueKey('fraction_insert')),
    );
    debugPrint('PROBE getSemantics(insert): [${insertNode.label}]');
    final toggleNode = tester.getSemantics(
      find.byKey(const ValueKey('fraction_toggle')),
    );
    debugPrint('PROBE getSemantics(toggle): [${toggleNode.label}]');

    final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    void walk(SemanticsNode n, int depth) {
      final l = n.label;
      final low = l.toLowerCase();
      if (depth > 1 && depth < 8) {
        final flags = <String>[
          if (n.hasFlag(SemanticsFlag.isButton)) 'button',
          if (n.hasFlag(SemanticsFlag.isFocusable)) 'focusable',
          if (n.hasFlag(SemanticsFlag.isToggled)) 'toggled',
          if (n.hasFlag(SemanticsFlag.isEnabled) == false &&
              n.hasFlag(SemanticsFlag.isButton)) 'DISABLED',
        ];
        final acts = <String>[
          if (n.getSemanticsData().hasAction(SemanticsAction.tap)) 'tap',
          if (n.getSemanticsData().hasAction(SemanticsAction.focus)) 'focus',
        ];
        debugPrint(
          'PROBE node depth=$depth id=${n.id} parent=${n.parent?.id} '
          'flags=[${flags.join(",")}] acts=[${acts.join(",")}] label=[$l]',
        );
      }
      n.visitChildren((SemanticsNode c) {
        walk(c, depth + 1);
        return true;
      });
    }

    walk(root, 0);
    debugPrint('PROBE – konec výpisu');
    expect(handle, isNotNull);
    handle.dispose();
  });
}