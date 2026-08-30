part of 'main.dart';

class StatsStorage {
  static const String _prefsSetsKey = 'statsSets';
  static const String _prefsIndexKey = 'currentStatsSetIndex';
  static const String _prefsFoldersKey = 'statsFolders';
  static const String _fileName = 'stats_sets_v2.json';

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<Map<String, dynamic>?> _readFileJson() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final content = await f.readAsString();
      if (content.trim().isEmpty) return null;
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeFileJson(Map<String, dynamic> data) async {
    try {
      final f = await _file();
      final jsonStr = jsonEncode(data);
      await f.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  static Future<({List<StatisticsSet> sets, List<StatisticsFolder> folders, int currentIndex})> load() async {
    final fileJson = await _readFileJson();
    if (fileJson != null) {
      try {
        final sets = (fileJson['sets'] as List)
            .map((e) => StatisticsSet.fromJson(e as Map<String, dynamic>))
            .toList();
        final folders = fileJson['folders'] != null
            ? (fileJson['folders'] as List)
                .map((e) => StatisticsFolder.fromJson(e as Map<String, dynamic>))
                .toList()
            : <StatisticsFolder>[];
        final idx = (fileJson['currentIndex'] as num?)?.toInt() ?? 0;
        return (sets: sets, folders: folders, currentIndex: idx.clamp(0, sets.isEmpty ? 0 : sets.length - 1));
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    List<StatisticsSet> sets = [];
    List<StatisticsFolder> folders = [];
    int idx = prefs.getInt(_prefsIndexKey) ?? 0;
    final statsJson = prefs.getString(_prefsSetsKey);
    if (statsJson != null) {
      try {
        sets = (jsonDecode(statsJson) as List)
            .map((e) => StatisticsSet.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    final foldersJson = prefs.getString(_prefsFoldersKey);
    if (foldersJson != null) {
      try {
        folders = (jsonDecode(foldersJson) as List)
            .map((e) => StatisticsFolder.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (sets.isNotEmpty || folders.isNotEmpty) {
      await _writeFileJson({
        'sets': sets.map((s) => s.toJson()).toList(),
        'folders': folders.map((f) => f.toJson()).toList(),
        'currentIndex': idx,
        'migratedAt': DateTime.now().toIso8601String(),
      });
    }
    return (sets: sets, folders: folders, currentIndex: idx.clamp(0, sets.isEmpty ? 0 : sets.length - 1));
  }

  static Future<void> save({
    required List<StatisticsSet> sets,
    required List<StatisticsFolder> folders,
    required int currentIndex,
  }) async {
    final data = {
      'sets': sets.map((s) => s.toJson()).toList(),
      'folders': folders.map((f) => f.toJson()).toList(),
      'currentIndex': currentIndex,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _writeFileJson(data);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsIndexKey, currentIndex);
      final f = await _file();
      final len = await f.length();
      if (len < 500 * 1024) {
        await prefs.setString(_prefsSetsKey, jsonEncode(sets.map((s) => s.toJson()).toList()));
        await prefs.setString(_prefsFoldersKey, jsonEncode(folders.map((f) => f.toJson()).toList()));
      } else {
        await prefs.remove(_prefsSetsKey);
        await prefs.remove(_prefsFoldersKey);
      }
    } catch (_) {}
  }
}
