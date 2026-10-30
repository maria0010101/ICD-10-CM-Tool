import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icd_dictionary/app/controller.dart';
import 'package:icd_dictionary/data/package_store.dart';
import 'package:icd_dictionary/ui/dictionary_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'classification reviewer phone UI with unchanged sample package',
    (tester) async {
      final docs = await getApplicationSupportDirectory();
      final root = await Directory(
        '${docs.path}/review022-${DateTime.now().microsecondsSinceEpoch}',
      ).create();
      final input = await File('${root.path}/sample.icdpack')
          .writeAsBytes(base64Decode(const String.fromEnvironment('PACK1')));
      final store = await PackageStore.open(
        Directory('${root.path}/state'),
        jsonDecode(await rootBundle.loadString('assets/schema_contract.json'))
            as Map<String, dynamic>,
      );
      final c = DictionaryController(store);
      try {
        final hash = await store.publish(await store.prepare(input));
        await c.choose(hash);
        c.query = 'N179';
        await c.search();
        await tester.pumpWidget(DictionaryApp(controller: c));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(2));
        expect(find.widgetWithText(NavigationDestination, '資料'), findsNothing);
        expect(find.textContaining('該版本無經驗證官方中譯'), findsNothing);
        await tester.tap(find.text('N17.9  Acute kidney failure, unspecified'));
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (find.text('代碼 / Index 詳情').evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();
        expect(find.text('代碼 / Index 詳情'), findsOneWidget);
        expect(find.textContaining('該版本無經驗證官方中譯'), findsNothing);
        final button = find.widgetWithText(TextButton, '本層與繼承notes');
        await tester.scrollUntilVisible(button, 160);
        await tester.pumpAndSettle();
        expect(find.text('SAMPLE chapter note'), findsNothing);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('SAMPLE chapter note'), findsOneWidget);
        expect(find.textContaining('繼承：'), findsWidgets);
        final captured = File('${docs.path}/review022-captured');
        if (await captured.exists()) await captured.delete();
        // Host captures the real device, then acknowledges. No production data.
        // ignore: avoid_print
        print('ICD022_NOTES_VISIBLE:${docs.path}');
        final captureDeadline = DateTime.now().add(const Duration(seconds: 20));
        while (!await captured.exists() &&
            DateTime.now().isBefore(captureDeadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(await captured.exists(), true);
        await tester.tap(find.text('關閉'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('資料管理'));
        await tester.pumpAndSettle();
        expect(find.text('本機資料管理'), findsOneWidget);
        await tester.tap(find.byTooltip('資料管理'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
        await File('${docs.path}/review022-report.json').writeAsString(
          jsonEncode({
            'version': '0.2.2',
            'os': Platform.operatingSystemVersion,
            'sha256': hash,
            'two_mobile_destinations': true,
            'missing_translation_row_hidden': true,
            'notes_dialog_open_close': true,
            'inherited_note_visible': true,
            'management_roundtrip': true,
            'production_package_untouched': true,
          }),
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        c.dispose();
        store.close();
        await root.delete(recursive: true);
      }
    },
  );
}
