import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/voice_round_tracker.dart';

/// Životní cyklus poslechových kol (část B).
///
/// Skupina 1 – skutečná kritéria opravy: co tracker a zapojení session
/// garantují (hint nikdy nedokončuje, milost je zrušitelná, TTS-okno a
/// ukončení jsou imunní, každé kolo se dokončí nejvýše jednou).
///
/// Skupina 2 – charakterizační testy ZNÁMÉHO OMEZENÍ knihovny
/// speech_to_text (bez id relace): nejsou kritérii ochrany, pouze
/// dokumentují hranici, kterou API neumožňuje překročit.
///
/// Simulace kopíruje přesné brány produkčního zapojení
/// (`voice_set_creation.dart`: beginRound → TTS → Completer → activate →
/// acceptFinal/armHint → closeRound před stop()).
///
/// Časování: reálné krátké milosti (10–20 ms) s velkorysou rezervou čekání;
/// žádná závislost na balíčku pro virtuální čas.
void main() {
  const testGrace = Duration(milliseconds: 20);

  VoiceRoundTracker newTracker({void Function(int)? onExpired}) {
    final tracker = VoiceRoundTracker(graceDuration: testGrace);
    if (onExpired != null) tracker.onGraceExpired = onExpired;
    return tracker;
  }

  group('ochrana kol (kritéria opravy)', () {
    test('hint před finálem: finále v milosti vyhrává, milost se ruší',
        () async {
      int expirations = 0;
      final tracker = newTracker(onExpired: (_) => expirations++);
      final completer = Completer<String?>();

      final g = tracker.beginRound();
      // TTS mezera: hint sem neprojde.
      expect(tracker.armHint(g, pending: true), isFalse);
      tracker.activate(g);
      // done bez výsledku → pouze milost, žádné dokončení.
      expect(tracker.armHint(g, pending: !completer.isCompleted), isTrue);
      expect(completer.isCompleted, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Finále v letu dorazí v milosti → přijato, milost zrušena.
      expect(tracker.acceptFinal(g), isTrue);
      completer.complete('ano');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expirations, 0);
      expect(completer.isCompleted, isTrue);
    });

    test('obvyklé pořadí finále → done: hint po finále je no-op', () async {
      int expirations = 0;
      final tracker = newTracker(onExpired: (_) => expirations++);
      final g = tracker.beginRound();
      tracker.activate(g);
      expect(tracker.acceptFinal(g), isTrue);
      expect(tracker.armHint(g, pending: true), isFalse);
      expect(tracker.hasPendingGrace, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expirations, 0);
    });

    test('opožděný notListening během TTS nové otázky je ignorován',
        () async {
      int expirations = 0;
      final tracker = newTracker(onExpired: (_) => expirations++);
      // Kolo N úspěšně skončilo.
      final gN = tracker.beginRound();
      tracker.activate(gN);
      expect(tracker.acceptFinal(gN), isTrue);
      tracker.closeRound(gN);
      // Kolo N+1: TTS mezera (neaktivní).
      final gNext = tracker.beginRound();
      expect(gNext, isNot(gN));
      // Starý hint během TTS: ignorován (neaktivní kolo).
      expect(tracker.armHint(gN, pending: true), isFalse);
      expect(tracker.armHint(gNext, pending: true), isFalse);
      expect(tracker.hasPendingGrace, isFalse);
      // Nový poslech dostane svou odpověď.
      tracker.activate(gNext);
      expect(tracker.acceptFinal(gNext), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expirations, 0);
    });

    test('stará onError na ukončeném kole je no-op', () async {
      int expirations = 0;
      final tracker = newTracker(onExpired: (_) => expirations++);
      final g = tracker.beginRound();
      tracker.activate(g);
      tracker.closeRound(g);
      expect(tracker.armHint(g, pending: true), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expirations, 0);
    });

    test('nový poslech po úspěchu: starý timer je zrušen', () async {
      final expired = <int>[];
      final tracker = newTracker(onExpired: expired.add);
      final gN = tracker.beginRound();
      tracker.activate(gN);
      expect(tracker.armHint(gN, pending: true), isTrue);
      // Start kola N+1 ruší milost kola N.
      final gNext = tracker.beginRound();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expired, isEmpty);
      tracker.activate(gNext);
      expect(tracker.acceptFinal(gNext), isTrue);
    });

    test('opakovaný hint: jedna milost, jedno dokončení', () async {
      final completer = Completer<String?>();
      int completions = 0;
      final tracker = newTracker();
      tracker.onGraceExpired = (g) {
        if (g != tracker.generation || !tracker.isActive) return;
        if (tracker.gotFinal) return;
        if (!completer.isCompleted) {
          completions++;
          completer.complete(null);
        }
      };
      final g = tracker.beginRound();
      tracker.activate(g);
      expect(tracker.armHint(g, pending: true), isTrue);
      // Druhý hint (např. done po erroru s cancelOnError): odmítnut.
      expect(tracker.armHint(g, pending: true), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(completions, 1);
      expect(completer.isCompleted, isTrue);
      tracker.closeRound(g);
    });

    test('shutdown (zrušení/dispose) ignoruje hinty a ruší milost', () async {
      int expirations = 0;
      final tracker = newTracker(onExpired: (_) => expirations++);
      final g = tracker.beginRound();
      tracker.activate(g);
      expect(tracker.armHint(g, pending: true), isTrue);
      tracker.shutdown();
      expect(tracker.armHint(g, pending: true), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(expirations, 0);
    });

    test('skutečné ticho: milost vyprší včas, ne až za 16 s', () async {
      final completer = Completer<String?>();
      final tracker = newTracker();
      tracker.onGraceExpired = (g) {
        if (g != tracker.generation || !tracker.isActive) return;
        if (!completer.isCompleted) completer.complete(null);
      };
      final g = tracker.beginRound();
      tracker.activate(g);
      expect(tracker.armHint(g, pending: true), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(completer.isCompleted, isTrue);
      tracker.closeRound(g);
    });
  });

  group('známá omezení knihovny (charakterizace, NE kritéria)', () {
    test(
        'CHARAKTERIZACE: staré finále doručené do nového aktivního kola '
        'tracker přijme — původ slov API nerozliší', () {
      final tracker = newTracker();
      final gN = tracker.beginRound();
      tracker.activate(gN);
      tracker.closeRound(gN);
      // Nové kolo již skutečně poslouchá; platforma opožděně doručí
      // FINÁLE STARÉ relace do uzávěrky nového kola (jediný globální slot
      // onResult). Tracker generaci nového kola potvrdí: původ slov
      // nelze ověřit, toto přijetí je zdokumentované reziduum, nikoli
      // důkaz ochrany před starými výsledky.
      final gNext = tracker.beginRound();
      tracker.activate(gNext);
      expect(tracker.acceptFinal(gNext), isTrue);
    });
  });
}
