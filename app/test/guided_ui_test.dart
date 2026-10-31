import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

class RecordingGuidedController extends DictionaryController {
  RecordingGuidedController(super.store);
  Future<void>? lastSearch, lastMore, lastBrowse;
  @override
  Future<void> search({bool submitted = false, bool keepBranch = false}) =>
      lastSearch = super.search(submitted: submitted, keepBranch: keepBranch);
  @override
  Future<void> loadMore() => lastMore = super.loadMore();
  @override
  Future<void> browseIndex(DataRow row) => lastBrowse = super.browseIndex(row);
}

void main() {
  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('guided list and real paginated SQLite UI at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      late Directory root;
      late PackageStore store;
      late RecordingGuidedController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('guided-ui-');
        store = await PackageStore.open(
          root,
          jsonDecode(await File('assets/schema_contract.json').readAsString())
              as Map<String, dynamic>,
        );
        final hash = await store.publish(
          await store.prepare(
            File('../samples/sample-index-guidance-v1.icdpack'),
            capacity: 1 << 40,
          ),
        );
        c = RecordingGuidedController(store);
        await c.choose(hash);
      });
      try {
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Diabetes, diabetic',
        );
        // ignore: avoid_print
        print('GUIDED_UI submit start');
        await tester.runAsync(
          () => tester.testTextInput.receiveAction(TextInputAction.search),
        );
        // ignore: avoid_print
        print('GUIDED_UI submit returned');
        await tester.runAsync(() => c.lastSearch!);
        // ignore: avoid_print
        print('GUIDED_UI search done');
        await tester.pumpAndSettle();
        expect(c.results.first['target_code'], 'E11.9');
        expect(c.resultTotal, 120);
        expect(find.text('Diabetes, diabetic (SAMPLE)'), findsOneWidget);
        expect(find.textContaining('已載入 100／120'), findsOneWidget);
        final scroller = find.descendant(
          of: find.byKey(const ValueKey('search-results')),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scroller).position;
        try {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('search-load-more')),
            300,
            scrollable: scroller,
            maxScrolls: 200,
          );
        } catch (e) {
          // ignore: avoid_print
          print(
            'GUIDED_UI failed scroll: pixels=${position.pixels} max=${position.maxScrollExtent} viewport=${position.viewportDimension} count=${c.results.length} more=${c.hasMore}',
          );
          rethrow;
        }
        // ignore: avoid_print
        print('GUIDED_UI scroll done');
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('search-load-more'))),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => tester.tap(find.byKey(const ValueKey('search-load-more'))),
        );
        // ignore: avoid_print
        print('GUIDED_UI more tapped');
        await tester.runAsync(() => c.lastMore!);
        // ignore: avoid_print
        print('GUIDED_UI more done');
        await tester.pumpAndSettle();
        expect(c.results.length, 120);
        expect(c.hasMore, isFalse);
        expect(find.textContaining('已載入 120／120'), findsOneWidget);
        // A prefix suggestion must open the source branch, not a Tabular result.
        await tester.enterText(find.byType(TextField).first, 'diab');
        await tester.runAsync(() => c.search());
        await tester.pumpAndSettle();
        expect(c.resultMode, 'index-suggestions');
        await tester.runAsync(
          () => tester.tap(find.text('Diabetes, diabetic (SAMPLE)')),
        );
        await tester.runAsync(() => c.lastBrowse!);
        // ignore: avoid_print
        print('GUIDED_UI browse done');
        await tester.pumpAndSettle();
        expect(c.resultMode, 'index-context');
        expect(c.resultTotal, 120);
        expect(c.results.first['target_code'], 'E11.9');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.runAsync(() async {
          store.close();
          await root.delete(recursive: true);
        });
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }
    });
  }
}
