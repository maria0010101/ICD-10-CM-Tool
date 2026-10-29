// Bounded, strict ZIP v1 reader. No generic extraction or executable content.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

import '../domain/manifest.dart';

class ZipMember {
  final String name;
  final int compressed, size, method, crc, offset;
  ZipMember(
    this.name,
    this.compressed,
    this.size,
    this.method,
    this.crc,
    this.offset,
  );
}

class SafeZip {
  static const maxArchive = 256 * 1024 * 1024, maxTotal = 512 * 1024 * 1024;
  final File file;
  final List<ZipMember> members;
  SafeZip._(this.file, this.members);
  static Future<SafeZip> inspect(File file) async {
    final length = await file.length();
    if (length < 22 || length > maxArchive) {
      throw PackException('ZIP 檔案大小超出限制');
    }
    final raf = await file.open();
    try {
      final tailSize = min(length, 65557);
      await raf.setPosition(length - tailSize);
      final tail = await raf.read(tailSize);
      final b = ByteData.sublistView(tail);
      var end = -1;
      for (var i = tailSize - 22; i >= 0; i--) {
        if (b.getUint32(i, Endian.little) == 0x06054b50 &&
            i + 22 + b.getUint16(i + 20, Endian.little) == tailSize) {
          end = i;
          break;
        }
      }
      if (end < 0) {
        throw PackException('ZIP central directory 不完整');
      }
      int u16(int i) => b.getUint16(end + i, Endian.little);
      int u32(int i) => b.getUint32(end + i, Endian.little);
      if (u16(4) != 0 || u16(6) != 0 || u16(8) != 3 || u16(10) != 3) {
        throw PackException('ZIP 僅允許三個檔案、單磁碟、非 ZIP64');
      }
      final cdSize = u32(12), cdOffset = u32(16);
      if (cdSize > 8192 || cdOffset + cdSize != length - tailSize + end) {
        throw PackException('ZIP 目錄大小/位移錯誤');
      }
      await raf.setPosition(cdOffset);
      final raw = await raf.read(cdSize);
      final d = ByteData.sublistView(raw);
      final entries = <ZipMember>[];
      final names = <String>{};
      var p = 0, total = 0;
      for (var i = 0; i < 3; i++) {
        if (p + 46 > raw.length ||
            d.getUint32(p, Endian.little) != 0x02014b50) {
          throw PackException('ZIP central header 錯誤');
        }
        int v16(int j) => d.getUint16(p + j, Endian.little);
        int v32(int j) => d.getUint32(p + j, Endian.little);
        final flags = v16(8),
            method = v16(10),
            crc = v32(16),
            compressed = v32(20),
            size = v32(24),
            n = v16(28),
            extra = v16(30),
            comment = v16(32),
            attr = v32(38),
            local = v32(42);
        if (p + 46 + n + extra + comment > raw.length) {
          throw PackException('ZIP 截斷');
        }
        final name = utf8.decode(raw.sublist(p + 46, p + 46 + n));
        if (!{
              'manifest.json',
              'content.sqlite',
              'checksums.sha256',
            }.contains(name) ||
            !names.add(name) ||
            ((attr >> 16) & 0xf000) == 0xa000 ||
            (flags & ~0x800) != 0 ||
            ![0, 8].contains(method) ||
            v16(34) != 0) {
          throw PackException('ZIP 路徑、重複檔、symlink、加密或壓縮格式不合法');
        }
        total += size;
        if (size > maxTotal ||
            total > maxTotal ||
            size > max(1, compressed) * 200 ||
            (name != 'content.sqlite' && size > 1024 * 1024)) {
          throw PackException('ZIP 解壓大小/比例超限');
        }
        await raf.setPosition(local);
        final header = await raf.read(30);
        if (header.length != 30) {
          throw PackException('ZIP local header 截斷');
        }
        final l = ByteData.sublistView(header);
        if (l.getUint32(0, Endian.little) != 0x04034b50 ||
            l.getUint16(6, Endian.little) != flags ||
            l.getUint16(8, Endian.little) != method ||
            l.getUint32(14, Endian.little) != crc ||
            l.getUint32(18, Endian.little) != compressed ||
            l.getUint32(22, Endian.little) != size) {
          throw PackException('ZIP central/local header 不一致');
        }
        final localN = l.getUint16(26, Endian.little),
            localExtra = l.getUint16(28, Endian.little);
        final localName = utf8.decode(await raf.read(localN));
        final offset = local + 30 + localN + localExtra;
        if (localName != name ||
            offset + compressed > cdOffset ||
            localN > 128) {
          throw PackException('ZIP local 路徑或大小錯誤');
        }
        entries.add(ZipMember(name, compressed, size, method, crc, offset));
        p += 46 + n + extra + comment;
      }
      if (p != raw.length || names.length != 3) {
        throw PackException('ZIP 多餘目錄資料');
      }
      final sorted = [...entries]..sort((a, b) => a.offset.compareTo(b.offset));
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].offset <
            sorted[i - 1].offset + sorted[i - 1].compressed + 30) {
          throw PackException('ZIP 區段重疊');
        }
      }
      return SafeZip._(file, entries);
    } finally {
      await raf.close();
    }
  }

  Future<void> extract(Directory stage) async {
    for (final entry in members) {
      final raf = await file.open();
      final out = File('${stage.path}/${entry.name}').openWrite();
      var size = 0, crc = 0;
      Stream<List<int>> chunks() async* {
        await raf.setPosition(entry.offset);
        var remaining = entry.compressed;
        while (remaining > 0) {
          final data = await raf.read(min(64 * 1024, remaining));
          if (data.isEmpty) {
            throw PackException('ZIP 資料截斷');
          }
          remaining -= data.length;
          yield data;
        }
      }

      try {
        final stream = entry.method == 8
            ? ZLibDecoder(raw: true).bind(chunks())
            : chunks();
        await for (final chunk in stream) {
          size += chunk.length;
          if (size > entry.size || size > maxTotal) {
            throw PackException('實際解壓大小超限');
          }
          crc = getCrc32(chunk, crc);
          out.add(chunk);
          await out.flush();
        }
        if (size != entry.size || crc != entry.crc) {
          throw PackException('ZIP CRC/size 不符');
        }
      } finally {
        await out.close();
        await raf.close();
      }
    }
  }
}
