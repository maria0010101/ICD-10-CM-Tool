import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/controller.dart';
import 'data/package_store.dart';
import 'ui/dictionary_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final root = Platform.isWindows
        ? Directory(
            p.join(p.dirname(Platform.resolvedExecutable), 'portable-data'),
          )
        : Directory(
            p.join((await getApplicationSupportDirectory()).path, 'dictionary'),
          );
    final schema = jsonDecode(
      await rootBundle.loadString('assets/schema_contract.json'),
    ) as Map<String, dynamic>;
    final store = await PackageStore.open(root, schema);
    final controller = DictionaryController(store);
    await controller.refresh();
    runApp(DictionaryApp(controller: controller));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText(
              '無法開啟離線資料目錄：$e\nWindows 請將 portable ZIP 解壓至可寫入的資料夾。原始資料不會清除。',
            ),
          ),
        ),
      ),
    );
  }
}
