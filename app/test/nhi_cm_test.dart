import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  test(
    'NHI CM standalone: independent activation, FTS, Chinese and lineage',
    () async {
      final root = await Directory.systemTemp.createTemp('nhi-cm-native-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      final c = DictionaryController(store);
      try {
        final hash = await store.publish(
          await store.prepare(
            File('../samples/sample-nhi-cm-v1.icdpack'),
            capacity: 1 << 40,
          ),
        );
        await c.choose(hash);
        expect(c.active, hash);
        expect(store.manifest(hash).isOverlay, false);
        final package = store.manifest(hash).id;
        store.favorite(package, 'I50.9', true);
        store.saveNote(package, 'I50.9', 'SAMPLE isolated note');
        final snapshots = <Map<String, Object?>>[];
        for (var i = 0; i < 50; i++) {
          final query = ['I50.9', 'I509', 'failure', '心臟', '衰竭'][i % 5];
          c.query = query;
          await c.search();
          expect(c.results, isNotEmpty);
          expect(
            c.results.every((r) => r['translation_status'] == 'exact_edition'),
            true,
          );
          snapshots.add({
            'query': query,
            'results': c.results
                .map(
                  (r) => {
                    'code': r['code'],
                    'title_en': r['title_en'],
                    'title_zh_tw': r['title_zh_tw'],
                    'state': r['state'],
                  },
                )
                .toList(),
          });
        }
        final roots = await c.loadChildren(null);
        expect(await c.loadChildren(null, limit: 1, offset: 1), isEmpty);
        final categories = await c.loadChildren(roots.single['id'] as int);
        final leaves = await c.loadChildren(categories.single['id'] as int);
        expect(leaves.single['code'], 'I50.9');
        final overlay = await store.publish(
          await store.prepare(
            File('../samples/sample-overlay-unresolved.icdpack'),
            capacity: 1 << 40,
          ),
        );
        await expectLater(
          c.choose(overlay, translation: true),
          throwsException,
        );
        expect(c.active, hash);
        expect(store.overlay, isNull);
        expect(
          store.user.select('SELECT count(*) n FROM favorites').single['n'],
          1,
        );
        expect(
          store.user.select('SELECT note FROM personal_notes').single['note'],
          'SAMPLE isolated note',
        );
        await File('../evidence/nhi-cm-native.json').writeAsString(
          jsonEncode({
            'sha256': hash,
            'classification': 'ICD-10-CM',
            'source_edition_only': true,
            'snapshots': snapshots,
            'os': Platform.operatingSystemVersion,
          }),
        );
      } finally {
        c.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets('overlay is labelled and cannot activate without a base', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp('overlay-ui-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      final c = DictionaryController(store);
      try {
        await store.publish(
          await store.prepare(
            File('../samples/sample-overlay-unresolved.icdpack'),
            capacity: 1 << 40,
          ),
        );
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('資料管理'));
        await tester.pumpAndSettle();
        final button = find.byTooltip('附加中譯不可獨立啟用：先選相容主版本');
        expect(button, findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '附加中譯不可獨立啟用：先選相容主版本',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(find.textContaining('附加中譯包：沒有獨立代碼主表'), findsOneWidget);
        expect(store.active, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    });
  });
}
