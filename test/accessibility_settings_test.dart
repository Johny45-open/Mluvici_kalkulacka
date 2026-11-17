import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';

void main() {
  group('AccessibilitySettings profile-only model', () {
    test('copyWith creates independent profile settings', () {
      final standard = AccessibilitySettings.defaultsStandard();
      final updated = standard.copyWith(fontSizeMultiplier: 2.0);
      expect(standard.fontSizeMultiplier, 1.0);
      expect(updated.fontSizeMultiplier, 2.0);
      expect(identical(standard, updated), isFalse);
    });

    test('profile serialization excludes global settings', () {
      final settings = AccessibilitySettings.fromJson({
        ...AccessibilitySettings.defaultsStandard().toJson(),
        'screenReaderMode': 1,
        'ttsEnabled': false,
        'speechRate': 0.8,
        'resultDisplayMode': 2,
        'announceFractionAvailability': false,
      });
      final json = settings.toJson();
      expect(json.containsKey('screenReaderMode'), isFalse);
      expect(json.containsKey('ttsEnabled'), isFalse);
      expect(json.containsKey('speechRate'), isFalse);
      expect(json.containsKey('resultDisplayMode'), isFalse);
      expect(json.containsKey('announceFractionAvailability'), isFalse);
    });

    test('profile JSON roundtrip preserves profile values', () {
      final original = AccessibilitySettings.defaultsLowVision().copyWith(
        dialogFontScale: 2.2,
        inverseFormatPreference: 0,
      );
      final restored = AccessibilitySettings.fromJson(original.toJson());
      expect(restored.dialogFontScale, 2.2);
      expect(restored.inverseFormatPreference, 0);
      expect(restored.thousandGroupGap, original.thousandGroupGap);
    });
  });

  group('GlobalSettings', () {
    test('copyWith and JSON preserve global values independently', () {
      final original = GlobalSettings.defaults().copyWith(
        screenReaderMode: ScreenReaderMode.on,
        ttsEnabled: false,
        speechRate: 0.0 + 0.5,
        speechVolume: 0.0,
        ttsVoice: {'name': 'voice', 'locale': 'cs-CZ'},
        ttsVoiceName: 'voice',
        resultDisplayMode: ResultDisplayMode.auto,
        announceFractionAvailability: false,
        themeMode: ThemeMode.light,
      );
      final restored = GlobalSettings.fromJson(original.toJson());
      expect(restored.screenReaderMode, ScreenReaderMode.on);
      expect(restored.ttsEnabled, isFalse);
      expect(restored.speechRate, 0.5);
      expect(restored.speechVolume, 0.0);
      expect(restored.ttsVoice, {'name': 'voice', 'locale': 'cs-CZ'});
      expect(restored.ttsVoiceName, 'voice');
      expect(restored.resultDisplayMode, ResultDisplayMode.auto);
      expect(restored.announceFractionAvailability, isFalse);
      expect(restored.themeMode, ThemeMode.light);

      final changed = original.copyWith(ttsEnabled: true);
      expect(original.ttsEnabled, isFalse);
      expect(changed.ttsEnabled, isTrue);
    });
  });
}
