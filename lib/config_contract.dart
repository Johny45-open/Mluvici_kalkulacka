part of 'main.dart';

String _accessibilityTypeToString(AccessibilityType v) => v.name;
AccessibilityType _accessibilityTypeFromString(String s) {
  for (final v in AccessibilityType.values) if (v.name == s) return v;
  return AccessibilityType.none;
}
String _screenReaderModeToString(ScreenReaderMode v) => v.name;
ScreenReaderMode _screenReaderModeFromString(String s) {
  for (final v in ScreenReaderMode.values) if (v.name == s) return v;
  return ScreenReaderMode.auto;
}
String _gapToString(ThousandGroupGap v) => v.name;
ThousandGroupGap _gapFromString(String s) {
  for (final v in ThousandGroupGap.values) if (v.name == s) return v;
  return ThousandGroupGap.medium;
}
String _dialogSizeToString(DialogSize v) => v.name;
DialogSize _dialogSizeFromString(String s) {
  for (final v in DialogSize.values) if (v.name == s) return v;
  return DialogSize.compact;
}
String _themeToString(ThemeMode m) => m == ThemeMode.light ? 'light' : 'dark';
ThemeMode _themeFromString(String s) => s == 'light' ? ThemeMode.light : ThemeMode.dark;
String _calcModeToString(CalculatorMode m) => m.name;
CalculatorMode _calcModeFromString(String s) {
  for (final v in CalculatorMode.values) if (v.name == s) return v;
  return CalculatorMode.scientific;
}
String? _inverseToString(int? v) {
  if (v == null) return null;
  if (v == 0) return 'dms';
  return 'decimal';
}
int? _inverseFromString(String? s) {
  if (s == null) return null;
  if (s == 'dms') return 0;
  return 1;
}
String _statsSectionToString(StatsSummarySection s) => s.name;
StatsSummarySection _statsSectionFromString(String s) {
  for (final v in StatsSummarySection.values) if (v.name == s) return v;
  return StatsSummarySection.header;
}
String _statsComputedToString(StatsComputedItem s) => s.name;
StatsComputedItem _statsComputedFromString(String s) {
  for (final v in StatsComputedItem.values) if (v.name == s) return v;
  return StatsComputedItem.mean;
}

Map<String, dynamic> _settingsToContract(AccessibilitySettings s) => {
  'accessibilityType': _accessibilityTypeToString(s.accessibilityType),
  'screenReaderMode': _screenReaderModeToString(s.screenReaderMode),
  'fontSizeMultiplier': s.fontSizeMultiplier,
  'dialogFontScale': s.dialogFontScale,
  'dotMatrixZoom': s.dotMatrixZoom,
  'resultZoom': s.resultZoom,
  'thousandGroupGap': _gapToString(s.thousandGroupGap),
  'dialogSize': _dialogSizeToString(s.dialogSize),
  'useSixteenSegment': s.useSixteenSegment,
  'usePeriodicNotation': s.usePeriodicNotation,
  'announceExpression': s.announceExpression,
  'readStatsMemoryValues': s.readStatsMemoryValues,
  'autoReadStatsSummary': s.autoReadStatsSummary,
  'showStatsNavigationHint': s.showStatsNavigationHint,
  'alignInputLeft': s.alignInputLeft,
  'overlineThickness': s.overlineThickness,
  'overlineHeight': s.overlineHeight,
  'speechRate': s.speechRate,
  'speechVolume': s.speechVolume,
  'ttsEnabled': s.ttsEnabled,
  'ttsEngine': s.ttsEngine,
  'ttsVoice': s.ttsVoice == null ? null : {'name': s.ttsVoice!['name'], 'locale': s.ttsVoice!['locale']},
  'ttsVoiceName': s.ttsVoiceName,
  'inverseFormatPreference': _inverseToString(s.inverseFormatPreference),
};

AccessibilitySettings _settingsFromContract(Map<String, dynamic> m) => AccessibilitySettings(
  accessibilityType: _accessibilityTypeFromString(m['accessibilityType'] as String),
  screenReaderMode: _screenReaderModeFromString(m['screenReaderMode'] as String),
  fontSizeMultiplier: (m['fontSizeMultiplier'] as num).toDouble(),
  dialogFontScale: (m['dialogFontScale'] as num).toDouble(),
  dotMatrixZoom: (m['dotMatrixZoom'] as num).toDouble(),
  resultZoom: (m['resultZoom'] as num).toDouble(),
  thousandGroupGap: _gapFromString(m['thousandGroupGap'] as String),
  dialogSize: _dialogSizeFromString(m['dialogSize'] as String),
  useSixteenSegment: m['useSixteenSegment'] as bool,
  usePeriodicNotation: m['usePeriodicNotation'] as bool,
  announceExpression: m['announceExpression'] as bool,
  readStatsMemoryValues: m['readStatsMemoryValues'] as bool,
  autoReadStatsSummary: m['autoReadStatsSummary'] as bool,
  showStatsNavigationHint: m['showStatsNavigationHint'] as bool,
  alignInputLeft: m['alignInputLeft'] as bool,
  overlineThickness: (m['overlineThickness'] as num).toDouble(),
  overlineHeight: (m['overlineHeight'] as num).toDouble(),
  speechRate: (m['speechRate'] as num).toDouble(),
  speechVolume: (m['speechVolume'] as num).toDouble(),
  ttsEnabled: m['ttsEnabled'] as bool,
  ttsEngine: m['ttsEngine'] as String?,
  ttsVoice: m['ttsVoice'] == null ? null : Map<String,String>.from((m['ttsVoice'] as Map).map((k,v)=>MapEntry(k.toString(), v.toString()))),
  ttsVoiceName: m['ttsVoiceName'] as String?,
  inverseFormatPreference: _inverseFromString(m['inverseFormatPreference'] as String?),
);

