import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mluvici_kalkulacka/auto_import.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'auto-import reads the expected file and computes a stable hash',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mluvici-auto-import-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}$autoImportFileName',
      );
      await file.writeAsString(jsonEncode({'schemaVersion': 3}));

      final result = await readAutoImportFile(directory.path);
      expect(result.path, file.path);
      expect(result.contract['schemaVersion'], 3);
      expect(result.hash, hasLength(64));
      expect(validateAutoImportFile(result).ok, isFalse);
    },
  );

  test('content URI is read through the Android SAF channel', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channel = const MethodChannel(
      'com.example.mluvici_kalkulacka/auto_import',
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readTreeFile');
      return utf8.encode(jsonEncode({'schemaVersion': 3}));
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final result = await readAutoImportFile('content://tree/abc');
    expect(result.contract['schemaVersion'], 3);
  });
}
