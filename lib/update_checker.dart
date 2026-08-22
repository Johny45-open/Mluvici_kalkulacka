import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  String get plainTextBody {
    final text = shortBody;
    if (text.isEmpty) {
      return '';
    }

    // Odstranění markdown syntaxe, aby se text dal přečíst hlasem.
    return text
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*', multiLine: true), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*', multiLine: true), r'$1')
        .replaceAll('`', '')
        .replaceAll('_', '');
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
    // Odstranění prefixu 'v' a build metadat (+...)
    final cleaned = version.trim().replaceAll(RegExp(r'^v'), '').split('+').first;
    
    // Extrakce pouze číselných částí oddělených tečkou
    final parts = cleaned.split('.').where((part) => part.isNotEmpty).toList();
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

class GitHubFetchResult {
  final List<GitHubReleaseInfo> releases;
  final String? errorType; // null=success, otherwise offline/timeout/rateLimit/notFound/serverError/generic

  const GitHubFetchResult({required this.releases, this.errorType});

  bool get isSuccess => errorType == null;
}

class GitHubReleaseChecker {
  GitHubReleaseChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static Map<String, String> _headers() {
    return {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'MluviciKalkulackaApp',
    };
  }

  Future<GitHubReleaseInfo?> checkForUpdates({
    required String owner,
    required String repo,
    required String currentVersion,
  }) async {
    try {
      final uri = Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');
      final response = await _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to check for updates: ${response.statusCode} ${response.body}',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?) ?? '';
      if (tagName.isEmpty) {
        debugPrint('GitHub release has empty tag_name');
        return null;
      }

      final release = _releaseFromJson(json);

      if (release.isNewerThan(currentVersion)) {
        return release;
      }

      return null;
    } on TimeoutException catch (e) {
      debugPrint('Timeout checking for updates: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('Offline checking for updates: $e');
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  Future<List<GitHubReleaseInfo>> fetchRecentReleases({
    required String owner,
    required String repo,
    int perPage = 30,
    int page = 1,
  }) async {
    final result = await fetchRecentReleasesWithResult(
      owner: owner,
      repo: repo,
      perPage: perPage,
      page: page,
    );
    return result.releases;
  }

  Future<GitHubFetchResult> fetchRecentReleasesWithResult({
    required String owner,
    required String repo,
    int perPage = 30,
    int page = 1,
  }) async {
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/releases',
        {'per_page': '$perPage', 'page': '$page'},
      );
      final response = await _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to fetch recent releases: ${response.statusCode} ${response.body}',
        );
        final errorType = _errorTypeFromStatus(response.statusCode);
        return GitHubFetchResult(releases: [], errorType: errorType);
      }

      final json = jsonDecode(response.body) as List<dynamic>;
      final releases = json
          .whereType<Map<String, dynamic>>()
          .map(_releaseFromJson)
          .toList();
      return GitHubFetchResult(releases: releases);
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching recent releases: $e');
      return const GitHubFetchResult(releases: [], errorType: 'timeout');
    } on SocketException catch (e) {
      debugPrint('Offline fetching recent releases: $e');
      return const GitHubFetchResult(releases: [], errorType: 'offline');
    } catch (e) {
      debugPrint('Error fetching recent releases: $e');
      // Rozlišení podle typu výjimky
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        return const GitHubFetchResult(releases: [], errorType: 'offline');
      }
      return const GitHubFetchResult(releases: [], errorType: 'generic');
    }
  }

  static String _errorTypeFromStatus(int statusCode) {
    if (statusCode == 403 || statusCode == 429) return 'rateLimit';
    if (statusCode == 404) return 'notFound';
    if (statusCode >= 500) return 'serverError';
    return 'generic';
  }

  static GitHubReleaseInfo _releaseFromJson(Map<String, dynamic> json) {
    return GitHubReleaseInfo(
      tagName: (json['tag_name'] as String?) ?? '',
      htmlUrl: json['html_url'] as String?,
      body: json['body'] as String?,
    );
  }

  void close() {
    _client.close();
  }
}