import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  for (final configuration in [
    (390.0, TargetPlatform.android),
    (800.0, TargetPlatform.android),
    (1440.0, TargetPlatform.windows),
    (650.0, TargetPlatform.windows),
  ]) {
    final (width, platform) = configuration;
    testWidgets('review navigation $width $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      late Directory root;
      late PackageStore store;
      late DictionaryController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('icd-review-');
        store = await PackageStore.open(
          root,
          jsonDecode(await File('assets/schema_contract.json').readAsString())
              as Map<String, dynamic>,
        );
        final hash = await store.publish(
          await store.prepare(
            File('../samples/sample-demo-v1.icdpack'),
            capacity: 1 << 40,
          ),
        );
        c = DictionaryController(store);
        await c.choose(hash);
      });
      try {
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        final phone = width < 720 && platform != TargetPlatform.windows;
        expect(
          find.byType(NavigationBar),
          phone ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(NavigationDestination),
          phone ? findsNWidgets(2) : findsNothing,
        );
        expect(find.widgetWithText(NavigationDestination, '資料'), findsNothing);
        // Both destinations must remain reachable in the integrated tablet pane
        // and in a narrow Windows window without restoring bottom navigation.
        if (width < 1180) {
          await tester.tap(find.text('分類'));
          await tester.pumpAndSettle();
          expect(find.text('分類樹 / 來源結構'), findsOneWidget);
          await tester.tap(find.text('搜尋'));
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
        }
        await tester.tap(find.byTooltip('資料管理'));
        await tester.pumpAndSettle();
        expect(find.text('本機資料管理'), findsOneWidget);
        await tester.tap(find.byTooltip('資料管理'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.runAsync(() async {
          store.close();
          await root.delete(recursive: true);
        });
      }
    });
  }

  for (final sample in [
    'sample-demo-v1',
    'sample-nhi-cm-v1',
    'sample-pcs-v1',
  ]) {
    testWidgets('notes dialog and optional translation: $sample', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      late Directory root;
      late PackageStore store;
      late DictionaryController c;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('icd-review-notes-');
        store = await PackageStore.open(
          root,
          jsonDecode(await File('assets/schema_contract.json').readAsString())
              as Map<String, dynamic>,
        );
        final hash = await store.publish(
          await store.prepare(
            File('../samples/$sample.icdpack'),
            capacity: 1 << 40,
          ),
        );
        c = DictionaryController(store);
        await c.choose(hash);
        // N17.9 and PCS deliberately have no verified translation.
        c.query = sample == 'sample-pcs-v1'
            ? '0016070'
            : sample == 'sample-demo-v1'
            ? 'N179'
            : 'I509';
        await c.search();
        await c.open(c.results.first);
      });
      try {
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        expect(find.textContaining('該版本無經驗證官方中譯'), findsNothing);
        if (sample == 'sample-nhi-cm-v1') {
          expect(find.textContaining('合成心臟衰竭未明示'), findsWidgets);
        }
        final button = find.widgetWithText(TextButton, '本層與繼承notes');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(button).dx,
          greaterThan(
            tester.getTopLeft(find.widgetWithText(TextButton, '個人註解')).dx,
          ),
        );
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.textContaining('繼承：'), findsNothing);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final expected = (c.detail!['notes'] as List)
            .where(
              (n) =>
                  n['note_type'] != 'pcs_table' &&
                  n['note_type'] != 'nhi_source_columns',
            )
            .toList();
        for (final note in expected) {
          final text = find.text(note['note_text'] as String);
          await tester.scrollUntilVisible(
            text,
            120,
            scrollable: find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(text, findsOneWidget);
          expect(find.text('來源：${note['source_reference']}'), findsWidgets);
        }
        if (sample == 'sample-pcs-v1') {
          expect(
            find.text('PCS 來源註記與 section 參考定義（非 CM 繼承規則）'),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('關閉'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.textContaining('繼承：'), findsNothing);
        expect(c.detail, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        await tester.runAsync(() async {
          store.close();
          await root.delete(recursive: true);
        });
      }
    });
  }
}
