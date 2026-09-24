import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';

void main() {
  group('AccessibilitySettings copyWith independence', () {
    test('copyWith creates independent instance – fontSizeMultiplier', () {
      final a = AccessibilitySettings.defaultsStandard();
      final b = a.copyWith(fontSizeMultiplier: 2.0);
      expect(a.fontSizeMultiplier, 1.0);
      expect(b.fontSizeMultiplier, 2.0);
      expect(identical(a, b), isFalse);
    });

    test('copyWith deep copies ttsVoice map', () {
      final a = AccessibilitySettings.defaultsStandard().copyWith(
        ttsVoice: {'name': 'voice1', 'locale': 'cs-CZ'},
        ttsVoiceName: 'voice1',
      );
      final b = a.copyWith();
      // mutate b's voice via new map
      final c = b.copyWith(ttsVoice: {'name': 'voice2', 'locale': 'en-US'});
      expect(a.ttsVoice!['name'], 'voice1');
      expect(b.ttsVoice!['name'], 'voice1');
      expect(c.ttsVoice!['name'], 'voice2');
      // ensure not shared reference
      b.ttsVoice!['name'] = 'mutated';
      expect(a.ttsVoice!['name'], 'voice1');
    });

    test('defaults factories create independent instances', () {
      final a = AccessibilitySettings.defaultsBlind();
      final b = AccessibilitySettings.defaultsBlind();
      expect(identical(a, b), isFalse);
      final c = b.copyWith(speechRate: 0.9);
      expect(a.speechRate, 0.5);
      expect(c.speechRate, 0.9);
    });

    test('profile copyWith does not share settings', () {
      final base = AccessibilitySettings.defaultsStandard();
      final p1 = AccessibilityProfile(
        id: 'a',
        name: 'A',
        settings: base,
        isBuiltIn: false,
      );
      final p2 = AccessibilityProfile(
        id: 'b',
        name: 'B',
        settings: base,
        isBuiltIn: false,
      );
      // p1 and p2 currently share same base instance – copyWith should break sharing
      final p1Updated = p1.copyWith(
        settings: p1.settings.copyWith(fontSizeMultiplier: 2.5),
      );
      expect(p1.settings.fontSizeMultiplier, 1.0);
      expect(p1Updated.settings.fontSizeMultiplier, 2.5);
      expect(p2.settings.fontSizeMultiplier, 1.0);
    });

    test('settings JSON roundtrip', () {
      final orig = AccessibilitySettings.defaultsLowVision().copyWith(
        speechRate: 0.77,
        ttsVoice: {'name': 'v', 'locale': 'cs-CZ'},
        ttsVoiceName: 'v',
        inverseFormatPreference: 0,
      );
      final json = orig.toJson();
      final restored = AccessibilitySettings.fromJson(json);
      expect(restored.fontSizeMultiplier, orig.fontSizeMultiplier);
      expect(restored.speechRate, orig.speechRate);
      expect(restored.ttsVoice, orig.ttsVoice);
      expect(restored.inverseFormatPreference, 0);
      expect(restored.thousandGroupGap, orig.thousandGroupGap);
    });
  });
}
