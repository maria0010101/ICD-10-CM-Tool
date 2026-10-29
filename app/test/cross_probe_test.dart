import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';

import '../test_support/probe.dart';

void main() {
  test('50-query native snapshot + 1000-query warm benchmark', () async {
    expect(probeQueries.length, 50);
    final root = await Directory.systemTemp.createTemp('icd-probe-');
    final store = await PackageStore.open(
      root,
      jsonDecode(await File('assets/schema_contract.json').readAsString())
          as Map<String, dynamic>,
    );
    final p = await store.prepare(
      File('../samples/sample-demo-v1.icdpack'),
      capacity: 1 << 40,
    );
    final hash = await store.publish(p);
    await store.activate(hash);
    final repo = DictionaryRepository(
      store.contentPath(hash),
      store.manifest(hash),
    );
    try {
      final report = {
        ...queryProbe(repo, hash),
        'benchmark': benchmark(repo),
        'os': Platform.operatingSystemVersion,
        'time': DateTime.now().toUtc().toIso8601String(),
        'edition': repo.manifest.edition,
        'build_revision': 'working-tree-0.1.0',
      };
      await Directory('../evidence').create(recursive: true);
      await File('../evidence/linux-probe.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    } finally {
      repo.close();
      store.close();
      await root.delete(recursive: true);
    }
  });
  test(
    'official English release native snapshot and 1000 warm queries',
    () async {
      final root = await Directory.systemTemp.createTemp('icd-official-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      final p = await store.prepare(
        File('../.local-source/cdc-fy2027.icdpack'),
        capacity: 1 << 40,
      );
      final hash = await store.publish(p);
      await store.activate(hash);
      final repo = DictionaryRepository(
        store.contentPath(hash),
        store.manifest(hash),
      );
      try {
        final report = {
          ...queryProbe(repo, hash),
          'benchmark': benchmark(repo),
          'os': Platform.operatingSystemVersion,
          'time': DateTime.now().toUtc().toIso8601String(),
          'edition': repo.manifest.edition,
          'build_revision': 'working-tree-0.1.0',
        };
        await File('../evidence/linux-official-probe.json')
            .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
      } finally {
        repo.close();
        store.close();
        await root.delete(recursive: true);
      }
    },
    skip: !File('../.local-source/cdc-fy2027.icdpack').existsSync(),
  );
}
