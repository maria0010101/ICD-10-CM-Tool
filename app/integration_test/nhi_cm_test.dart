import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/validator.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'official standalone NHI CM Chinese/English activation and hierarchy',
    (tester) async {
      final docs = await getApplicationSupportDirectory();
      final root = await Directory(
        '${docs.path}/release021-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final inputs = await Directory('${root.path}/inputs').create();
      // ignore: avoid_print
      print('ICD021_INPUT_READY:${inputs.path}');
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (!await File('${inputs.path}/ready').exists() &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await File('${inputs.path}/ready').exists(), true);
      final expected = jsonDecode(
        await File('${inputs.path}/ready').readAsString(),
      ) as Map<String, dynamic>;
      final source = File('${inputs.path}/nhi_cm.icdpack');
      final store = await PackageStore.open(
        Directory('${root.path}/state'),
        jsonDecode(await rootBundle.loadString('assets/schema_contract.json'))
            as Map<String, dynamic>,
      );
      final c = DictionaryController(store);
      try {
        final watch = Stopwatch()..start();
        final prepared = await store.prepare(source);
        expect(prepared.hash, expected['nhi_cm']);
        final hash = await store.publish(prepared);
        await c.choose(hash);
        expect(c.active, hash);
        expect(store.overlay, isNull);
        for (final query in ['I509', 'heart failure', '心臟衰竭']) {
          c.query = query;
          await c.search();
          expect(c.results, isNotEmpty);
        }
        c.query = 'I509';
        await c.search();
        expect(c.results.first['title_zh_tw'], '心臟衰竭');
        final m = store.manifest(hash);
        store.favorite(m.id, 'I50.9', true);
        store.saveNote(m.id, 'I50.9', 'SAMPLE isolated test note');
        final group = await c.resolveTarget('I50');
        expect(group, isNotEmpty);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  HierarchyTile(
                    row: group.first,
                    controller: c,
                    onOpen: c.open,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('I50 Heart failure'));
        // Bounded UI completion wait, not a guessed storage teardown delay.
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (find.byType(HierarchyTile).evaluate().length < 2 &&
            DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        expect(find.byType(HierarchyTile).evaluate().length, greaterThan(1));
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
        expect(await fileHash(source), hash);
        final report = {
          'sha256': hash,
          'counts': m.counts,
          'independent_activation': true,
          'queries': ['I509', 'heart failure', '心臟衰竭'],
          'actual_hierarchy_widget_expanded': true,
          'duration_ms': watch.elapsedMilliseconds,
          'source_edition_only': true,
          'production_package_untouched': true,
          'os': Platform.operatingSystemVersion,
        };
        await File('${docs.path}/release021-report.json')
            .writeAsString(jsonEncode(report));
        // ignore: avoid_print
        print('ICD021_REPORT_READY');
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
