import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../domain/manifest.dart';
import 'capacity.dart';
import 'safe_zip.dart';
import 'validator.dart';

class PreparedPack {
  final String stage, hash;
  final PackManifest manifest;
  PreparedPack(this.stage, this.hash, this.manifest);
}

class PackageStore {
  final Directory root;
  final Database user;
  final Map<String, dynamic> contract;
  PackageStore._(this.root, this.user, this.contract);
  static Future<PackageStore> open(
    Directory root,
    Map<String, dynamic> contract,
  ) async {
    await root.create(recursive: true);
    final db = sqlite3.open('${root.path}/user.sqlite');
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA journal_mode=DELETE');
    db.execute('PRAGMA synchronous=FULL');
    db.execute(
      'CREATE TABLE IF NOT EXISTS preferences(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS installed_packages(hash TEXT PRIMARY KEY,package_id TEXT NOT NULL,version TEXT NOT NULL,manifest TEXT NOT NULL,installed_at TEXT NOT NULL,UNIQUE(package_id,version))',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS import_log(id INTEGER PRIMARY KEY,time TEXT NOT NULL,event TEXT NOT NULL,hash TEXT)',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS favorites(package_id TEXT NOT NULL,code TEXT NOT NULL,PRIMARY KEY(package_id,code))',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS personal_notes(package_id TEXT NOT NULL,code TEXT NOT NULL,note TEXT NOT NULL,PRIMARY KEY(package_id,code))',
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS search_history(package_id TEXT NOT NULL,query TEXT NOT NULL,time TEXT NOT NULL)',
    );
    return PackageStore._(root, db, contract);
  }

