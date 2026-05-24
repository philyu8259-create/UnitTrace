import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class AppDirectories {
  AppDirectories._();

  static const _channel = MethodChannel('unittrace/app_directories');
  static Future<Directory>? _documentsDirectory;

  static Future<Directory> documents() {
    return _documentsDirectory ??= _resolveDocuments();
  }

  @visibleForTesting
  static void setDocumentsDirectoryForTesting(Directory directory) {
    directory.createSync(recursive: true);
    _documentsDirectory = Future.value(directory);
  }

  @visibleForTesting
  static void resetForTesting() {
    _documentsDirectory = null;
  }

  static Future<Directory> _resolveDocuments() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return _fallbackDocuments();
    }
    try {
      final path = await _channel.invokeMethod<String>('documentsDirectory');
      if (path != null && path.isNotEmpty) {
        final directory = Directory(path);
        await directory.create(recursive: true);
        return directory;
      }
    } on Exception {
      // Widget tests and unsupported desktop targets can run without a host
      // channel. Use a stable temp folder instead of failing startup.
    }
    return _fallbackDocuments();
  }

  static Future<Directory> _fallbackDocuments() async {
    final directory = Directory(
      p.join(
        Directory.systemTemp.path,
        'unittrace-documents-$pid-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    directory.createSync(recursive: true);
    return directory;
  }
}
