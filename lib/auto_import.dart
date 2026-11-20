import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'config_validator.dart';

const autoImportFileName = 'mluvici_kalkulacka_config_v3.json';
const _autoImportChannel = MethodChannel(
  'com.example.mluvici_kalkulacka/auto_import',
);

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
  late final Uint8List bytes;
  late final String path;
  if (directory.startsWith('content://')) {
    final raw = await _autoImportChannel.invokeMethod<List<dynamic>>(
      'readTreeFile',
      {'treeUri': directory, 'fileName': autoImportFileName},
    );
    if (raw == null) throw const FormatException('SAF file is unavailable');
    bytes = Uint8List.fromList(raw.cast<int>());
    path = '$directory/$autoImportFileName';
  } else {
    final file = File('$directory${Platform.pathSeparator}$autoImportFileName');
    bytes = await file.readAsBytes();
    path = file.path;
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const FormatException('Contract is not an object');
  return AutoImportFile(
    contract: Map<String, dynamic>.from(decoded),
    hash: sha256.convert(bytes).toString(),
    path: path,
  );
}

ValidationResult validateAutoImportFile(AutoImportFile file) =>
    validateContract(file.contract);
