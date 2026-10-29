import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';
import 'package:icd_dictionary/domain/manifest.dart';

void main() {
  late Directory root;
  late PackageStore store;
  final sample = File('../samples/sample-demo-v1.icdpack');
  setUp(() async {
    root = await Directory.systemTemp.createTemp('icd-tests-');
    store = await PackageStore.open(
      root,
      jsonDecode(await File('assets/schema_contract.json').readAsString())
          as Map<String, dynamic>,
    );
  });
  tearDown(() async {
    store.close();
    await root.delete(recursive: true);
  });
  Future<String> install(File file) async {
    final p = await store.prepare(file, capacity: 1 << 40);
    final h = await store.publish(p);
    await store.activate(h);
    return h;
  }

  test('normalization AND OR prefixes cannot inject FTS SQL', () {
    expect(normalizeCode(' i50.9 '), 'I509');
    expect(normalizeCode('Ｉ５０９'), 'I509');
    expect(
      ftsExpression('heart failure', prefix: false),
      '"heart" AND "failure"',
    );
    expect(
      ftsExpression('heart OR " ); DROP TABLE notes; --'),
      isNot(contains('DROP TABLE notes;')),
    );
    expect(ngrams('心臟衰竭'), containsAll(['心', '心臟', '衰竭']));
  });
  test(
    'same bytes readonly queries and inherited notes/index/lineage',
    () async {
      final h = await install(sample), m = store.manifest(store.active!);
      final repo = DictionaryRepository(store.contentPath(h), m);
      try {
        for (final q in [
          'I50.9',
          'I509',
          ' i509 ',
          'heart failure',
          'failure heart',
          'hear',
          '心臟衰竭',
        ]) {
          expect(
            repo.search(q).map((r) => r['code']),
            contains('I50.9'),
            reason: q,
          );
        }
        expect(repo.search('腎衰竭').single['code'], 'N17.9');
        expect(repo.search('未確認跨版翻譯'), isEmpty);
        expect(repo.detail(4)['notes'], hasLength(5));
        expect((repo.detail(4)['notes'] as List).first['inherited'], true);
        expect(repo.indexDetail(1)['crossrefs'], hasLength(1));
        expect(repo.indexDetail(4)['target_nodes'], isEmpty);
        expect(repo.search('S00.0').first['billable'], 0);
        expect(repo.translations('S000'), isEmpty);
        expect(
          repo.availableScopes(),
          containsAll(['drugs', 'external', 'neoplasm']),
        );
      } finally {
        repo.close();
      }
      expect(await fileHash(sample), h);
      expect(
        await fileHash(File('${root.path}/packages/$h/original.icdpack')),
        h,
      );
    },
  );
  test('atomic rollback survives interrupted staging/disk full/publish and isolates user data', () async {
    final h = await install(sample);
    store.favorite('sample-demo-v1', 'I50.9', true);
    store.saveNote('sample-demo-v1', 'I50.9', 'private local test');
    final next = File('../samples/sample-demo-v2.icdpack');
    await expectLater(
      store.prepare(next, capacity: 0),
      throwsA(isA<PackException>()),
    );
    for (final point in ['copy', 'validate']) {
      await expectLater(
        store.prepare(next, capacity: 1 << 40, failAt: point),
        throwsA(isA<PackException>()),
      );
      expect(store.active, h);
    }
    final p = await store.prepare(next, capacity: 1 << 40);
    await expectLater(
      store.publish(p, failAt: 'rename'),
      throwsA(isA<PackException>()),
    );
    expect(store.active, h);
    final retry = await store.prepare(next, capacity: 1 << 40);
    await expectLater(
      store.publish(retry, failAt: 'transaction'),
      throwsA(isA<PackException>()),
    );
    expect(store.active, h);
    final retry2 = await store.prepare(next, capacity: 1 << 40);
    final h2 = await store.publish(retry2);
    await store.activate(h2);
    expect(store.active, h2);
    await store.rollback();
    expect(store.active, h);
    expect(store.isFavorite('sample-demo-v1', 'I50.9'), true);
    expect(store.note('sample-demo-v1', 'I50.9'), 'private local test');
    final data = store.exportPersonal();
    store.importPersonal(data);
    expect(store.isFavorite('sample-demo-v1', 'I50.9'), true);
  });
  test('version diff reports changed description, never silently merges translation', () async {
    final h = await install(sample);
    final h2 = await install(File('../samples/sample-demo-v2.icdpack'));
    final a = DictionaryRepository(store.contentPath(h), store.manifest(h)),
        b = DictionaryRepository(store.contentPath(h2), store.manifest(h2));
    try {
      expect(a.compare(b).single['code'], 'I50.9');
    } finally {
      a.close();
      b.close();
    }
  });
  test(
    'malicious ZIP/DB/schema are rejected without changing active data',
    () async {
      final h = await install(sample);
      for (final kind in [
        'traversal',
        'duplicate',
        'symlink',
        'bomb',
        'checksum',
        'schema',
        'db',
        'trigger',
        'cycle',
        'duplicate-json',
      ]) {
        await expectLater(
          store.prepare(
            File('../tools/data_builder/tests/fixtures/unsafe/$kind.icdpack'),
            capacity: 1 << 40,
          ),
          throwsA(anything),
          reason: kind,
        );
        expect(store.active, h, reason: kind);
      }
    },
  );
  test('overlay cannot silently turn an unresolved translation into official compatible content', () async {
    final base = await install(sample);
    final prepared = await store.prepare(
      File('../samples/sample-overlay-unresolved.icdpack'),
      capacity: 1 << 40,
    );
    final overlay = await store.publish(prepared);
    await store.activate(overlay, translation: true);
    final repo = DictionaryRepository(
      store.contentPath(base),
      store.manifest(base),
      overlayPath: store.contentPath(overlay),
      overlayManifest: store.manifest(overlay),
    );
    try {
      expect(repo.search('跨版測試譯名'), isEmpty);
      expect(repo.translations('I509'), isEmpty);
      expect(
        repo
            .translations('I509', includeUnresolved: true)
            .single['mapping_status'],
        'unresolved',
      );
    } finally {
      repo.close();
    }
    await install(File('../samples/sample-demo-v2.icdpack'));
    expect(store.overlay, isNull);
    await expectLater(
      store.activate(overlay, translation: true),
      throwsA(isA<PackException>()),
    );
  });
  test('duplicate JSON keys cannot differ across validators', () {
    expect(
      () => rejectDuplicateJsonKeys('{"x":1,"x":2}'),
      throwsA(isA<PackException>()),
    );
    expect(
      () => rejectDuplicateJsonKeys('{"x":{"y":1},"z":{"y":2}}'),
      returnsNormally,
    );
  });
  test(
    'tampered installed file cannot activate, old pointer retained',
    () async {
      final h = await install(sample),
          h2 = await install(File('../samples/sample-demo-v2.icdpack'));
      await store.rollback();
      await File(store.contentPath(h2)).writeAsBytes([1, 2, 3]);
      await expectLater(store.activate(h2), throwsA(isA<PackException>()));
      expect(store.active, h);
    },
  );
}
