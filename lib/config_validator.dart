// Validace kontraktu - lehka implementace bez externiho package, zrcadli Python validator.
import 'dart:convert';

class ValidationIssue {
  final String path;
  final String message;
  final String code;
  ValidationIssue({
    required this.path,
    required this.message,
    required this.code,
  });
}

class ValidationResult {
  final List<ValidationIssue> errors = [];
  final List<ValidationIssue> warnings = [];
  bool get ok => errors.isEmpty;
}

const Set<String> _knownRootKeys = {
  'schemaVersion',
  'createdAt',
  'generator',
  'calculatorCompatibility',
  'activeProfileId',
  'profiles',
  'globalSettings',
};
const Set<String> _knownCompatKeys = {'minVersion', 'maxVersion'};
const Set<String> _knownProfileKeys = {'id', 'name', 'isBuiltIn', 'settings'};
const Set<String> _knownSettingsKeys = {
  'accessibilityType',
  'screenReaderMode',
  'fontSizeMultiplier',
  'dialogFontScale',
  'dotMatrixZoom',
  'resultZoom',
  'thousandGroupGap',
  'dialogSize',
  'useSixteenSegment',
  'usePeriodicNotation',
  'announceExpression',
  'readStatsMemoryValues',
  'autoReadStatsSummary',
  'showStatsNavigationHint',
  'alignInputLeft',
  'overlineThickness',
  'overlineHeight',
  'speechRate',
  'speechVolume',
  'ttsEnabled',
  'ttsEngine',
  'ttsVoice',
  'ttsVoiceName',
  'inverseFormatPreference',
};
const Set<String> _knownGlobalKeys = {
  'themeMode',
  'isDegreeMode',
  'defaultMode',
  'statsSummaryOrder',
  'statsComputedOrder',
  'currency',
  'devMode',
};
const Set<String> _knownCurrencyKeys = {'from', 'to'};
const Set<String> _knownDevModeKeys = {
  'enabled',
  'autoDiagnostic',
  'diagnosticDurationMs',
  'pinCode',
};

bool _isVersionString(String s) => RegExp(r'^\d+\.\d+\.\d+.*$').hasMatch(s);

void _collectUnknownKeys(Map<String, dynamic> data, ValidationResult res) {
  for (final k in data.keys) {
    if (!_knownRootKeys.contains(k)) {
      res.warnings.add(
        ValidationIssue(
          path: k,
          message: "Neznamy klic '$k' na rootu, ignoruje se.",
          code: 'unknownKey',
        ),
      );
    }
  }
  final comp = data['calculatorCompatibility'];
  if (comp is Map) {
    for (final k in comp.keys) {
      if (!_knownCompatKeys.contains(k.toString())) {
        res.warnings.add(
          ValidationIssue(
            path: 'calculatorCompatibility.$k',
            message: "Neznamy klic '$k' v calculatorCompatibility.",
            code: 'unknownKey',
          ),
        );
      }
    }
  }
  final profiles = data['profiles'];
  if (profiles is List) {
    for (int i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      if (p is! Map) continue;
      for (final k in p.keys) {
        if (!_knownProfileKeys.contains(k.toString())) {
          res.warnings.add(
            ValidationIssue(
              path: 'profiles[$i].$k',
              message: "Neznamy klic '$k' v profilu.",
              code: 'unknownKey',
            ),
          );
        }
      }
      final settings = p['settings'];
      if (settings is Map) {
        for (final k in settings.keys) {
          if (!_knownSettingsKeys.contains(k.toString())) {
            res.warnings.add(
              ValidationIssue(
                path: 'profiles[$i].settings.$k',
                message: "Neznamy klic '$k' v settings, ignoruje se.",
                code: 'unknownKey',
              ),
            );
          }
        }
        final voice = settings['ttsVoice'];
        if (voice is Map) {
          for (final k in voice.keys) {
            if (!{'name', 'locale'}.contains(k.toString())) {
              res.warnings.add(
                ValidationIssue(
                  path: 'profiles[$i].settings.ttsVoice.$k',
                  message: "Neznamy klic '$k' v ttsVoice.",
                  code: 'unknownKey',
                ),
              );
            }
          }
        }
      }
    }
  }
  final gs = data['globalSettings'];
  if (gs is Map) {
    for (final k in gs.keys) {
      if (!_knownGlobalKeys.contains(k.toString())) {
        res.warnings.add(
          ValidationIssue(
            path: 'globalSettings.$k',
            message: "Neznamy klic '$k' v globalSettings.",
            code: 'unknownKey',
          ),
        );
      }
    }
    final cur = gs['currency'];
    if (cur is Map) {
      for (final k in cur.keys) {
        if (!_knownCurrencyKeys.contains(k.toString())) {
          res.warnings.add(
            ValidationIssue(
              path: 'globalSettings.currency.$k',
              message: "Neznamy klic '$k' v currency.",
              code: 'unknownKey',
            ),
          );
        }
      }
    }
    final dev = gs['devMode'];
    if (dev is Map) {
      for (final k in dev.keys) {
        if (!_knownDevModeKeys.contains(k.toString())) {
          res.warnings.add(
            ValidationIssue(
              path: 'globalSettings.devMode.$k',
              message: "Neznamy klic '$k' v devMode.",
              code: 'unknownKey',
            ),
          );
        }
      }
    }
  }
}

