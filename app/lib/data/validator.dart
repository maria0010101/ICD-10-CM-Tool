import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import '../domain/manifest.dart';
import 'repository.dart';

Future<String> fileHash(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

Future<PackManifest> validateStage(
  Directory stage,
  Map<String, dynamic> contract,
) async {
  final raw = await File('${stage.path}/manifest.json').readAsString();
  final manifest = PackManifest.parse(raw);
  final content = File('${stage.path}/content.sqlite');
  final hash = await fileHash(content);
  final manifestHash = await fileHash(File('${stage.path}/manifest.json'));
  if (hash != manifest.json['content_sha256'] ||
      await File('${stage.path}/checksums.sha256').readAsString() !=
          '$hash  content.sqlite\n$manifestHash  manifest.json\n') {
    throw PackException('SHA256 驗證失敗');
  }
  final db = sqlite3.open(content.path, mode: OpenMode.readOnly);
  try {
    db.execute('PRAGMA trusted_schema=OFF');
    db.execute('PRAGMA query_only=ON');
    final actual = {
      for (final r in db.select(
        "SELECT name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'",
      ))
        r['name'] as String: r['sql'],
    };
    if (actual.length != contract.length ||
        actual.entries.any((e) => contract[e.key] != e.value)) {
      throw PackException('SQLite schema 不符合契約（禁止 views/triggers/extension）');
    }
    if (db.select('PRAGMA user_version').single.values.first != 10000 ||
        db
                .select('PRAGMA integrity_check')
                .map((r) => r.values.first)
                .join(',') !=
            'ok' ||
        db.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw PackException('SQLite integrity/schema/foreign keys 驗證失敗');
    }
    final meta = {
      for (final r in db.select('SELECT * FROM package_meta'))
        r['key']: r['value'],
    };
    if (meta.length != 2 ||
        meta['package_id'] != manifest.id ||
        meta['schema_version'] != '1.0.0') {
      throw PackException('SQLite metadata 不一致');
    }
    for (final table in contentTables) {
      if (db.select('SELECT count(*) AS n FROM $table').single['n'] !=
          manifest.counts[table]) {
        throw PackException('資料列數不符：$table');
      }
    }
    if (!manifest.isOverlay && manifest.counts['code_nodes'] == 0) {
      throw PackException('英文包不可為空');
    }
    for (final table in ['code_nodes', 'index_entries']) {
      final parents = {
        for (final r in db.select('SELECT id,parent_id FROM $table'))
          r['id'] as int: r['parent_id'] as int?,
      };
      final checked = <int>{};
      for (final id in parents.keys) {
        final seen = <int>{};
        int? current = id;
        while (current != null && !checked.contains(current)) {
          if (!seen.add(current) || seen.length > 100) {
            throw PackException('分類樹循環或層數超限');
          }
          current = parents[current];
        }
        checked.addAll(seen);
      }
    }
    for (final t in [
      ('code_search_fts', 'code_nodes', ['code', 'title_en']),
      ('index_search_fts', 'index_entries', ['term_path']),
    ]) {
      final cols = t.$3.join(',');
      final diff = db.select(
        'SELECT rowid,$cols FROM ${t.$1} EXCEPT SELECT id,$cols FROM ${t.$2} UNION ALL SELECT id,$cols FROM ${t.$2} EXCEPT SELECT rowid,$cols FROM ${t.$1}',
      );
      if (diff.isNotEmpty ||
          db.select('SELECT count(*) AS n FROM ${t.$1}').single['n'] !=
              db.select('SELECT count(*) AS n FROM ${t.$2}').single['n']) {
        throw PackException('FTS content 不一致');
      }
    }
    // Bound row materialization: large official NHI overlays carry verbose
    // source-column JSON. A keyset batch keeps that payload out of memory.
    var lastTranslation = 0;
    final postings = db.prepare(
      'SELECT ngram,code_normalized FROM zh_ngrams WHERE source_translation_id=?',
    );
    try {
      while (true) {
        final batch = db.select(
          'SELECT id,code_normalized,title_zh_tw,search_normalized,mapping_status,base_package_id FROM translations WHERE id>? ORDER BY id LIMIT 256',
          [lastTranslation],
        );
        if (batch.isEmpty) break;
        for (final row in batch) {
          final title = row['title_zh_tw'] as String;
          if (title.length > 10000 ||
              row['search_normalized'] != normalizeText(title) ||
              (row['mapping_status'] != 'unresolved' &&
                  !manifest.bases.contains(row['base_package_id']))) {
            throw PackException('中譯 lineage/正規化錯誤');
          }
          final expected = ngrams(row['search_normalized'] as String);
          final actual = postings.select([row['id']]);
          if (actual.length != expected.length ||
              actual.any(
                (g) =>
                    g['code_normalized'] != row['code_normalized'] ||
                    !expected.contains(g['ngram']),
              )) {
            throw PackException('中文索引不完整');
          }
          lastTranslation = row['id'] as int;
        }
      }
    } finally {
      postings.close();
    }
  } finally {
    db.close();
  }
  // FTS integrity requires a write command. Run solely against a staging copy.
  final check = await content.copy('${stage.path}/fts-check.sqlite');
  final writable = sqlite3.open(check.path);
  try {
    for (final fts in ['code_search_fts', 'index_search_fts']) {
      writable.execute("INSERT INTO $fts($fts) VALUES ('integrity-check')");
    }
  } finally {
    writable.close();
    await check.delete();
  }
  return manifest;
}
