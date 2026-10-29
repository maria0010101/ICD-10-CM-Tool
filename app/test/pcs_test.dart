import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter_test/flutter_test.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/data/repository.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  test(
    'PCS shared package: code, FTS, seven axes, Index and family isolation',
    () async {
      final root = await Directory.systemTemp.createTemp('pcs-native-');
      final store = await PackageStore.open(
        root,
        jsonDecode(await File('assets/schema_contract.json').readAsString())
            as Map<String, dynamic>,
      );
      try {
        final cm = await store.publish(
          await store.prepare(
            File('../samples/sample-demo-v1.icdpack'),
            capacity: 1 << 40,
          ),
        );
        final pcs = await store.publish(
          await store.prepare(
            File('../samples/sample-pcs-v1.icdpack'),
            capacity: 1 << 40,
          ),
        );
        final controller = DictionaryController(store);
        await controller.choose(pcs);
        final repo = DictionaryRepository(
          store.contentPath(pcs),
          store.manifest(pcs),
        );
        try {
          expect(repo.search('0016070').first['billable'], 1);
          expect(repo.search('Bypass'), isNotEmpty);
          expect(repo.search('001').first['billable'], 0);
          final detail = repo.detail(repo.search('0016070').first['id'] as int);
          expect((detail['pcs_axes'] as List).length, 7);
          expect((detail['pcs_rows'] as List).length, 1);
          final main = repo.indexChildren(null, 'alphabetic').first;
          expect(repo.indexDetail(main['id'] as int)['target_code'], '001');
          expect(
            (repo.indexDetail(main['id'] as int)['pcs_prefix_candidates']
                    as List)
                .length,
            2,
          );
          expect(repo.resolveTarget('0016070'), isNotEmpty);
          expect(repo.resolveTarget('0UT9'), isEmpty);
        } finally {
          repo.close();
        }
        await controller.switchClassification('ICD-10-CM');
        expect(controller.active, cm);
        await controller.switchClassification('ICD-10-PCS');
        expect(controller.active, pcs);
        final payload = {
          'package_sha256': pcs,
          'sqlite': store.user
              .select('select sqlite_version() as v')
              .single['v'],
          'classification': 'ICD-10-PCS',
          'seven_axes': true,
          'index_target_not_inherited_from_subterm': true,
          'os': Platform.operatingSystemVersion,
        };
        await Directory('../evidence').create(recursive: true);
        await File('../evidence/pcs-native.json')
            .writeAsString(jsonEncode(payload));
        controller.dispose();
      } finally {
        store.close();
        await root.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'PCS selector remains available when that family has no package',
    (tester) async {
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp('pcs-ui-');
        final store = await PackageStore.open(
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
        final controller = DictionaryController(store);
        await controller.choose(hash);
        await tester.pumpWidget(DictionaryApp(controller: controller));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PCS 處置'));
        await tester.pumpAndSettle();
        expect(find.text('CM 診斷'), findsOneWidget);
        expect(controller.active, isNull);
        await tester.tap(find.text('CM 診斷'));
        await tester.pumpAndSettle();
        expect(controller.classification, 'ICD-10-CM');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        store.close();
        await root.delete(recursive: true);
      });
    },
  );
}