ValidationResult validateContract(dynamic data) {
  final result = ValidationResult();
  if (data is! Map) {
    result.errors.add(
      ValidationIssue(path: '', message: 'Root musi byt objekt.', code: 'type'),
    );
    return result;
  }
  final map = Map<String, dynamic>.from(data as Map);
  // schemaVersion
  final sv = map['schemaVersion'];
  if (sv == null) {
    result.errors.add(
      ValidationIssue(
        path: 'schemaVersion',
        message: 'Chybi schemaVersion.',
        code: 'required',
      ),
    );
    return result;
  }
  if (sv is! int) {
    result.errors.add(
      ValidationIssue(
        path: 'schemaVersion',
        message: 'schemaVersion musi byt integer.',
        code: 'type',
      ),
    );
    return result;
  }
  if (sv != 1) {
    if (sv > 1) {
      result.errors.add(
        ValidationIssue(
          path: 'schemaVersion',
          message:
              'Nepodporovana budouci verze schemaVersion=$sv (podporovana je 1). Aktualizujte kalkulacku.',
          code: 'futureVersion',
        ),
      );
    } else {
      result.errors.add(
        ValidationIssue(
          path: 'schemaVersion',
          message:
              'Nepodporovana stara verze schemaVersion=$sv (podporovana je 1).',
          code: 'unsupportedVersion',
        ),
      );
    }
    return result;
  }
  // required keys
  for (final k in ['activeProfileId', 'profiles', 'globalSettings']) {
    if (!map.containsKey(k)) {
      result.errors.add(
        ValidationIssue(
          path: k,
          message: 'Chybi povinne pole $k.',
          code: 'required',
        ),
      );
    }
  }
  // profiles
  final profiles = map['profiles'];
  if (profiles != null) {
    if (profiles is! List) {
      result.errors.add(
        ValidationIssue(
          path: 'profiles',
          message: 'profiles musi byt pole.',
          code: 'type',
        ),
      );
    } else {
      if (profiles.isEmpty) {
        result.errors.add(
          ValidationIssue(
            path: 'profiles',
            message: 'profiles nesmi byt prazdne.',
            code: 'minItems',
          ),
        );
      }
      for (int i = 0; i < profiles.length; i++) {
        final p = profiles[i];
        if (p is! Map) {
          result.errors.add(
            ValidationIssue(
              path: 'profiles[$i]',
              message: 'profil musi byt objekt.',
              code: 'type',
            ),
          );
          continue;
        }
        final pm = Map<String, dynamic>.from(p as Map);
        for (final rk in ['id', 'name', 'isBuiltIn', 'settings']) {
          if (!pm.containsKey(rk))
            result.errors.add(
              ValidationIssue(
                path: 'profiles[$i].$rk',
                message: 'Chybi $rk',
                code: 'required',
              ),
            );
        }
        final id = pm['id'];
        if (id is! String || id.isEmpty)
          result.errors.add(
            ValidationIssue(
              path: 'profiles[$i].id',
              message: 'id musi byt neprazdny string.',
              code: 'type',
            ),
          );
        final name = pm['name'];
        if (name is! String || name.isEmpty)
          result.errors.add(
            ValidationIssue(
              path: 'profiles[$i].name',
              message: 'name musi byt neprazdny string.',
              code: 'type',
            ),
          );
        if (pm['isBuiltIn'] is! bool)
          result.errors.add(
            ValidationIssue(
              path: 'profiles[$i].isBuiltIn',
              message: 'isBuiltIn musi byt bool.',
              code: 'type',
            ),
          );
        final settings = pm['settings'];
        if (settings is! Map) {
          result.errors.add(
            ValidationIssue(
              path: 'profiles[$i].settings',
              message: 'settings musi byt objekt.',
              code: 'type',
            ),
          );
        } else {
          _validateSettings(
            Map<String, dynamic>.from(settings as Map),
            'profiles[$i].settings',
            result,
          );
        }
      }
      // unique ids
      final ids = profiles
          .whereType<Map>()
          .map((e) => e['id'])
          .whereType<String>()
          .toList();
      if (ids.length != ids.toSet().length) {
        result.errors.add(
          ValidationIssue(
            path: 'profiles',
            message: 'ID profilu musi byt unikatni.',
            code: 'unique',
          ),
        );
      }
      for (int i = 0; i < profiles.length; i++) {
        final p = profiles[i];
        if (p is Map && p['isBuiltIn'] == true) {
          final pid = p['id'];
          if (pid != 'standard' && pid != 'blind' && pid != 'lowvision') {
            result.errors.add(
              ValidationIssue(
                path: 'profiles[$i].isBuiltIn',
                message:
                    'isBuiltIn=true povoleno pouze pro standard/blind/lowvision.',
                code: 'enum',
              ),
            );
          }
        }
      }
      final active = map['activeProfileId'];
      if (active is String && !ids.contains(active)) {
        result.errors.add(
          ValidationIssue(
            path: 'activeProfileId',
            message: "activeProfileId '$active' neexistuje v profiles.",
            code: 'existence',
          ),
        );
      }
    }
  }
  final gs = map['globalSettings'];
  if (gs is Map) {
    _validateGlobalSettings(Map<String, dynamic>.from(gs as Map), result);
  } else if (gs != null) {
    result.errors.add(
      ValidationIssue(
        path: 'globalSettings',
        message: 'globalSettings musi byt objekt.',
        code: 'type',
      ),
    );
  }
  final comp = map['calculatorCompatibility'];
  if (comp is Map) {
    final mv = (comp as Map)['minVersion'];
    if (mv is String && !_isVersionString(mv)) {
      result.errors.add(
        ValidationIssue(
          path: 'calculatorCompatibility.minVersion',
          message: "Neplatny format verze '$mv'.",
          code: 'format',
        ),
      );
    }
  }
  _collectUnknownKeys(map, result);
  return result;
}

