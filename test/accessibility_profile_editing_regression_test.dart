import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'modeQuestionAsked': true,
      'themeMode': ThemeMode.light.index,
    });
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
        'appName': 'calculator',
        'packageName': 'test',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  testWidgets('profile switching leaves global settings unchanged', (
    tester,
  ) async {
    final dynamic state = await pumpApp(tester);
    final settings = state.globalSettingsForTest as GlobalSettings;
    await state.updateGlobalSettingsForTest(
      (GlobalSettings value) => value.copyWith(
        screenReaderMode: ScreenReaderMode.off,
        ttsEnabled: false,
        speechRate: 0.8,
        speechVolume: 0.3,
        ttsVoice: {'name': 'voice', 'locale': 'cs-CZ'},
        ttsVoiceName: 'voice',
      ),
    );
    await tester.pumpAndSettle();
    final expected = state.globalSettingsForTest as GlobalSettings;

    state.switchProfileForTest('blind');
    await tester.pumpAndSettle();
    state.switchProfileForTest('lowvision');
    await tester.pumpAndSettle();
    state.switchProfileForTest('standard');
    await tester.pumpAndSettle();

    expect(
      state.globalSettingsForTest.screenReaderMode,
      expected.screenReaderMode,
    );
    expect(state.globalSettingsForTest.ttsEnabled, expected.ttsEnabled);
    expect(state.globalSettingsForTest.speechRate, expected.speechRate);
    expect(state.globalSettingsForTest.speechVolume, expected.speechVolume);
    expect(state.globalSettingsForTest.ttsVoice, expected.ttsVoice);
    expect(state.globalSettingsForTest.ttsVoiceName, expected.ttsVoiceName);
    expect(state.globalSettingsForTest, isNot(same(settings)));
  });

  testWidgets('editing a profile does not change global theme or speech', (
    tester,
  ) async {
    final dynamic state = await pumpApp(tester);
    final before = state.globalSettingsForTest as GlobalSettings;
    expect(state.themeModeForTest, ThemeMode.light);

    expect(state.startEditingForTest('lowvision'), isTrue);
    state.updateEditingForTest(
      (AccessibilitySettings settings) =>
          settings.copyWith(dialogFontScale: 2.0),
    );
    expect(await state.saveEditingForTest(), isTrue);
    await tester.pumpAndSettle();

    expect(state.globalSettingsForTest.themeMode, before.themeMode);
    expect(state.globalSettingsForTest.speechRate, before.speechRate);
    expect(state.themeModeForTest, ThemeMode.light);
    expect(
      state.profilesForTest
          .firstWhere((profile) => profile.id == 'lowvision')
          .settings
          .dialogFontScale,
      2.0,
    );
    final prefs = await SharedPreferences.getInstance();
    final savedProfiles = (prefs.getString('accessibility_profiles_v2')!);
    expect(savedProfiles, isNot(contains('"speechRate"')));
    expect(savedProfiles, isNot(contains('"ttsEnabled"')));
  });
}
