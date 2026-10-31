import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';

void main() {
  late Directory root;
  late PackageStore store;
  late DictionaryRepository repo;
  late String hash;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('guided-test-');
    store = await PackageStore.open(
      root,
      jsonDecode(await File('assets/schema_contract.json').readAsString())
          as Map<String, dynamic>,
    );
    hash = await store.publish(
      await store.prepare(
        File('../samples/sample-index-guidance-v1.icdpack'),
        capacity: 1 << 40,
      ),
    );
    repo = DictionaryRepository(store.contentPath(hash), store.manifest(hash));
  });
  tearDown(() async {
    repo.close();
    store.close();
    await root.delete(recursive: true);
  });
  test('Index precedes Tabular, retains official order, repeated codes, and all pages', () async {
    expect(
      repo.search('Diabetes, diabetic').first['code'],
      'E10.21',
    ); // old relevance API
    final page = repo.searchPage('Diabetes, diabetic');
    expect(page.mode, 'index-context');
    expect(page.total, 120);
    expect(page.rows.length, 100);
    expect(page.hasMore, isTrue);
    expect(page.rows.take(4).map((r) => r['sub_term'] ?? r['main_term']), [
      'Diabetes, diabetic (SAMPLE)',
      'with',
      'amyotrophy SAMPLE',
      'chronic kidney disease SAMPLE',
    ]);
    expect(page.rows.first['target_code'], 'E11.9');
    final next = repo.searchPage('Diabetes, diabetic', offset: 100);
    expect(next.rows.length, 20);
    expect(next.hasMore, isFalse);
    final all = [...page.rows, ...next.rows];
    expect(all.map((r) => r['id']).toSet().length, 120);
    expect(all.every((r) => !r.containsKey('node_key')), isTrue);
    expect(
      all.where((r) => r['target_code'] == 'E11.9').length,
      greaterThan(100),
    );
    expect(
      await fileHash(File('../samples/sample-index-guidance-v1.icdpack')),
      hash,
    );
    final snapshots = <String, Object?>{};
    for (final q in [
      'Diabetes, diabetic',
      'diabetic diabetes',
      'diab kid',
      'diabetes type 1',
      'diabetes type 2',
    ]) {
      final p = repo.searchPage(q, limit: 500);
      snapshots[q] = {'total': p.total, 'rows': p.rows};
    }
    await File('../evidence/guided-native.json').writeAsString(
      jsonEncode({
        'sha256': hash,
        'snapshots': snapshots,
        'os': Platform.operatingSystemVersion,
      }),
    );
  });
  test('commas/case/order normalize; prefix and exact-word/AND/OR semantics remain explicit', () {
    final a = repo.searchPage('Diabetes, diabetic', limit: 500).rows;
    expect(repo.searchPage('DIABETIC diabetes', limit: 500).rows, a);
    final q = repo.searchPage('diab kid');
    expect(q.total, 3);
    expect(q.rows.map((r) => r['index_depth']), [0, 1, 2]);
    expect(q.rows.last['sub_term'], 'chronic kidney disease SAMPLE');
    expect(repo.searchPage('diab kid', prefix: false).total, 0);
    expect(repo.searchPage('betes').total, 0);
    expect(repo.searchPage('diabetes absent').total, 0);
    expect(repo.searchPage('diabetes absent', any: true).total, 120);
    expect(
      repo
          .searchPage('diabetes type 1')
          .rows
          .where((r) => r['sub_term'] == 'type 2'),
      isEmpty,
    );
    expect(
      repo
          .searchPage('diabetes type 2')
          .rows
          .where((r) => r['sub_term'] == 'type 1'),
      isEmpty,
    );
  });
  test('live single term suggests main headings; branch can show all children; codes stay exact', () {
    final p = repo.searchPage('diab', suggestions: true);
    expect(p.mode, 'index-suggestions');
    expect(p.total, 1);
    final b = repo.searchPage(
      '',
      branch: p.rows.single['id'] as int,
      limit: 500,
    );
    expect(b.total, 120);
    final c = repo.searchPage('E11.9');
    expect(c.mode, 'code');
    expect(c.rows.single['code'], 'E11.9');
    expect(
      repo.searchPage('Diabetes diabetic', guided: false).rows.first['code'],
      'E10.21',
    );
    expect(
      repo.searchPage('Diabetes diabetic', scope: 'tabular').rows.first['code'],
      'E10.21',
    );
    final reference =
        repo
                .rows(
                  "SELECT id FROM index_entries WHERE main_term='Reference-only SAMPLE'",
                )
                .single['id']
            as int;
    expect(repo.indexDetail(reference)['crossrefs'], isNotEmpty);
    expect(
      repo
          .searchPage('diabetes diabetic')
          .rows
          .any((r) => r['main_term'] == 'Reference-only SAMPLE'),
      isFalse,
    );
  });
}
