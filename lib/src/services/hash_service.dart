import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class HashService {
  static String sha256ForBytes(List<int> bytes) =>
      sha256.convert(bytes).toString();

  static Future<String> sha256ForFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256ForBytes(bytes);
  }

  static String sha256ForJson(Map<String, Object?> json) {
    return sha256ForBytes(Uint8List.fromList(utf8.encode(jsonEncode(json))));
  }
}
