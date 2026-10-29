import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

class SelectedPackage {
  final File file;
  final bool temporary;
  SelectedPackage(this.file, {this.temporary = false});
  Future<void> dispose() async {
    if (temporary && await file.exists()) await file.delete();
  }
}

Future<SelectedPackage?> pickPackage() async {
  if (Platform.isAndroid) {
    // Native SAF streams to a private cache file; never return large byte arrays.
    final path = await const MethodChannel('tw.offline.icd/storage')
        .invokeMethod<String>('pickPackage');
    return path == null ? null : SelectedPackage(File(path), temporary: true);
  }
  final selected = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'ICD package', extensions: ['icdpack']),
    ],
  );
  return selected == null ? null : SelectedPackage(File(selected.path));
}
