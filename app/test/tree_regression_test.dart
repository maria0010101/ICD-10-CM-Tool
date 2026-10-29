import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

class TrackingController extends DictionaryController {
  TrackingController(super.store);
  Future<void>? pending;
  Object? readError;
  @override
  Future<T> read<T>(T Function(DictionaryRepository) operation) {
    final future = super.read(operation);
    pending = future.then<void>(
      (_) {},
      onError: (Object e) {
        readError = e;
      },
    );
    return future;
  }
}

void main() {
  testWidgets('native hierarchy and Index expand inside narrow desktop pane', (
    tester,
  ) async {
    await tester.runAsync(() async {
      late Directory root;
      late PackageStore store;
      late TrackingController controller;
      {
        root = await Directory.systemTemp.createTemp('tree-native-');
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
        controller = TrackingController(store);
        await controller.choose(hash);
      }
      final capture = GlobalKey();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 260,
                  child: RepaintBoundary(
                    key: capture,
                    child: ListView(
                      children: [
                        HierarchyTile(
                          row: controller.roots.first,
                          controller: controller,
                          onOpen: controller.open,
                        ),
                        IndexRoots(
                          controller: controller,
                          type: 'alphabetic',
                          onOpen: controller.open,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await controller.pending;
        await tester.pumpAndSettle();
        expect(controller.readError, isNull);
        final first = find.byType(ExpansionTile).first;
        await tester.tap(
          find.descendant(of: first, matching: find.byType(Text)).first,
        );
        await controller.pending;
        await tester.pumpAndSettle();
        expect(controller.readError, isNull);
        expect(tester.takeException(), isNull);
        expect(find.byType(HierarchyTile).evaluate().length, greaterThan(2));
        await tester.ensureVisible(find.text('Failure'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Failure'));
        await controller.pending;
        await tester.pumpAndSettle();
        expect(find.text('heart'), findsOneWidget);
        await tester.ensureVisible(find.text('heart'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('heart'));
        await controller.pending;
        await tester.pumpAndSettle();
        expect(find.text('unspecified'), findsOneWidget);
        expect(controller.readError, isNull);
        expect(tester.takeException(), isNull);
        final image =
            await (capture.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('../evidence/tree-expanded.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        await controller.pending;
        controller.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    });
  });
}
