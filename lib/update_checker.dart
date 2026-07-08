import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubReleaseInfo {
  final String tagName;
  final String? htmlUrl;
  final String? body;

  GitHubReleaseInfo({required this.tagName, this.htmlUrl, this.body});

  String get normalizedVersion {
    final cleaned = tagName.trim();
    final match = RegExp(r'\d+(?:\.\d+)+').firstMatch(cleaned);
    if (match == null) {
      return cleaned;
    }

    return match.group(0)!;
  }

  String get shortBody {
    if (body == null || body!.trim().isEmpty) {
      return '';
    }

    return body!.trim().replaceAll('\r\n', '\n');
  }

  String get releaseSummary {
    final text = shortBody;
    if (text.isEmpty) {
      return '';
    }

    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    return lines.take(5).join('\n');
  }

  bool isNewerThan(String currentVersion) {
    final parsedCurrent = _parseVersion(currentVersion);
    final parsedLatest = _parseVersion(normalizedVersion);
    return _compareVersions(parsedLatest, parsedCurrent) > 0;
  }

  static List<int> _parseVersion(String version) {
    final cleaned = version.trim();
    final match = RegExp(r'\d+(?:\.\d+)+').firstMatch(cleaned);
    final numeric = match?.group(0) ?? cleaned;
    final parts = numeric.split('.').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return [];
    }

    return parts.map((part) {
      final digits = part.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? 0 : int.parse(digits);
    }).toList();
  }

  static int _compareVersions(List<int> left, List<int> right) {
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < left.length ? left[index] : 0;
      final rightValue = index < right.length ? right[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }
}

class GitHubReleaseChecker {
  GitHubReleaseChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GitHubReleaseInfo?> checkForUpdates({
    required String owner,
    required String repo,
    required String currentVersion,
  }) async {
    final uri = Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'MluviciKalkulackaApp', // GitHub vyžaduje identifikaci klienta
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final release = GitHubReleaseInfo(
      tagName: (json['tag_name'] as String?) ?? '',
      htmlUrl: json['html_url'] as String?,
      body: json['body'] as String?,
    );

    if (release.isNewerThan(currentVersion)) {
      return release;
    }

    return null;
  }
}