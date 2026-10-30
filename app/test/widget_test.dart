import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  test('adaptive breakpoints', () {
    expect(paneCount(390), 1);
    expect(paneCount(800), 2);
    expect(paneCount(1440), 3);
  });
  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('empty import flow ${width}px and text scaling', (
      tester,
    ) async {
      late Directory root;
      late PackageStore store;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('icd-widget-');
        store = await PackageStore.open(
          root,
          jsonDecode(await File('assets/schema_contract.json').readAsString())
              as Map<String, dynamic>,
        );
      });
      final controller = DictionaryController(store);
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(DictionaryApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('匯入 .icdpack'), findsOneWidget);
      expect(find.textContaining('完全離線'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('明暗模式'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        store.close();
        await root.delete(recursive: true);
      });
    });
  }
  for (final width in [390.0, 800.0, 1440.0]) {
    testWidgets('populated search/detail ${width}px at 1.6x text scale', (
      tester,
    ) async {
      late Directory root;
      late PackageStore store;
      late DictionaryController controller;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('icd-populated-');
        store = await PackageStore.open(
          root,
          jsonDecode(await File('assets/schema_contract.json').readAsString())
              as Map<String, dynamic>,
        );
        final prepared = await store.prepare(
          File('../samples/sample-demo-v1.icdpack'),
          capacity: 1 << 40,
        );
        final hash = await store.publish(prepared);
        await store.activate(hash);
        controller = DictionaryController(store);
        await controller.refresh();
      });
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(DictionaryApp(controller: controller));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('SAMPLE / NOT FOR CLINICAL CODING'),
        findsOneWidget,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        true,
      );
      await tester.runAsync(() async {
        controller.query = 'I509';
        await controller.search();
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() => controller.open(controller.results.first));
      await tester.pumpAndSettle();
      if (width >= 720) {
        await tester.scrollUntilVisible(
          find.text('本層與繼承notes'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('本層與繼承notes'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() async {
        store.close();
        await root.delete(recursive: true);
      });
    });
  }
}
