import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CnbRates {
  final Map<String, double> rates;
  final DateTime date;

  CnbRates({required this.rates, required this.date});
}

class CurrencyService {
  static const String cnbUrl =
      'https://www.cnb.cz/cs/financni-trhy/devizovy-trh/kurzy-devizoveho-trhu/kurzy-devizoveho-trhu/denni_kurz.txt';

  final http.Client _client;

  CurrencyService({http.Client? client}) : _client = client ?? http.Client();

  void close() => _client.close();

  Future<CnbRates?> fetchCnbRates({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final resp = await _client.get(Uri.parse(cnbUrl)).timeout(timeout);
      if (resp.statusCode != 200) return null;
      return _parseCnbTxt(utf8.decode(resp.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  CnbRates? parseCnbText(String txt) {
    try {
      return _parseCnbTxt(txt);
    } catch (_) {
      return null;
    }
  }

  CnbRates _parseCnbTxt(String txt) {
    final lines = txt.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) throw const FormatException('Empty CNB response');
    // First line: "28.08.2026 #241"
    DateTime date = DateTime.now();
    final first = lines.first;
    final dateMatch = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(first);
    if (dateMatch != null) {
      date = DateTime(
        int.parse(dateMatch.group(3)!),
        int.parse(dateMatch.group(2)!),
        int.parse(dateMatch.group(1)!),
      );
    }
    // Second line is header
    final rates = <String, double>{'CZK': 1.0};
    for (int i = 2; i < lines.length; i++) {
      final parts = lines[i].split('|');
      if (parts.length < 5) continue;
      final amountStr = parts[2].trim();
      final code = parts[3].trim().toUpperCase();
      final rateStr = parts[4].trim().replaceAll(',', '.');
      if (code.isEmpty) continue;
      final amount = int.tryParse(amountStr);
      final rate = double.tryParse(rateStr);
      if (amount == null || rate == null || amount == 0) continue;
      final perOne = rate / amount;
      rates[code] = perOne;
    }
    if (rates.length <= 1) throw const FormatException('No rates parsed');
    return CnbRates(rates: rates, date: date);
  }
}