  void close() => user.close();
  String? preference(String key) {
    final rows = user.select('SELECT value FROM preferences WHERE key=?', [
      key,
    ]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  void setPreference(String key, String value) => user.execute(
    'INSERT OR REPLACE INTO preferences VALUES (?,?)',
    [key, value],
  );
  List<Map<String, Object?>> get installed => user
      .select('SELECT * FROM installed_packages ORDER BY installed_at,hash')
      .map((r) => Map<String, Object?>.from(r))
      .toList();
  PackManifest manifest(String hash) => PackManifest.parse(
    user.select('SELECT manifest FROM installed_packages WHERE hash=?', [
          hash,
        ]).single['manifest']
        as String,
  );
  String contentPath(String hash) =>
      '${root.path}/packages/$hash/content.sqlite';
  String? get active => preference('active');
  String? get overlay => preference('overlay');
  Future<PreparedPack> prepare(
    File input, {
    int? capacity,
    String? failAt,
  }) async {
    // Inspect before any large copy. TOCTOU checked by inspecting the private copy again.
    final inspected = await SafeZip.inspect(input);
    final required =
        inspected.members.fold<int>(0, (n, e) => n + e.size) * 2 +
        await input.length() +
        16 * 1024 * 1024;
    final free = capacity ?? await availableBytes(root.path);
    if (free < required) {
      throw PackException('磁碟空間不足：需 $required bytes，可用 $free；現行版本未更動');
    }
    final rootPath = root.path;
    final schema = contract;
    return Isolate.run(() async {
      final staging = await Directory('$rootPath/staging')
          .create(recursive: true);
      final stage = await staging.createTemp('import-');
      try {
        await input.copy('${stage.path}/original.icdpack');
        if (failAt == 'copy') {
          throw PackException('Injected interruption after copy');
        }
        final private = File('${stage.path}/original.icdpack');
        final zip = await SafeZip.inspect(private);
        await zip.extract(stage);
        final manifest = await validateStage(stage, schema);
        if (failAt == 'validate') {
          throw PackException('Injected interruption after validation');
        }
        return PreparedPack(stage.path, await fileHash(private), manifest);
      } catch (_) {
        await stage.delete(recursive: true);
        rethrow;
      }
    });
  }

  Future<void> discard(PreparedPack p) async {
    final stage = Directory(p.stage);
    if (await stage.exists()) {
      await stage.delete(recursive: true);
    }
  }

  Future<String> publish(PreparedPack p, {String? failAt}) async {
    final duplicate = user.select(
      'SELECT hash FROM installed_packages WHERE package_id=? AND version=?',
      [p.manifest.id, p.manifest.json['package_version']],
    );
    if (duplicate.isNotEmpty) {
      if (duplicate.single['hash'] != p.hash) {
        throw PackException('同 package ID/版本已有不同 SHA256；請提升 package_version');
      }
      await discard(p);
      return p.hash;
    }
    final packages = await Directory('${root.path}/packages')
        .create(recursive: true);
    final dest = Directory('${packages.path}/${p.hash}');
    // Recheck files after preview before publication. No SQL or archive content executes.
    final schema = contract;
    await Isolate.run(() async {
      if (await fileHash(File('${p.stage}/original.icdpack')) != p.hash) {
        throw PackException('預覽後資料包已變動');
      }
      final m = await validateStage(Directory(p.stage), schema);
      if (jsonEncode(m.json) != jsonEncode(p.manifest.json)) {
        throw PackException('預覽後 manifest 已變動');
      }
    });
    if (await dest.exists()) {
      // Crash residue: replace nothing; validate its independently stored original before adoption.
      if (await fileHash(File('${dest.path}/original.icdpack')) != p.hash ||
          await fileHash(File('${dest.path}/content.sqlite')) !=
              p.manifest.json['content_sha256']) {
        throw PackException('殘留發布目錄不一致');
      }
      await discard(p);
    } else {
      await Directory(p.stage).rename(dest.path);
    }
    if (failAt == 'rename') {
      throw PackException('Injected interruption after rename');
    }
    user.execute('BEGIN IMMEDIATE');
    try {
      user.execute('INSERT INTO installed_packages VALUES (?,?,?,?,?)', [
        p.hash,
        p.manifest.id,
        p.manifest.json['package_version'],
        jsonEncode(p.manifest.json),
        DateTime.now().toUtc().toIso8601String(),
      ]);
      user.execute('INSERT INTO import_log(time,event,hash) VALUES (?,?,?)', [
        DateTime.now().toUtc().toIso8601String(),
        'validated/published',
        p.hash,
      ]);
      if (failAt == 'transaction') {
        throw PackException('Injected transaction interruption');
      }
      user.execute('COMMIT');
    } catch (_) {
      user.execute('ROLLBACK');
      rethrow;
    }
    return p.hash;
  }

  Future<void> activate(String hash, {bool translation = false}) async {
    final m = manifest(hash);
    if (translation) {
      if (m.kind != 'icd10cm_zh_tw' ||
          active == null ||
          !m.bases.contains(manifest(active!).id)) {
        throw PackException('中譯不相容目前英文 base');
      }
    } else if (m.kind == 'icd10cm_zh_tw') {
      throw PackException('中譯 overlay 不能當英文 base');
    }
    if (await fileHash(File(contentPath(hash))) != m.json['content_sha256']) {
      throw PackException('已安裝資料內容已損壞；未切換');
    }
    user.execute('BEGIN IMMEDIATE');
    try {
      final old = preference(translation ? 'overlay' : 'active');
      if (old != null && old != hash && !translation) {
        setPreference('previous', old);
      }
      setPreference(translation ? 'overlay' : 'active', hash);
      if (!translation &&
          overlay != null &&
          !manifest(overlay!).bases.contains(m.id)) {
        user.execute("DELETE FROM preferences WHERE key='overlay'");
      }
      user.execute('INSERT INTO import_log(time,event,hash) VALUES (?,?,?)', [
        DateTime.now().toUtc().toIso8601String(),
        'activated',
        hash,
      ]);
      user.execute('COMMIT');
    } catch (_) {
      user.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> rollback() async {
    final previous = preference('previous');
    if (previous == null) {
      throw PackException('沒有可回復版本');
    }
    await activate(previous);
  }

  bool isFavorite(String package, String code) => user.select(
    'SELECT 1 FROM favorites WHERE package_id=? AND code=?',
    [package, code],
  ).isNotEmpty;
  void favorite(String package, String code, bool enabled) => user.execute(
    enabled
        ? 'INSERT OR IGNORE INTO favorites VALUES (?,?)'
        : 'DELETE FROM favorites WHERE package_id=? AND code=?',
    [package, code],
  );
  String note(String package, String code) {
    final rows = user.select(
      'SELECT note FROM personal_notes WHERE package_id=? AND code=?',
      [package, code],
    );
    return rows.isEmpty ? '' : rows.single['note'] as String;
  }

  void saveNote(String package, String code, String text) => user.execute(
    'INSERT OR REPLACE INTO personal_notes VALUES (?,?,?)',
    [package, code, text],
  );
  void recordSearch(String package, String query) {
    if (preference('history') == 'off' || query.isEmpty) {
      return;
    }
    user.execute('INSERT INTO search_history VALUES (?,?,?)', [
      package,
      query,
      DateTime.now().toUtc().toIso8601String(),
    ]);
  }

  String exportPersonal() => jsonEncode({
    'format': 'icd-user-1',
    'favorites': user
        .select('SELECT * FROM favorites')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
    'notes': user
        .select('SELECT * FROM personal_notes')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
  });
  void importPersonal(String source) {
    if (source.length > 1024 * 1024) {
      throw PackException('個人資料過大');
    }
    final m = jsonDecode(source) as Map<String, dynamic>;
    if (m['format'] != 'icd-user-1') {
      throw PackException('非使用者資料 JSON');
    }
    user.execute('BEGIN IMMEDIATE');
    try {
      for (final r in m['favorites'] as List) {
        if (r['package_id'] is! String || r['code'] is! String) {
          throw PackException('收藏格式錯誤');
        }
        favorite(r['package_id'], r['code'], true);
      }
      for (final r in m['notes'] as List) {
        if (r['package_id'] is! String ||
            r['code'] is! String ||
            r['note'] is! String) {
          throw PackException('註解格式錯誤');
        }
        saveNote(r['package_id'], r['code'], r['note']);
      }
      user.execute('COMMIT');
    } catch (_) {
      user.execute('ROLLBACK');
      rethrow;
    }
  }
}
