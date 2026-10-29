import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/data/validator.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

import '../test_support/probe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('device same-package import/search/rollback + adaptive UX', (
    tester,
  ) async {
    final docs = await getApplicationSupportDirectory();
    final official = File('${docs.path}/official-input.icdpack');
    // Machine-readable handshake with the host-side integration runner.
    // ignore: avoid_print
    print('ICD_DEVICE_INPUT_READY:${docs.path}');
    if (const bool.fromEnvironment('EXPECT_OFFICIAL')) {
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (!await official.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(
        await official.exists(),
        true,
        reason: 'Official input transfer timed out',
      );
    }
    final root = Directory(
      '${docs.path}/isolated-integration-${DateTime.now().microsecondsSinceEpoch}',
    );
    final schema = jsonDecode(
      await rootBundle.loadString('assets/schema_contract.json'),
    ) as Map<String, dynamic>;
    final store = await PackageStore.open(root, schema);
    final input = File('${root.path}/input.icdpack');
    await input.writeAsBytes(
      base64Decode(const String.fromEnvironment('PACK1')),
    );
    final p = await store.prepare(input);
    final hash = await store.publish(p);
    await store.activate(hash);
    final repo = DictionaryRepository(
      store.contentPath(hash),
      store.manifest(hash),
    );
    final sampleReport = {
      ...queryProbe(repo, hash),
      'benchmark': benchmark(repo),
      'edition': repo.manifest.edition,
      'os': Platform.operatingSystemVersion,
      'time': DateTime.now().toUtc().toIso8601String(),
      'build_revision': 'working-tree-0.1.0',
    };
    repo.close();
    expect(hash, const String.fromEnvironment('PACK1_SHA256'));
    expect(
      sampleReport['snapshot_sha256'],
      const String.fromEnvironment('SNAPSHOT_SHA256'),
    );
    store.favorite('sample-demo-v1', 'I50.9', true);
    await input.writeAsBytes(
      base64Decode(const String.fromEnvironment('PACK2')),
    );
    final next = await store.prepare(input);
    final h2 = await store.publish(next);
    await store.activate(h2);
    await store.rollback();
    expect(store.active, hash);
    expect(store.isFavorite('sample-demo-v1', 'I50.9'), true);
    await expectLater(store.prepare(input, capacity: 0), throwsA(anything));
    expect(store.active, hash);
    final controller = DictionaryController(store);
    await controller.refresh();
    await tester.pumpWidget(DictionaryApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'I509');
    await tester.pump(const Duration(milliseconds: 250));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (controller.searching && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(controller.results.first['code'], 'I50.9');
    await tester.tap(find.textContaining('I50.9  Heart failure').first);
    await tester.pumpAndSettle();
    final detailDeadline = DateTime.now().add(const Duration(seconds: 20));
    while (controller.detail == null &&
        DateTime.now().isBefore(detailDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('本層與繼承 notes'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('本層與繼承 notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Navigator.of(tester.element(find.textContaining('本層與繼承 notes')))
        .canPop()) {
      Navigator.of(tester.element(find.textContaining('本層與繼承 notes'))).pop();
      await tester.pumpAndSettle();
    }
    final layouts = <String, Object?>{};
    for (final width in [390.0, 800.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1100));
      await tester.pumpAndSettle();
      final error = tester.takeException();
      layouts['$width'] = {
        'panes': paneCount(width),
        'exception': error?.toString(),
      };
      expect(error, isNull);
    }
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    Map<String, Object?>? officialReport;
    if (await official.exists()) {
      final p = await store.prepare(official);
      final h = await store.publish(p);
      await store.activate(h);
      final r = DictionaryRepository(store.contentPath(h), store.manifest(h));
      officialReport = {
        ...queryProbe(r, h),
        'benchmark': benchmark(r),
        'edition': r.manifest.edition,
      };
      expect(h, const String.fromEnvironment('OFFICIAL_SHA256'));
      expect(
        officialReport['snapshot_sha256'],
        const String.fromEnvironment('OFFICIAL_SNAPSHOT_SHA256'),
      );
      r.close();
    }
    final output = File('${docs.path}/device-report.json');
    await output.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'sample': sampleReport,
        'layouts': layouts,
        'official': officialReport,
        'user_data_isolated': true,
        'rollback_passed': true,
      }),
    );
    binding.reportData = {
      'report_path': output.path,
      'sample_snapshot': sampleReport['snapshot_sha256'],
      'official_tested': officialReport != null,
    };
    // Machine-readable completion marker; not production application logging.
    // ignore: avoid_print
    print('ICD_DEVICE_REPORT_READY:${output.path}');
    expect(
      await fileHash(File('${root.path}/packages/$hash/original.icdpack')),
      hash,
    );
    store.close();
    await root.delete(recursive: true);
  });
}
