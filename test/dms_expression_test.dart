import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DMS expression components and operator boundaries', (
    tester,
  ) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({'modeQuestionAsked': true});

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (call) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;

    expect(state.evaluateExpressionForTest('30°'), closeTo(30, 1e-12));
    expect(
      state.evaluateExpressionForTest("30°25'"),
      closeTo(30 + 25 / 60, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('30°25\'12"'),
      closeTo(30 + 25 / 60 + 12 / 3600, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('30°25"'),
      closeTo(30 + 25 / 3600, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('30°25'),
      closeTo(30 + 25 / 60, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('-30°25'),
      closeTo(-(30 + 25 / 60), 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('30.5°25.5'),
      closeTo(30.5 + 25.5 / 60, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('30°25+5'),
      closeTo(30 + 25 / 60 + 5, 1e-12),
    );
    expect(
      state.evaluateExpressionForTest('2*30°25'),
      closeTo(2 * (30 + 25 / 60), 1e-12),
    );
    expect(state.evaluateExpressionForTest('30+25'), closeTo(55, 1e-12));
  });
}
