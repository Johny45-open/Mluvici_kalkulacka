import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void mockChannels() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (MethodCall call) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.example.mluvici_kalkulacka/accessibility'), (MethodCall call) async {
      if (call.method == 'isTalkBackEnabled' || call.method == 'isScreenReaderEnabled') return false;
      return false;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (MethodCall call) async => <String, Object>{
      'appName': 'mluvici_kalkulacka',
      'packageName': 'com.example.mluvici_kalkulacka',
      'version': '6.2.0',
      'buildNumber': '1',
    });
  }
  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }
  group('Editing draft', () {
    testWidgets('B theme revert', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true, 'themeMode': ThemeMode.light.index});
      mockChannels();
      dynamic state = await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      final beforeV2 = (await SharedPreferences.getInstance()).getString('accessibility_profiles_v2');
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.9, dialogFontScale: 2.0, speechVolume: 0.3, accessibilityType: AccessibilityType.visuallyImpaired));
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest.settings.speechRate, 0.9);
      expect(state.dialogFontScaleNotifierForTest.value, 2.0);
      expect(state.themeModeForTest, ThemeMode.dark);
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, 0.5);
      final midV2 = (await SharedPreferences.getInstance()).getString('accessibility_profiles_v2');
      expect(midV2, beforeV2);
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNull);
      expect(state.dialogFontScaleNotifierForTest.value, 1.0);
      expect(state.themeModeForTest, ThemeMode.light);
      final afterV2 = (await SharedPreferences.getInstance()).getString('accessibility_profiles_v2');
      expect(afterV2, beforeV2);
    });
  });
}
