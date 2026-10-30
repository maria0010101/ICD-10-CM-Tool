// Run as a native Flutter test from an ASCII checkout. Full sources stay local.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';

void main() {
  const input = String.fromEnvironment('ICD_PROFILE_DATA');
  const evidence = String.fromEnvironment('ICD_PROFILE_EVIDENCE');
  test(
    'new official CM/PCS releases import and search using the App repository',
    () async {
      final folder = await Directory.systemTemp.createTemp('icd023-official-');
      final store = await PackageStore.open(
        folder,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      final report = <String, Object?>{};
      try {
        final files = await Directory(input)
            .list()
            .where((f) => f.path.endsWith('.icdpack'))
            .cast<File>()
            .toList();
        files.sort((a, b) => a.path.compareTo(b.path));
        expect(files.length, 10);
        for (final file in files) {
          final original = await fileHash(file);
          final hash = await store.publish(
            await store.prepare(file, capacity: 1 << 40),
          );
          expect(hash, original);
          await store.activate(hash);
          final m = store.manifest(hash);
          final repo = DictionaryRepository(store.contentPath(hash), m);
          try {
            final code = m.isPcs ? '0016070' : 'I509';
            final queries = m.isPcs
                ? ['0016070', 'bypass', 'ventricle']
                : ['I50.9', 'I509', 'heart failure'];
            if (m.json['language'] == 'en+zh-TW')
              queries.add(m.isPcs ? '腦室' : '心臟衰竭');
            final queriesResult = <Object?>[];
            for (var i = 0; i < 50; i++) {
              final q = queries[i % queries.length];
              final results = repo.search(q);
              expect(results, isNotEmpty, reason: '${m.id}: $q');
              queriesResult.add({'query': q, 'results': results});
            }
            final codeRow = repo.rows(
              'SELECT * FROM code_nodes WHERE code_normalized=?',
              [code],
            ).single;
            final notes = repo.detail(codeRow['id'] as int)['notes'];
            if (m.json['code_status_policy'] == 'not_provided') {
              expect(
                repo
                    .rows(
                      'SELECT count(*) AS n FROM code_nodes WHERE billable!=0',
                    )
                    .single['n'],
                0,
              );
              if (!m.isPcs) expect(repo.translations('T50B96'), isEmpty);
            }
            report[m.id] = {
              'package_sha256': hash,
              'row_counts': m.counts,
              'edition': m.edition,
              'release_id': m.json['release_id'],
              'snapshots': queriesResult,
              'notes': notes,
              'roots': repo.children(null),
            };
          } finally {
            repo.close();
          }
          expect(await fileHash(file), original);
        }
        await File(evidence).writeAsString(
          jsonEncode({'os': Platform.operatingSystemVersion, 'packs': report}),
        );
      } finally {
        store.close();
        await folder.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
