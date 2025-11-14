import 'package:flutter/services.dart';

final class Assets {
  static Future<Uint8List> getByPath(String path) async {
    final byteData = await rootBundle.load(path);
    final buffer = byteData.buffer.asUint8List();
    return buffer.sublist(0);
  }
}
