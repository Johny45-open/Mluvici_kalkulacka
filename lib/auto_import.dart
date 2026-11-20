import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'config_validator.dart';

const autoImportFileName = 'mluvici_kalkulacka_config_v3.json';

class AutoImportFile {
  final Map<String, dynamic> contract;
  final String hash;
  final String path;

  const AutoImportFile({
    required this.contract,
    required this.hash,
    required this.path,
  });
}

Future<AutoImportFile> readAutoImportFile(String directory) async {
  final file = File('$directory${Platform.pathSeparator}$autoImportFileName');
  final bytes = await file.readAsBytes();
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const FormatException('Contract is not an object');
  return AutoImportFile(
    contract: Map<String, dynamic>.from(decoded),
    hash: sha256.convert(bytes).toString(),
    path: file.path,
  );
}

ValidationResult validateAutoImportFile(AutoImportFile file) =>
    validateContract(file.contract);
