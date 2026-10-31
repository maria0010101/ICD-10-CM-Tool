import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';

import '../test_support/guided_probe.dart';

void main() {
  const input = String.fromEnvironment('GUIDED_OFFICIAL_PACK');
  const output = String.fromEnvironment('GUIDED_OFFICIAL_EVIDENCE');
  test(
    'FY2025 actual official pack: same website order and complete paginated forest',
    () async {
      final root = await Directory.systemTemp.createTemp('guided-official-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      try {
        final source = File(input);
        final original = await fileHash(source);
        final h = await store.publish(
          await store.prepare(source, capacity: 1 << 40),
        );
        final repo = DictionaryRepository(
          store.contentPath(h),
          store.manifest(h),
        );
        try {
          expect(repo.manifest.edition, 'FY2025');
          expect(repo.manifest.json['release_id'], '2025-04-01');
          final report = guidedProbe(repo);
          for (final q in guidanceQueries.take(3)) {
            expect((report[q] as Map)['total'], 449);
          }
          expect((report['diabetes kidney'] as Map)['total'], 24);
          expect((report['kidney diabetes'] as Map)['total'], 24);
          expect((report['diab neph'] as Map)['total'], 34);
          expect((report['betes'] as Map)['total'], 0);
          final page = repo.searchPage('Diabetes, diabetic');
          expect(page.rows.first['target_code'], 'E11.9');
          expect(
            page.rows.take(4).map((r) => r['sub_term'] ?? r['main_term']),
            [
              'Diabetes, diabetic(mellitus) (sugar)',
              'with',
              'amyotrophy',
              'arthropathy NEC',
            ],
          );
          final rows = <Map<String, Object?>>[];
          for (var offset = 0; offset < 449; offset += 100) {
            rows.addAll(
              repo.searchPage('Diabetes, diabetic', offset: offset).rows,
            );
          }
          expect(rows.length, 449);
          expect(rows.map((r) => r['id']).toSet().length, 449);
          final watch = Stopwatch();
          final times = <int>[];
          for (var i = 0; i < 105; i++) {
            watch
              ..reset()
              ..start();
            repo.searchPage('Diabetes, diabetic');
            watch.stop();
            if (i >= 5) times.add(watch.elapsedMicroseconds);
          }
          times.sort();
          if (output.isNotEmpty) {
            await File(output).writeAsString(
              jsonEncode({
                'sha256': h,
                'edition': repo.manifest.edition,
                'release_id': repo.manifest.json['release_id'],
                'snapshots': report,
                'first_page_p95_ms': times[94] / 1000,
                'os': Platform.operatingSystemVersion,
              }),
            );
          }
        } finally {
          repo.close();
        }
        expect(await fileHash(source), original);
      } finally {
        store.close();
        await root.delete(recursive: true);
      }
    },
    skip: input.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
