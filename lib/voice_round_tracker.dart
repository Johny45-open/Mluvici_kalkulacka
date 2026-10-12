// Čistá stavová politika poslechových kol hlasového vytváření sad.
// Záměrně bez importu Flutteru a bez speech_to_text: musí být
// unit-testovatelná izolovaně.
//
// Generace je POUZE značka našich vlastních kol a časovačů — nikdy
// identifikátor původu platformní události. Ten veřejné API knihovny
// speech_to_text neposkytuje (globální onStatus/onError bez tagu kola,
// jediný globální slot onResult): opožděnou událost staré relace doručenou
// během nového aktivního kola nelze od čerstvé události rozlišit.
// Ochrana proto stojí na životním cyklu kola (aktivní/neaktivní),
// zrušitelném milostivém časovači a pravidle, že globální callbacky
// nikdy přímo nedokončují — dokončuje pouze vlastní finální výsledek
// vlastního kola, `null` pouze lokální časovače a záměrné ukončení
// (zrušení/dispose).
import 'dart:async';

class VoiceRoundTracker {
  VoiceRoundTracker({Duration? graceDuration})
    : graceDuration =
          graceDuration ?? const Duration(milliseconds: 2500);

  /// Milost po hintu (done/notListening/onError): dává finále v letu šanci
  /// dorazit dřív, než kolo padne do `null`. Délka není náhodná: kryje
  /// 2s final-promotion pluginu (stop → dodatečné finále) + jitter doručení.
  final Duration graceDuration;

  /// Volá session při vypršení milosti; session dokončí `null` pod svými
  /// branami (stejné kolo, aktivní, pending, bez finále).
  void Function(int generation)? onGraceExpired;

  int _generation = 0;
  bool _active = false;
  bool _gotFinal = false;
  Timer? _graceTimer;

  int get generation => _generation;
  bool get isActive => _active;
  bool get gotFinal => _gotFinal;
  bool get hasPendingGrace => _graceTimer != null;

  /// Nové kolo; zneplatní časovače předchozího. Volá se JEŠTĚ PŘED TTS
  /// mezerou, aby TTS patřila přicházejícímu kolu a zastaralé timery
  /// během ní nemohly zasáhnout.
  int beginRound() {
    _generation++;
    _active = false;
    _gotFinal = false;
    _cancelGrace();
    return _generation;
  }

  /// Poslechová fáze kola (po TTS, po vytvoření Completeru).
  void activate(int generation) {
    if (generation != _generation) return;
    _active = true;
    _gotFinal = false;
    _cancelGrace();
  }

  /// Vlastní finální výsledek. Vrátí true, pokud byl přijat (vlastní kolo,
  /// aktivní, první). Neruší nic kromě milosti — dokončení Completeru je
  /// věc session (at-most-once přes isCompleted).
  bool acceptFinal(int generation) {
    if (generation != _generation || !_active || _gotFinal) return false;
    _gotFinal = true;
    _cancelGrace();
    return true;
  }

  /// Hint z globálního callbacku (done/notListening/onError). Nikdy
  /// nedokončuje — pouze jednorázově na kolo nabije milost. Volající předá,
  /// zda je čekání kola stále pending (jinak hint patří ukončenému kolu).
  bool armHint(int generation, {required bool pending}) {
    if (generation != _generation || !_active || _gotFinal || !pending) {
      return false;
    }
    if (_graceTimer != null) return false;
    _graceTimer = Timer(graceDuration, () {
      _graceTimer = null;
      onGraceExpired?.call(generation);
    });
    return true;
  }

  /// Uzavření kola (po výsledku/timeoutu, PŘED stop()): vlastní stop→done
  /// pak padne do neaktivního kola a je ignorován.
  void closeRound(int generation) {
    if (generation != _generation) return;
    _active = false;
    _cancelGrace();
  }

  /// Zrušení/dispose: deaktivuje vše, ruší milost. Záměrné dokončení
  /// `null` pak provede session přímo (není to nejednoznačná událost
  /// rozpoznávače).
  void shutdown() {
    _active = false;
    _gotFinal = false;
    _cancelGrace();
  }

  void _cancelGrace() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }
}
