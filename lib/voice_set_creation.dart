part of 'main.dart';

/// Řízený hlasový rozhovor, který vytvoří novou statistickou sadu:
/// zeptá se na název sady, poté postupně na názvy polí a sadu uloží.
/// Během celého rozhovoru fungují příkazy „zrušit" a „zopakuj".
class _VoiceSetCreationSession {
  _VoiceSetCreationSession(this.parent);

  final _CalculatorScreenState parent;

  SpeechToText? _stt;
  bool _recognizerAvailable = false;
  bool listening = false;
  bool finished = false;

  String _name = '';
  final List<String> _fields = <String>[];
  int _attempts = 0;
  Completer<String?>? _resultCompleter;

  static const int _maxFields = 10;
  static const int _maxAttempts = 3;

  Future<void> start() async {
    if (parent._currentMode != CalculatorMode.statistics) {
      parent._changeMode(CalculatorMode.statistics);
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    _recognizerAvailable = await _ensureRecognizer();
    if (!mounted) return;
    if (!_recognizerAvailable) {
      _announceUnavailable();
      return;
    }
    await _askSetName();
  }

  bool get mounted => !finished && parent.mounted;

  Future<bool> _ensureRecognizer() async {
    final stt = _stt ??= SpeechToText();
    if (stt.isAvailable) return true;
    try {
      return await stt.initialize(
        onError: (error) => _completeResult(null),
        onStatus: (status) {
          // Některá zařízení ukončí poslech bez doručení výsledku.
          if (status == 'done' || status == 'notListening') {
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              _completeResult(null);
            });
          }
        },
        debugLogging: false,
      );
    } catch (_) {
      return false;
    }
  }

  void _completeResult(String? value) {
    final completer = _resultCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  void _announceUnavailable() {
    finished = true;
    parent._onVoiceSessionEnded();
    parent.speak(
      parent._s(
        'Hlasové rozpoznávání není dostupné nebo nebylo povoleno oprávnění k '
        'mikrofonu. Zkontrolujte oprávnění aplikace v nastavení systému, nebo '
        'sadu vytvořte ručně tlačítkem SETS.',
        'Speech recognition is not available or the microphone permission was '
        'not granted. Check the app permissions in system settings, or create '
        'the set manually using the SETS button.',
      ),
      force: true,
    );
    if (parent.mounted) {
      ScaffoldMessenger.of(parent.context).showSnackBar(
        SnackBar(
          content: Text(
            parent._s(
              'Hlasové rozpoznávání není dostupné.',
              'Speech recognition is not available.',
            ),
          ),
        ),
      );
    }
  }

  /// Přečte výzvu a počká, dokud nedoběhne syntéza řeči (s pojistným
  /// časovým limitem), aby mikrofon nezachycoval vlastní otázky aplikace.
  Future<void> _speakAndWait(String text) async {
    await parent.tts.stop();
    final willSpeak = parent.ttsEnabled;
    if (!willSpeak) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return;
    }
    final done = Completer<void>();
    var completed = false;
    void finish() {
      if (!completed) {
        completed = true;
        done.complete();
      }
    }

    parent.tts.setCompletionHandler(finish);
    parent.speak(text, force: true);
    // Pojistný odhad délky promluvy pro případ, že completion handler nedorazí.
    final estimate = Duration(milliseconds: 800 + text.length * 75);
    await done.future.timeout(estimate, onTimeout: finish);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<String?> _listenOnce(String prompt) async {
    await _speakAndWait(prompt);
    if (!mounted) return null;

    final completer = Completer<String?>();
    _resultCompleter = completer;
    _setListening(true);
    try {
      await _stt!.listen(
        onResult: (result) {
          if (result.finalResult && !completer.isCompleted) {
            completer.complete(result.recognizedWords.trim());
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          localeId: parent._isEnglish() ? 'en-US' : 'cs-CZ',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }

    String? heard;
    try {
      heard = await completer.future.timeout(const Duration(seconds: 16));
    } on TimeoutException {
      heard = null;
    }
    await _stopListening();
    _setListening(false);
    if (!mounted) return null;
    if (heard == null || heard.isEmpty) return null;
    return heard;
  }

  Future<void> _stopListening() async {
    try {
      await _stt?.stop();
    } catch (_) {}
  }

  void _setListening(bool value) {
    if (listening == value) return;
    listening = value;
    // ignore: invalid_use_of_protected_member
    if (parent.mounted) parent.setState(() {});
  }

  Future<void> _askSetName() async {
    final heard = await _listenOnce(
      parent._s(
        'Hlasové vytvoření statistické sady. Řekněte název nové sady.',
        'Voice creation of a statistics set. Say the name of the new set.',
      ),
    );
    if (!mounted) return;
    if (_handleCancel(heard)) return;
    if (heard == null) {
      await _retryOrAbort(_askSetName);
      return;
    }
    if (_isRepeat(heard)) {
      await _askSetName();
      return;
    }
    _attempts = 0;
    await _confirmSetName(heard);
  }

  Future<void> _confirmSetName(String proposedName) async {
    _name = proposedName;
    final heard = await _listenOnce(
      parent._s(
        'Název sady: $proposedName. Potvrďte slovem ano, nebo řekněte název znovu.',
        'Set name: $proposedName. Confirm by saying yes, or say the name again.',
      ),
    );
    if (!mounted) return;
    if (_handleCancel(heard)) return;
    if (heard == null) {
      await _retryOrAbort(() => _confirmSetName(proposedName));
      return;
    }
    if (_isYes(heard)) {
      _attempts = 0;
      await _askFieldName(0);
      return;
    }
    if (_isRepeat(heard) || _isNo(heard)) {
      _attempts = 0;
      await _askSetName();
      return;
    }
    // Jiná odpověď se chápe jako opravený název.
    _attempts = 0;
    await _confirmSetName(heard);
  }

  Future<void> _askFieldName(int index) async {
    final heard = await _listenOnce(
      parent._s(
        'Řekněte název ${_fieldOrdinal(index)} pole.',
        'Say the name of the ${_fieldOrdinalEn(index)} field.',
      ),
    );
    if (!mounted) return;
    if (_handleCancel(heard)) return;
    if (heard == null) {
      await _retryOrAbort(() => _askFieldName(index));
      return;
    }
    if (_isRepeat(heard)) {
      await _askFieldName(index);
      return;
    }
    _attempts = 0;
    await _confirmFieldName(index, heard);
  }

  Future<void> _confirmFieldName(int index, String proposedName) async {
    final heard = await _listenOnce(
      parent._s(
        'Pole: $proposedName. Potvrďte slovem ano, nebo řekněte název znovu.',
        'Field: $proposedName. Confirm by saying yes, or say the name again.',
      ),
    );
    if (!mounted) return;
    if (_handleCancel(heard)) return;
    if (heard == null) {
      await _retryOrAbort(() => _confirmFieldName(index, proposedName));
      return;
    }
    if (_isYes(heard)) {
      _attempts = 0;
      _fields.add(proposedName);
      await _askAnotherField();
      return;
    }
    if (_isNo(heard)) {
      _attempts = 0;
      await _askFieldName(index);
      return;
    }
    if (_isRepeat(heard)) {
      await _askFieldName(index);
      return;
    }
    // Jiná odpověď se chápe jako opravený název pole.
    _attempts = 0;
    await _confirmFieldName(index, heard);
  }

  Future<void> _askAnotherField() async {
    if (_fields.length >= _maxFields) {
      await _finishCreation();
      return;
    }
    final count = _fields.length;
    final heard = await _listenOnce(
      parent._s(
        '$count. pole uloženo. Chcete přidat další pole? Řekněte ano, nebo ne.',
        'Field number $count saved. Do you want to add another field? Say yes or no.',
      ),
    );
    if (!mounted) return;
    if (_handleCancel(heard)) return;
    if (heard == null) {
      await _retryOrAbort(_askAnotherField);
      return;
    }
    if (_isYes(heard)) {
      _attempts = 0;
      await _askFieldName(_fields.length);
      return;
    }
    if (_isNo(heard)) {
      _attempts = 0;
      await _finishCreation();
      return;
    }
    await _retryOrAbort(_askAnotherField);
  }

  Future<void> _finishCreation() async {
    final defaultName = parent._l10n.statsSetDefaultName(
      parent._statsSets.length + 1,
    );
    final name = _name.trim().isEmpty ? defaultName : _name.trim();
    final fieldNames =
        _fields.isEmpty ? <String>[parent._s('Hodnota', 'Value')] : _fields;

    // ignore: invalid_use_of_protected_member
    parent.setState(() {
      parent._statsSets.add(
        StatisticsSet(
          name: name,
          fieldNames: List<String>.of(fieldNames),
          records: <StatisticsRecord>[],
        ),
      );
      parent._currentStatsSetIndex = parent._statsSets.length - 1;
      parent._selectedFieldIndex = 0;
    });
    parent._saveStatsData();

    finished = true;
    parent._onVoiceSessionEnded();
    final fieldsSpoken = fieldNames.join(', ');
    parent.speak(
      parent._s(
        'Sada $name byla vytvořena. Pole: $fieldsSpoken. Hodnoty můžete '
        'přidávat tlačítkem M plus.',
        'Set $name was created. Fields: $fieldsSpoken. You can add values '
        'using the M+ button.',
      ),
      force: true,
    );
  }

  bool _handleCancel(String? heard) {
    if (heard != null && _isCancel(heard)) {
      cancelByUser();
      return true;
    }
    return false;
  }

  void cancelByUser() {
    _abortWithMessage(
      parent._s(
        'Hlasové vytvoření sady bylo zrušeno.',
        'Voice set creation was cancelled.',
      ),
    );
  }

  void _abortWithMessage(String message) {
    finished = true;
    _completeResult(null);
    unawaited(_stopListening());
    listening = false;
    parent._onVoiceSessionEnded();
    parent.speak(message, force: true);
  }
  Future<void> _retryOrAbort(Future<void> Function() retryAsk) async {
    _attempts++;
    if (_attempts >= _maxAttempts) {
      _abortWithMessage(
        parent._s(
          'Nerozuměl jsem vám. Hlasové vytváření ukončuji. Sadu můžete '
          'vytvořit ručně tlačítkem SETS.',
          "I could not understand you. Ending voice creation. You can create "
          'the set manually using the SETS button.',
        ),
      );
      return;
    }
    await retryAsk();
  }

  void dispose() {
    finished = true;
    _completeResult(null);
    unawaited(_stopListening());
  }

  String _fieldOrdinal(int index) {
    const ordinals = [
      'první',
      'druhé',
      'třetí',
      'čtvrté',
      'páté',
      'šesté',
      'sedmé',
      'osmé',
      'deváté',
      'desáté',
    ];
    if (index < ordinals.length) return ordinals[index];
    return '${index + 1}.';
  }

  String _fieldOrdinalEn(int index) {
    const ordinals = [
      'first',
      'second',
      'third',
      'fourth',
      'fifth',
      'sixth',
      'seventh',
      'eighth',
      'ninth',
      'tenth',
    ];
    if (index < ordinals.length) return ordinals[index];
    return '${index + 1}';
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[.,!?;:"]'), '').trim();
  }

  bool _isYes(String text) {
    final t = _normalize(text);
    return t == 'ano' ||
        t == 'jo' ||
        t == 'áno' ||
        t == 'ano prosím' ||
        t == 'yes' ||
        t == 'yeah' ||
        t == 'yep' ||
        t == 'sure' ||
        t == 'ok';
  }

  bool _isNo(String text) {
    final t = _normalize(text);
    return t == 'ne' ||
        t == 'ne ne' ||
        t == 'no' ||
        t == 'nope' ||
        t == 'nah';
  }

  bool _isCancel(String text) {
    final t = _normalize(text);
    return t.contains('zruš') ||
        t == 'stop' ||
        t == 'zastav' ||
        t == 'zastavit' ||
        t == 'konec' ||
        t.contains('cancel') ||
        t == 'abort';
  }

  bool _isRepeat(String text) {
    final t = _normalize(text);
    return t.contains('zopakuj') ||
        t.contains('znovu') ||
        t.contains('repeat') ||
        t.contains('again');
  }
}