Map<String,dynamic> buildContractJson({
  required List<AccessibilityProfile> profiles,
  required String activeProfileId,
  required ThemeMode themeMode,
  required bool isDegreeMode,
  required CalculatorMode defaultMode,
  required List<StatsSummarySection> statsSummaryOrder,
  required List<StatsComputedItem> statsComputedOrder,
  required String currencyFrom,
  required String currencyTo,
  required bool devEnabled,
  required bool devAutoDiagnostic,
  required int devDiagnosticDurationMs,
  required String? devPinCode,
}) {
  final now = DateTime.now().toUtc().toIso8601String().replaceAll('+00:00','Z');
  return {
    'schemaVersion': 1,
    'createdAt': now,
    'generator': 'Mluvici_kalkulacka/12.1.0',
    'calculatorCompatibility': {'minVersion': '11.5.0', 'maxVersion': null},
    'activeProfileId': activeProfileId,
    'profiles': profiles.map((p) => {
      'id': p.id,
      'name': p.name,
      'isBuiltIn': p.isBuiltIn,
      'settings': _settingsToContract(p.settings),
    }).toList(),
    'globalSettings': {
      'themeMode': _themeToString(themeMode),
      'isDegreeMode': isDegreeMode,
      'defaultMode': _calcModeToString(defaultMode),
      'statsSummaryOrder': statsSummaryOrder.map((e)=>_statsSectionToString(e)).toList(),
      'statsComputedOrder': statsComputedOrder.map((e)=>_statsComputedToString(e)).toList(),
      'currency': {'from': currencyFrom, 'to': currencyTo},
      'devMode': {
        'enabled': devEnabled,
        'autoDiagnostic': devAutoDiagnostic,
        'diagnosticDurationMs': devDiagnosticDurationMs,
        if (devPinCode != null) 'pinCode': devPinCode,
      }
    }
  };
}

class ParsedContract {
  final List<AccessibilityProfile> profiles;
  final String activeProfileId;
  final ThemeMode themeMode;
  final bool isDegreeMode;
  final CalculatorMode defaultMode;
  final List<StatsSummarySection> statsSummaryOrder;
  final List<StatsComputedItem> statsComputedOrder;
  final String currencyFrom;
  final String currencyTo;
  final bool devEnabled;
  final bool devAutoDiagnostic;
  final int devDiagnosticDurationMs;
  final String? devPinCode;
  ParsedContract({
    required this.profiles, required this.activeProfileId, required this.themeMode,
    required this.isDegreeMode, required this.defaultMode, required this.statsSummaryOrder,
    required this.statsComputedOrder, required this.currencyFrom, required this.currencyTo,
    required this.devEnabled, required this.devAutoDiagnostic, required this.devDiagnosticDurationMs, required this.devPinCode,
  });
}

ParsedContract parseContract(Map<String,dynamic> raw) {
  final profilesRaw = raw['profiles'] as List;
  final profiles = profilesRaw.map((e) {
    final m = Map<String,dynamic>.from(e as Map);
    return AccessibilityProfile(
      id: m['id'] as String,
      name: m['name'] as String,
      isBuiltIn: m['isBuiltIn'] as bool,
      settings: _settingsFromContract(Map<String,dynamic>.from(m['settings'] as Map)),
    );
  }).toList();
  final gs = Map<String,dynamic>.from(raw['globalSettings'] as Map);
  final cur = Map<String,dynamic>.from(gs['currency'] as Map);
  final dev = Map<String,dynamic>.from(gs['devMode'] as Map);
  return ParsedContract(
    profiles: profiles,
    activeProfileId: raw['activeProfileId'] as String,
    themeMode: _themeFromString(gs['themeMode'] as String),
    isDegreeMode: gs['isDegreeMode'] as bool,
    defaultMode: _calcModeFromString(gs['defaultMode'] as String),
    statsSummaryOrder: (gs['statsSummaryOrder'] as List).map((e)=> _statsSectionFromString(e as String)).toList(),
    statsComputedOrder: (gs['statsComputedOrder'] as List).map((e)=> _statsComputedFromString(e as String)).toList(),
    currencyFrom: cur['from'] as String,
    currencyTo: cur['to'] as String,
    devEnabled: dev['enabled'] as bool,
    devAutoDiagnostic: dev['autoDiagnostic'] as bool,
    devDiagnosticDurationMs: (dev['diagnosticDurationMs'] as num).toInt(),
    devPinCode: dev['pinCode'] as String?,
  );
}

Future<void> _saveContractToPrefs(Map<String,dynamic> contract) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('config_contract_v1', jsonEncode(contract));
}

Future<Map<String,dynamic>?> _loadContractFromPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final s = prefs.getString('config_contract_v1');
  if (s == null) return null;
  try { return jsonDecode(s) as Map<String,dynamic>; } catch (_) { return null; }
}

Future<void> _exportContractFile(Map<String,dynamic> contract, {String fileName = 'mluvici_kalkulacka_config_v1.json'}) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';
  final f = File(path);
  await f.writeAsString(const JsonEncoder.withIndent('  ').convert(contract), flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: fileName));
}

Future<Map<String,dynamic>?> _pickAndReadContractFile() async {
  final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
  if (files.isEmpty) return null;
  final file = files.first;
  String? content;
  if (file.path != null) {
    content = await File(file.path!).readAsString();
  } else {
    try {
      final bytes = await file.readAsBytes();
      content = utf8.decode(bytes);
    } catch (_) { return null; }
  }
  if (content == null) return null;
  try { return jsonDecode(content) as Map<String,dynamic>; } catch (_) { return null; }
}
