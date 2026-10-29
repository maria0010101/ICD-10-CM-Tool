import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../data/package_store.dart';
import '../data/repository.dart';

class DictionaryController extends ChangeNotifier {
  final PackageStore store;
  List<DataRow> results = [], roots = [];
  List<String> scopes = ['all', 'tabular'];
  DataRow? detail;
  String query = '', scope = 'all';
  String? lastError;
  bool any = false, prefix = true, searching = false;
  int selected = 0;
  int _generation = 0;
  Timer? _timer;
  DictionaryController(this.store);
  String? get active => store.active;
  Future<T> read<T>(T Function(DictionaryRepository) operation) async {
    final hash = store.active;
    if (hash == null) {
      throw StateError('請先匯入資料包');
    }
    final path = store.contentPath(hash), m = store.manifest(hash);
    final overlay = store.overlay;
    final overlayPath = overlay == null ? null : store.contentPath(overlay);
    final overlayManifest = overlay == null ? null : store.manifest(overlay);
    return Isolate.run(() {
      final repository = DictionaryRepository(
        path,
        m,
        overlayPath: overlayPath,
        overlayManifest: overlayManifest,
      );
      try {
        return operation(repository);
      } finally {
        repository.close();
      }
    });
  }

  Future<void> refresh() async {
    _generation++;
    detail = null;
    results = [];
    if (active != null) {
      final data = await read((r) => (r.children(null), r.availableScopes()));
      roots = data.$1;
      scopes = data.$2;
      if (!scopes.contains(scope)) {
        scope = 'all';
      }
      await search();
    }
    notifyListeners();
  }

  void queueSearch(String value) {
    query = value;
    _generation++;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), search);
  }

  Future<void> search() async {
    if (active == null) {
      return;
    }
    final generation = ++_generation;
    final input = query, source = scope, or = any, pre = prefix;
    searching = true;
    lastError = null;
    notifyListeners();
    try {
      final found = await read(
        (r) => r.search(input, scope: source, any: or, prefix: pre),
      );
      if (generation != _generation) {
        return;
      }
      results = found;
      selected = 0;
    } catch (e) {
      if (generation == _generation) {
        lastError = '$e';
        results = [];
      }
    } finally {
      if (generation == _generation) {
        searching = false;
        notifyListeners();
      }
    }
  }

  Future<void> open(DataRow row) async {
    final generation = _generation;
    final id = row['id'] as int, code = row.containsKey('node_key');
    final found = await read((r) => code ? r.detail(id) : r.indexDetail(id));
    if (generation == _generation) {
      detail = found;
      notifyListeners();
    }
  }

  Future<void> choose(String hash, {bool translation = false}) async {
    _generation++;
    await store.activate(hash, translation: translation);
    await refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
