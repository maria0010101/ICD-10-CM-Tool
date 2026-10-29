// Copy into an ASCII Flutter app/test directory; run with ICD_IMPORT_DATA and
// ICD_IMPORT_EVIDENCE dart-defines. Uses only isolated temporary user state.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';

void main() {
  const input = String.fromEnvironment('ICD_IMPORT_DATA');
  const evidence = String.fromEnvironment('ICD_IMPORT_EVIDENCE');
  test(
    'Actual local official CM packs import without App schema changes',
    () async {
      final folder = await Directory.systemTemp.createTemp('icd-new-official-');
      final contract = jsonDecode(
        await File('assets/schema_contract.json').readAsString(),
      ) as Map<String, dynamic>;
      final store = await PackageStore.open(folder, contract);
      final results = <String, Object?>{};
      final hashes = <String, String>{};
      try {
        for (final name in [
          'cm-fy2026-oct',
          'cm-fy2026-apr',
          'cm-fy2027-oct',
          'nhi2023-cm-ods-unresolved',
        ]) {
          final file = File('$input/$name.icdpack');
          final originalSha = sha256
              .convert(await file.readAsBytes())
              .toString();
          final prepared = await store.prepare(file, capacity: 1 << 40);
          expect(prepared.hash, originalSha);
          final hash = await store.publish(prepared);
          hashes[name] = hash;
          final manifest = store.manifest(hash);
          if (name.startsWith('cm-')) {
            await store.activate(hash);
            final repo = DictionaryRepository(
              store.contentPath(hash),
              manifest,
            );
            try {
              expect(
                repo.search('I509').any((r) => r['code'] == 'I50.9'),
                isTrue,
              );
              expect(repo.search('heart failure'), isNotEmpty);
              expect(repo.children(null), isNotEmpty);
              results[name] = {
                'package_sha256': hash,
                'row_counts': manifest.counts,
                'english_and_code_search': true,
              };
            } finally {
              repo.close();
            }
          } else {
            await store.activate(hash, translation: true);
            final baseHash = hashes['cm-fy2027-oct']!;
            final repo = DictionaryRepository(
              store.contentPath(baseHash),
              store.manifest(baseHash),
              overlayPath: store.contentPath(hash),
              overlayManifest: manifest,
            );
            try {
              expect(repo.translations('I509'), isEmpty);
              final reference = repo.translations(
                'I509',
                includeUnresolved: true,
              );
              expect(reference, isNotEmpty);
              expect(reference.single['mapping_status'], 'unresolved');
              expect(reference.single['title_zh_tw'], '心臟衰竭');
              expect(repo.search('心臟衰竭'), isEmpty);
              results[name] = {
                'package_sha256': hash,
                'row_counts': manifest.counts,
                'unresolved_not_qualified_translation': true,
              };
            } finally {
              repo.close();
            }
          }
          expect(
            sha256.convert(await file.readAsBytes()).toString(),
            originalSha,
          );
        }
        final report = {
          'os': Platform.operatingSystemVersion,
          'sqlite': store.user
              .select('select sqlite_version() as v')
              .single['v'],
          'packs': results,
          'scope': 'Linux native Flutter test engine, not Windows/Android full official acceptance',
        };
        if (evidence.isNotEmpty)
          await File(
            evidence,
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      } finally {
        store.close();
        await folder.delete(recursive: true);
      }
    },
    skip: input.isEmpty,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
