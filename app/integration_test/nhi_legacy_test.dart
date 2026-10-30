import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('NHI 2014 cross-platform same original packs and 100 queries', (
    tester,
  ) async {
    final docs = await getApplicationSupportDirectory();
    final folder = await Directory(
      '${docs.path}/legacy023-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final store = await PackageStore.open(
      Directory('${folder.path}/state'),
      jsonDecode(await rootBundle.loadString('assets/schema_contract.json'))
          as Map<String, dynamic>,
    );
    const cm = String.fromEnvironment('LEGACY_CM_B64');
    const pcs = String.fromEnvironment('LEGACY_PCS_B64');
    const expectedJson = String.fromEnvironment('LEGACY_EXPECTED_JSON');
    final snapshots = <String, Object?>{};
    try {
      for (final cl in ['cm', 'pcs']) {
        final file = File('${folder.path}/$cl.icdpack');
        await file.writeAsBytes(base64Decode(cl == 'cm' ? cm : pcs));
        final hash = await store.publish(await store.prepare(file));
        await store.activate(hash);
        final m = store.manifest(hash);
        final repo = DictionaryRepository(store.contentPath(hash), m);
        try {
          final queries = cl == 'cm'
              ? ['I50.9', 'I509', 'failure', '心臟', '衰竭']
              : ['0016070', 'bypass', 'heart', '心臟', '繞道'];
          final results = <Object?>[];
          for (var i = 0; i < 50; i++) {
            final rows = repo.search(queries[i % 5]);
            expect(rows, isNotEmpty);
            expect(codeStateLabel(rows.first, m), '來源未提供可申報狀態');
            results.add({'query': queries[i % 5], 'results': rows});
          }
          if (cl == 'cm') expect(repo.translations('I50'), isEmpty);
          snapshots[cl] = {
            'sha256': hash,
            'row_counts': m.counts,
            'snapshots': results,
          };
        } finally {
          repo.close();
        }
      }
      expect(snapshots, jsonDecode(expectedJson));
      await File('${docs.path}/legacy023-report.json').writeAsString(
        jsonEncode({'os': Platform.operatingSystemVersion, 'packs': snapshots}),
      );
      // ignore: avoid_print
      print('ICD023_REPORT:${docs.path}/legacy023-report.json');
    } finally {
      store.close();
      await folder.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
