import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'large NHI native streaming copy/import and PCS real-data search',
    (tester) async {
      final docs = await getApplicationSupportDirectory();
      final root = await Directory(
        '${docs.path}/release020-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final inputs = await Directory('${root.path}/inputs').create();
      // ignore: avoid_print
      print('ICD020_INPUT_READY:${inputs.path}');
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (!await File('${inputs.path}/ready').exists() &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await File('${inputs.path}/ready').exists(), isTrue);
      final expected = jsonDecode(
        await File('${inputs.path}/ready').readAsString(),
      ) as Map<String, dynamic>;
      final schema = jsonDecode(
        await rootBundle.loadString('assets/schema_contract.json'),
      ) as Map<String, dynamic>;
      final store = await PackageStore.open(
        Directory('${root.path}/state'),
        schema,
      );
      final report = <String, Object?>{};
      try {
        for (final name in ['cm', 'nhi', 'pcs', 'twpcs']) {
          final source = File('${inputs.path}/$name.icdpack');
          File input = source;
          final watch = Stopwatch()..start();
          if (name == 'nhi') {
            final path = await const MethodChannel('tw.offline.icd/storage')
                .invokeMethod<String>(
                  'debugCopyPackageUri',
                  source.uri.toString(),
                );
            expect(path, isNotNull);
            input = File(path!);
            expect(await fileHash(input), expected[name]);
          }
          final prepared = await store.prepare(input);
          expect(prepared.hash, expected[name]);
          final hash = await store.publish(prepared);
          await store.activate(hash, translation: name == 'nhi');
          if (name == 'cm') {
            store.favorite(store.manifest(hash).id, 'I50.9', true);
            store.saveNote(
              store.manifest(hash).id,
              'I50.9',
              'isolated regression note',
            );
          }
          final base = store.active!;
          final overlay = store.overlay;
          final repo = DictionaryRepository(
            store.contentPath(base),
            store.manifest(base),
            overlayPath: overlay == null ? null : store.contentPath(overlay),
            overlayManifest: overlay == null ? null : store.manifest(overlay),
          );
          try {
            if (name == 'nhi') {
              expect(repo.translations('I509'), isEmpty);
              expect(
                repo
                    .translations('I509', includeUnresolved: true)
                    .single['title_zh_tw'],
                '心臟衰竭',
              );
              expect(repo.search('心臟衰竭'), isEmpty);
            } else if (name == 'pcs') {
              final row = repo.search('0016070').first;
              expect(row['billable'], 1);
              expect(
                (repo.detail(row['id'] as int)['pcs_axes'] as List).length,
                7,
              );
              expect(repo.search('Bypass'), isNotEmpty);
            } else if (name == 'twpcs') {
              expect(repo.search('0016070').first['title_zh_tw'], isNotNull);
              expect(repo.search('腦室'), isNotEmpty);
            } else {
              expect(repo.search('I509').first['code'], 'I50.9');
            }
            report[name] = {
              'package_sha256': hash,
              'counts': store.manifest(hash).counts,
              'duration_ms': watch.elapsedMilliseconds,
              'classification': store.manifest(hash).classification,
            };
          } finally {
            repo.close();
          }
          if (input.path != source.path) await input.delete();
          expect(await fileHash(source), expected[name]);
          // ignore: avoid_print
          print('ICD020_PACK_OK:$name');
        }
        expect(store.isFavorite('icd10cm-us-fy2027-oct-en', 'I50.9'), isTrue);
        expect(
          store.note('icd10cm-us-fy2027-oct-en', 'I50.9'),
          'isolated regression note',
        );
        report['old_user_data_test_scope'] =
            'only new isolated .debug test directory; production app untouched';
        report['os'] = Platform.operatingSystemVersion;
        final file = File('${docs.path}/release020-report.json');
        await file.writeAsString(jsonEncode(report));
        // ignore: avoid_print
        print('ICD020_REPORT_READY:${file.path}');
      } finally {
        store.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
