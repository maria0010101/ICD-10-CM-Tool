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
import 'package:icd_dictionary/ui/dictionary_app.dart';

import '../test_support/guided_probe.dart';

class DeviceGuidanceController extends DictionaryController {
  DeviceGuidanceController(super.store);
  Future<void>? lastSearch, lastMore;
  @override
  Future<void> search({bool submitted = false, bool keepBranch = false}) =>
      lastSearch = super.search(submitted: submitted, keepBranch: keepBranch);
  @override
  Future<void> loadMore() => lastMore = super.loadMore();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'official FY2025 Index source order, all snapshots, UI pagination',
    (tester) async {
      final docs = await getApplicationSupportDirectory();
      final root = await Directory(
        '${docs.path}/guided024-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final inputs = await Directory('${root.path}/inputs').create();
      // ignore: avoid_print
      print('ICD024_INPUT_READY:${inputs.path}');
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      final ready = File('${inputs.path}/ready.json');
      while (!await ready.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(await ready.exists(), isTrue);
      final expected =
          jsonDecode(await ready.readAsString()) as Map<String, dynamic>;
      final store = await PackageStore.open(
        Directory('${root.path}/state'),
        jsonDecode(await rootBundle.loadString('assets/schema_contract.json'))
            as Map<String, dynamic>,
      );
      final c = DeviceGuidanceController(store);
      try {
        final hash = await store.publish(
          await store.prepare(File('${inputs.path}/official.icdpack')),
        );
        // ignore: avoid_print
        print('ICD024_IMPORTED');
        expect(hash, expected['sha256']);
        final repo = DictionaryRepository(
          store.contentPath(hash),
          store.manifest(hash),
        );
        late Map<String, Object?> probe;
        try {
          probe = guidedProbe(repo);
          expect(probe, expected['snapshots']);
          // ignore: avoid_print
          print('ICD024_PROBE_MATCHED');
        } finally {
          repo.close();
        }
        await c.choose(hash);
        // ignore: avoid_print
        print('ICD024_ACTIVATED');
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Diabetes, diabetic',
        );
        await tester.runAsync(
          () => tester.testTextInput.receiveAction(TextInputAction.search),
        );
        await tester.runAsync(() => c.lastSearch!);
        await tester.pumpAndSettle();
        expect(c.resultTotal, 449);
        expect(c.results.length, 100);
        expect(c.results.first['target_code'], 'E11.9');
        expect(
          find.text('Diabetes, diabetic(mellitus) (sugar)'),
          findsOneWidget,
        );
        // ignore: avoid_print
        print('ICD024_RESULTS_VISIBLE:${inputs.path}');
        final capture = File('${inputs.path}/captured');
        final end = DateTime.now().add(const Duration(seconds: 40));
        while (!await capture.exists() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(await capture.exists(), isTrue);
        final scroller = find.descendant(
          of: find.byKey(const ValueKey('search-results')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('search-load-more')),
          300,
          scrollable: scroller,
          maxScrolls: 200,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('search-load-more'))),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.byKey(const ValueKey('search-load-more'))),
        );
        await tester.runAsync(() => c.lastMore!);
        await tester.pumpAndSettle();
        expect(c.results.length, 200);
        expect(c.results.map((r) => r['id']).toSet().length, 200);
        expect(c.hasMore, isTrue);
        expect(tester.takeException(), isNull);
        await File('${docs.path}/guided024-report.json').writeAsString(
          jsonEncode({
            'sha256': hash,
            'snapshots': probe,
            'loaded_ui_rows': 200,
            'ui_total': 449,
            'os': Platform.operatingSystemVersion,
          }),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