void _validateSettings(
  Map<String, dynamic> s,
  String path,
  ValidationResult res,
) {
  const requiredKeys = [
    'accessibilityType',
    'screenReaderMode',
    'fontSizeMultiplier',
    'dialogFontScale',
    'dotMatrixZoom',
    'resultZoom',
    'thousandGroupGap',
    'dialogSize',
    'useSixteenSegment',
    'usePeriodicNotation',
    'announceExpression',
    'readStatsMemoryValues',
    'autoReadStatsSummary',
    'showStatsNavigationHint',
    'alignInputLeft',
    'overlineThickness',
    'overlineHeight',
    'speechRate',
    'speechVolume',
    'ttsEnabled',
  ];
  for (final k in requiredKeys) {
    if (!s.containsKey(k))
      res.errors.add(
        ValidationIssue(
          path: '$path.$k',
          message: 'Chybi $k',
          code: 'required',
        ),
      );
  }
  void checkEnum(String key, Set<String> allowed) {
    final v = s[key];
    if (v != null && !allowed.contains(v)) {
      res.errors.add(
        ValidationIssue(
          path: '$path.$key',
          message: "$key musi byt jedno z ${allowed.join(', ')}",
          code: 'enum',
        ),
      );
    }
  }

  checkEnum('accessibilityType', {'none', 'blind', 'visuallyImpaired'});
  checkEnum('screenReaderMode', {'auto', 'on', 'off'});
  checkEnum('thousandGroupGap', {'small', 'medium', 'large'});
  checkEnum('dialogSize', {'compact', 'wide', 'fullscreen'});
  if (s['inverseFormatPreference'] != null &&
      s['inverseFormatPreference'] != 'dms' &&
      s['inverseFormatPreference'] != 'decimal') {
    res.errors.add(
      ValidationIssue(
        path: '$path.inverseFormatPreference',
        message: 'inverseFormatPreference musi byt dms/decimal/null',
        code: 'enum',
      ),
    );
  }
  void checkRange(String key, double min, double max) {
    final v = s[key];
    if (v is num) {
      final d = v.toDouble();
      if (d < min || d > max)
        res.errors.add(
          ValidationIssue(
            path: '$path.$key',
            message: '$key mimo rozsah $min..$max',
            code: 'range',
          ),
        );
    } else if (v != null) {
      res.errors.add(
        ValidationIssue(
          path: '$path.$key',
          message: '$key musi byt cislo.',
          code: 'type',
        ),
      );
    }
  }

  checkRange('fontSizeMultiplier', 0.7, 2.5);
  checkRange('dialogFontScale', 0.5, 5.0);
  checkRange('dotMatrixZoom', 0.5, 5.0);
  checkRange('resultZoom', 0.5, 5.0);
  checkRange('overlineThickness', 0.8, 4.0);
  checkRange('overlineHeight', 0.5, 2.0);
  checkRange('speechRate', 0.1, 1.0);
  checkRange('speechVolume', 0.0, 1.0);
  for (final k in [
    'useSixteenSegment',
    'usePeriodicNotation',
    'announceExpression',
    'readStatsMemoryValues',
    'autoReadStatsSummary',
    'showStatsNavigationHint',
    'alignInputLeft',
    'ttsEnabled',
  ]) {
    if (s.containsKey(k) && s[k] is! bool)
      res.errors.add(
        ValidationIssue(
          path: '$path.$k',
          message: '$k musi byt bool.',
          code: 'type',
        ),
      );
  }
  final ttsVoice = s['ttsVoice'];
  if (ttsVoice != null && ttsVoice is! Map) {
    res.errors.add(
      ValidationIssue(
        path: '$path.ttsVoice',
        message: 'ttsVoice musi byt objekt nebo null.',
        code: 'type',
      ),
    );
  } else if (ttsVoice is Map) {
    final m = Map<String, dynamic>.from(ttsVoice as Map);
    if (!m.containsKey('name') || !m.containsKey('locale'))
      res.errors.add(
        ValidationIssue(
          path: '$path.ttsVoice',
          message: 'ttsVoice musi mit name+locale.',
          code: 'required',
        ),
      );
    if (m['name'] is! String || (m['name'] as String).isEmpty)
      res.errors.add(
        ValidationIssue(
          path: '$path.ttsVoice.name',
          message: 'name musi byt neprazdny string.',
          code: 'type',
        ),
      );
    if (m['locale'] is! String || (m['locale'] as String).isEmpty)
      res.errors.add(
        ValidationIssue(
          path: '$path.ttsVoice.locale',
          message: 'locale musi byt neprazdny string.',
          code: 'type',
        ),
      );
  }
  if (s['ttsEngine'] != null && s['ttsEngine'] is! String)
    res.errors.add(
      ValidationIssue(
        path: '$path.ttsEngine',
        message: 'ttsEngine musi byt string/null.',
        code: 'type',
      ),
    );
  if (s['ttsVoiceName'] != null && s['ttsVoiceName'] is! String)
    res.errors.add(
      ValidationIssue(
        path: '$path.ttsVoiceName',
        message: 'ttsVoiceName musi byt string/null.',
        code: 'type',
      ),
    );
}

