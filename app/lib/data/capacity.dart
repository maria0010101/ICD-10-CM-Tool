import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

// Platform storage preflight. Write/flush failures are still handled transactionally.
Future<int> availableBytes(String path) async {
  if (Platform.isAndroid) {
    return (await const MethodChannel('tw.offline.icd/storage')
        .invokeMethod<int>('availableBytes', path))!;
  }
  if (Platform.isWindows) {
    final lib = DynamicLibrary.open('kernel32.dll');
    final fn = lib
        .lookupFunction<
          Int32 Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          ),
          int Function(
            Pointer<Utf16>,
            Pointer<Uint64>,
            Pointer<Uint64>,
            Pointer<Uint64>,
          )
        >('GetDiskFreeSpaceExW');
    final p = path.toNativeUtf16(),
        free = calloc<Uint64>(),
        total = calloc<Uint64>(),
        all = calloc<Uint64>();
    try {
      if (fn(p, free, total, all) == 0) {
        throw FileSystemException('無法查詢磁碟空間', path);
      }
      return free.value;
    } finally {
      calloc.free(p);
      calloc.free(free);
      calloc.free(total);
      calloc.free(all);
    }
  }
  // Linux x64 development host only. Android uses StatFs, Windows native Win32 above.
  if (Platform.isLinux && sizeOf<IntPtr>() == 8) {
    final fn = DynamicLibrary.open('libc.so.6')
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Pointer<Uint64>),
          int Function(Pointer<Utf8>, Pointer<Uint64>)
        >('statvfs');
    final p = path.toNativeUtf8(), buffer = calloc<Uint64>(32);
    try {
      if (fn(p, buffer) != 0) {
        throw FileSystemException('statvfs failed', path);
      }
      return buffer[1] * buffer[4];
    } finally {
      calloc.free(p);
      calloc.free(buffer);
    }
  }
  throw UnsupportedError('此平台尚未驗證磁碟空間檢查');
}
