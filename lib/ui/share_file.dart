import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// A picture or PDF for the share sheet. On a phone it's written to the temp folder first; in the
/// web app it stays in memory, and share_plus downloads it where the browser can't share files.
Future<XFile> shareFile(Uint8List bytes, {required String name, required String mimeType}) async {
  if (kIsWeb) return XFile.fromData(bytes, name: name, mimeType: mimeType);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, mimeType: mimeType);
}
