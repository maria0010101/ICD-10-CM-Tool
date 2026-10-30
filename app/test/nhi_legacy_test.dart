import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/domain/manifest.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  test(
    'NHI 2014: same-edition rows, missing Chinese, unknown status, 50 queries',
    () async {
      final root = await Directory.systemTemp.createTemp('icd-legacy-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      final snapshots = <String, Object?>{};
      try {
        for (final cl in ['cm', 'pcs']) {
          final file = File('../samples/sample-nhi2014-$cl-v1.icdpack');
          final hash = await store.publish(
            await store.prepare(file, capacity: 1 << 40),
          );
          await store.activate(hash);
          final m = store.manifest(hash);
          expect(m.json['code_status_policy'], 'not_provided');
          expect(m.json['required_app_schema_min'], '1.2.0');
          final repo = DictionaryRepository(store.contentPath(hash), m);
          try {
            final results = <Object?>[];
            final queries = cl == 'cm'
                ? ['I50.9', 'I509', 'failure', '心臟', '衰竭']
                : ['0016070', 'bypass', 'heart', '心臟', '繞道'];
            for (var i = 0; i < 50; i++) {
              final rows = repo.search(queries[i % 5]);
              expect(rows, isNotEmpty);
              expect(rows.every((r) => r['billable'] == 0), isTrue);
              expect(codeStateLabel(rows.first, m), '來源未提供可申報狀態');
              results.add({'query': queries[i % 5], 'results': rows});
            }
            if (cl == 'cm') {
              expect(repo.translations('I50'), isEmpty);
              expect(
                repo.translations('I509').single['mapping_status'],
                'exact_edition',
              );
            }
            expect(repo.children(null), isNotEmpty);
            final malformed = Map<String, dynamic>.from(m.json)
              ..['code_status_policy'] = 'inferred';
            expect(
              () => PackManifest.parse(jsonEncode(malformed)),
              throwsA(isA<PackException>()),
            );
            snapshots[cl] = {
              'sha256': hash,
              'row_counts': m.counts,
              'snapshots': results,
            };
          } finally {
            repo.close();
          }
        }
        expect(
          snapshots,
          jsonDecode(
            await File('../samples/sample-nhi2014-probe.json').readAsString(),
          ),
        );
        await File('../evidence/nhi2014-native.json').writeAsString(
          jsonEncode({
            'os': Platform.operatingSystemVersion,
            'packs': snapshots,
          }),
        );
      } finally {
        store.close();
        await root.delete(recursive: true);
      }
    },
  );
}