void _validateGlobalSettings(Map<String, dynamic> gs, ValidationResult res) {
  for (final k in [
    'themeMode',
    'isDegreeMode',
    'defaultMode',
    'statsSummaryOrder',
    'statsComputedOrder',
    'currency',
    'devMode',
  ]) {
    if (!gs.containsKey(k))
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.$k',
          message: 'Chybi $k',
          code: 'required',
        ),
      );
  }
  final tm = gs['themeMode'];
  if (tm != null && tm != 'light' && tm != 'dark')
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.themeMode',
        message: 'themeMode musi byt light/dark',
        code: 'enum',
      ),
    );
  if (gs['isDegreeMode'] != null && gs['isDegreeMode'] is! bool)
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.isDegreeMode',
        message: 'isDegreeMode musi byt bool',
        code: 'type',
      ),
    );
  final dm = gs['defaultMode'];
  if (dm != null &&
      !{
        'basic',
        'scientific',
        'statistics',
        'electrician',
        'unitConversion',
        'time',
        'currency',
      }.contains(dm)) {
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.defaultMode',
        message: 'defaultMode neplatny enum',
        code: 'enum',
      ),
    );
  }
  final order = gs['statsSummaryOrder'];
  if (order is List) {
    if (order.length != 3)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.statsSummaryOrder',
          message: 'statsSummaryOrder musi mit 3 polozky',
          code: 'length',
        ),
      );
    final allowed = {'header', 'dataValues', 'computed'};
    for (int i = 0; i < order.length; i++)
      if (!allowed.contains(order[i]))
        res.errors.add(
          ValidationIssue(
            path: 'globalSettings.statsSummaryOrder[$i]',
            message: 'neplatna hodnota',
            code: 'enum',
          ),
        );
    if (order.toSet().length != order.length)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.statsSummaryOrder',
          message: 'musi obsahovat unikatni hodnoty',
          code: 'unique',
        ),
      );
  } else if (order != null) {
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.statsSummaryOrder',
        message: 'musi byt pole',
        code: 'type',
      ),
    );
  }
  final corder = gs['statsComputedOrder'];
  if (corder is List) {
    if (corder.length != 10)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.statsComputedOrder',
          message: 'musi mit 10 polozek',
          code: 'length',
        ),
      );
    final allowed = {
      'mean',
      'sum',
      'variance',
      'sd',
      'median',
      'min',
      'max',
      'mode',
      'cv',
      'wmean',
    };
    for (int i = 0; i < corder.length; i++)
      if (!allowed.contains(corder[i]))
        res.errors.add(
          ValidationIssue(
            path: 'globalSettings.statsComputedOrder[$i]',
            message: 'neplatna hodnota',
            code: 'enum',
          ),
        );
    if (corder.toSet().length != corder.length)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.statsComputedOrder',
          message: 'musi obsahovat unikatni hodnoty',
          code: 'unique',
        ),
      );
  } else if (corder != null) {
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.statsComputedOrder',
        message: 'musi byt pole',
        code: 'type',
      ),
    );
  }
  final cur = gs['currency'];
  if (cur is Map) {
    if (!cur.containsKey('from') || !cur.containsKey('to'))
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.currency',
          message: 'currency musi mit from+to',
          code: 'required',
        ),
      );
    if (cur['from'] is! String || (cur['from'] as String).isEmpty)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.currency.from',
          message: 'from musi byt neprazdny string',
          code: 'type',
        ),
      );
    if (cur['to'] is! String || (cur['to'] as String).isEmpty)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.currency.to',
          message: 'to musi byt neprazdny string',
          code: 'type',
        ),
      );
  } else if (cur != null) {
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.currency',
        message: 'currency musi byt objekt',
        code: 'type',
      ),
    );
  }
  final dev = gs['devMode'];
  if (dev is Map) {
    final dm2 = Map<String, dynamic>.from(dev as Map);
    if (dm2['enabled'] is! bool)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.devMode.enabled',
          message: 'enabled musi byt bool',
          code: 'type',
        ),
      );
    if (dm2['autoDiagnostic'] is! bool)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.devMode.autoDiagnostic',
          message: 'autoDiagnostic musi byt bool',
          code: 'type',
        ),
      );
    if (dm2['diagnosticDurationMs'] is! int)
      res.errors.add(
        ValidationIssue(
          path: 'globalSettings.devMode.diagnosticDurationMs',
          message: 'diagnosticDurationMs musi byt int',
          code: 'type',
        ),
      );
    else {
      final v = dm2['diagnosticDurationMs'] as int;
      if (v < 200 || v > 3000)
        res.errors.add(
          ValidationIssue(
            path: 'globalSettings.devMode.diagnosticDurationMs',
            message: 'mimo rozsah 200..3000',
            code: 'range',
          ),
        );
    }
    if (dm2.containsKey('pinCode') && dm2['pinCode'] != null) {
      if (dm2['pinCode'] is! String ||
          !RegExp(r'^\d{4}$').hasMatch(dm2['pinCode'] as String)) {
        res.errors.add(
          ValidationIssue(
            path: 'globalSettings.devMode.pinCode',
            message: 'pinCode musi byt 4 cislice',
            code: 'format',
          ),
        );
      }
    }
  } else if (dev != null) {
    res.errors.add(
      ValidationIssue(
        path: 'globalSettings.devMode',
        message: 'devMode musi byt objekt',
        code: 'type',
      ),
    );
  }
}
