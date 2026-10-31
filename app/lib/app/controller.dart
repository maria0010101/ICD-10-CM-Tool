import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../data/package_store.dart';
import '../data/repository.dart';

// Factories live outside widget State methods: Dart closures may capture the
// entire lexical context, including Element/RenderObject/Completer, when a UI
// callback and setState closures share a scope. Only scalar query data crosses.
List<DataRow> Function(DictionaryRepository) _childrenQuery(
  int? parent,
  String? indexType,
  int? limit,
  int offset,
) =>
    (r) => indexType == null
    ? r.children(parent, limit: limit, offset: offset)
    : r.indexChildren(parent, indexType, limit: limit, offset: offset);

List<DataRow> Function(DictionaryRepository) _targetQuery(String target) =>
    (r) => r.resolveTarget(target);

class DictionaryController extends ChangeNotifier {
  final PackageStore store;
  List<DataRow> results = [], roots = [];
  List<String> scopes = ['all', 'tabular'];
  DataRow? detail;
  String query = '', scope = 'all';
  String? lastError;
  bool any = false, prefix = true, searching = false;
  bool guided = true, loadingMore = false, hasMore = false;
  bool _suggestions = false;
  int? _indexBranch;
  int resultTotal = 0;
  String resultMode = 'relevance';
  int selected = 0;
  int _generation = 0;
  Timer? _timer;
  String classification;
  DictionaryController(this.store)
    : classification = store.active == null
          ? 'ICD-10-CM'
          : store.manifest(store.active!).classification;
  String? get active =>
      store.active != null &&
          store.manifest(store.active!).classification == classification
      ? store.active
      : null;
  Future<void> switchClassification(String value) async {
    classification = value;
    final saved = store.preference('active:$value');
    final candidates = store.installed.where((r) {
      final m = store.manifest(r['hash'] as String);
      return m.classification == value && !m.isOverlay;
    }).toList();
    if (candidates.isNotEmpty) {
      final hash = candidates.any((r) => r['hash'] == saved)
          ? saved!
          : candidates.last['hash'] as String;
      await store.activate(hash);
    }
    await refresh();
  }

  Future<T> read<T>(T Function(DictionaryRepository) operation) async {
    final hash = active;
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

  Future<List<DataRow>> loadChildren(
    int? parent, {
    String? indexType,
    int? limit,
    int offset = 0,
  }) => read(_childrenQuery(parent, indexType, limit, offset));

  Future<List<DataRow>> resolveTarget(String target) =>
      read(_targetQuery(target));

  Future<void> refresh() async {
    _generation++;
    detail = null;
    results = [];
    resultTotal = 0;
    resultMode = 'relevance';
    roots = [];
    scopes = ['all', 'tabular'];
    lastError = null;
    searching = false;
    loadingMore = false;
    hasMore = false;
    _indexBranch = null;
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
    _indexBranch = null;
    _suggestions = true;
    _generation++;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), search);
  }

  Future<void> search({bool submitted = false, bool keepBranch = false}) async {
    _timer?.cancel();
    if (submitted) _suggestions = false;
    if (!keepBranch) _indexBranch = null;
    if (active == null) {
      return;
    }
    final generation = ++_generation;
    final input = query, source = scope, or = any, pre = prefix;
    final guide = guided, suggest = _suggestions, branch = _indexBranch;
    loadingMore = false;
    hasMore = false;
    searching = true;
    lastError = null;
    notifyListeners();
    try {
      final found = await read(
        (r) => r.searchPage(
          input,
          scope: source,
          guided: guide,
          suggestions: suggest,
          branch: branch,
          any: or,
          prefix: pre,
        ),
      );
      if (generation != _generation) {
        return;
      }
      results = found.rows;
      resultTotal = found.total;
      resultMode = found.mode;
      hasMore = found.hasMore;
      selected = 0;
    } catch (e) {
      if (generation == _generation) {
        lastError = '$e';
        results = [];
        resultTotal = 0;
      }
    } finally {
      if (generation == _generation) {
        searching = false;
        notifyListeners();
      }
    }
  }

  Future<void> browseIndex(DataRow row) async {
    _timer?.cancel();
    _suggestions = false;
    _indexBranch = row['id'] as int;
    query = row['main_term'] as String;
    await search(keepBranch: true);
  }

  Future<void> loadMore() async {
    if (!hasMore || loadingMore || searching) return;
    final generation = _generation;
    final input = query, source = scope, or = any, pre = prefix;
    final guide = guided, suggest = _suggestions, branch = _indexBranch;
    final offset = results.length;
    loadingMore = true;
    lastError = null;
    notifyListeners();
    try {
      final page = await read(
        (r) => r.searchPage(
          input,
          scope: source,
          guided: guide,
          suggestions: suggest,
          branch: branch,
          any: or,
          prefix: pre,
          offset: offset,
        ),
      );
      if (generation != _generation) return;
      results = [...results, ...page.rows];
      resultTotal = page.total;
      hasMore = page.hasMore;
    } catch (e) {
      if (generation == _generation) lastError = '$e';
    } finally {
      if (generation == _generation) {
        loadingMore = false;
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
    classification = store.manifest(hash).classification;
    await refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
