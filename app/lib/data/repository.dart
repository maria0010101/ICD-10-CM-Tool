import 'dart:isolate';
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import '../domain/manifest.dart';

String normalizeCode(String s) =>
    unicode.nfkc(s).trim().toUpperCase().replaceAll('.', '');
String normalizeText(String s) => unicode.nfkc(s).trim().toLowerCase();
Set<String> ngrams(String s) {
  final chars = normalizeText(s).runes.map(String.fromCharCode).toList();
  return {
    ...chars,
    for (var i = 0; i < chars.length - 1; i++) chars[i] + chars[i + 1],
  };
}

String? ftsExpression(String input, {bool any = false, bool prefix = true}) {
  final tokens = RegExp(r'[\p{L}\p{N}]+', unicode: true)
      .allMatches(normalizeText(input))
      .take(20)
      .map((m) => '"${m[0]}"${prefix ? '*' : ''}')
      .toList();
  return tokens.isEmpty ? null : tokens.join(any ? ' OR ' : ' AND ');
}

typedef DataRow = Map<String, Object?>;

class DictionaryRepository {
  final Database db;
  final PackManifest manifest;
  final Database? overlay;
  final PackManifest? overlayManifest;
  DictionaryRepository(
    String path,
    this.manifest, {
    String? overlayPath,
    this.overlayManifest,
  }) : db = sqlite3.open(path, mode: OpenMode.readOnly),
       overlay = overlayPath == null
           ? null
           : sqlite3.open(overlayPath, mode: OpenMode.readOnly) {
    for (final d in [db, overlay]) {
      d?.execute('PRAGMA trusted_schema=OFF');
      d?.execute('PRAGMA query_only=ON');
    }
    if (overlayManifest != null &&
        (!overlayManifest!.bases.contains(manifest.id) ||
            overlayManifest!.classification != manifest.classification)) {
      close();
      throw PackException('中譯包不相容目前英文版本');
    }
  }
  void close() {
    db.close();
    overlay?.close();
  }

  List<DataRow> rows(String sql, [List<Object?> params = const []]) =>
      db.select(sql, params).map((r) => Map<String, Object?>.from(r)).toList();
  Database get translationDb => overlay ?? db;
  List<DataRow> translations(String code, {bool includeUnresolved = false}) {
    return translationDb
        .select(
          'SELECT * FROM translations WHERE code_normalized=? ORDER BY id',
          [code],
        )
        .where(
          (r) =>
              includeUnresolved ||
              (r['base_package_id'] == manifest.id &&
                  [
                    'exact_edition',
                    'reviewed_cross_release',
                  ].contains(r['mapping_status'])),
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  List<DataRow> search(
    String input, {
    String scope = 'all',
    bool any = false,
    bool prefix = true,
    int limit = 100,
  }) {
    if (input.runes.length > 200) {
      throw PackException('查詢最多 200 字');
    }
    input = input.trim();
    if (input.isEmpty) {
      return rows(
        "SELECT * FROM code_nodes WHERE code!='' ORDER BY sort_order,id LIMIT ?",
        [limit],
      );
    }
    final expression = ftsExpression(input, any: any, prefix: prefix);
    final result = <DataRow>[];
    if (scope == 'all' || scope == 'tabular') {
      final exact = rows('SELECT * FROM code_nodes WHERE code_normalized=?', [
        normalizeCode(input),
      ]);
      result.addAll(exact);
      if (RegExp(r'[\u3400-\u9fff]').hasMatch(input)) {
        final gs = ngrams(input).toList();
        final ids = translationDb.select(
          'SELECT t.code_normalized FROM zh_ngrams g JOIN translations t ON t.id=g.source_translation_id WHERE g.ngram IN (${List.filled(gs.length, '?').join(',')}) AND t.base_package_id=? AND t.mapping_status IN (\'exact_edition\',\'reviewed_cross_release\') GROUP BY t.id HAVING count(DISTINCT g.ngram)=? ORDER BY t.id LIMIT ?',
          [...gs, manifest.id, gs.length, limit],
        );
        for (final id in ids) {
          final code = id['code_normalized'] as String;
          if (translations(code).any(
            (t) => (t['search_normalized'] as String).contains(
              normalizeText(input),
            ),
          )) {
            result.addAll(
              rows('SELECT * FROM code_nodes WHERE code_normalized=?', [code]),
            );
          }
        }
      } else if (expression != null) {
        result.addAll(
          rows(
            'SELECT n.* FROM code_search_fts f JOIN code_nodes n ON n.id=f.rowid WHERE code_search_fts MATCH ? ORDER BY bm25(code_search_fts),n.sort_order,n.id LIMIT ?',
            [expression, limit],
          ),
        );
      }
    }
    if (scope != 'tabular' && expression != null) {
      result.addAll(
        rows(
          'SELECT e.* FROM index_search_fts f JOIN index_entries e ON e.id=f.rowid WHERE index_search_fts MATCH ? ${scope == 'all' ? '' : 'AND e.entry_type=?'} ORDER BY bm25(index_search_fts),e.display_order,e.id LIMIT ?',
          [expression, if (scope != 'all') scope, limit],
        ),
      );
    }
    final seen = <String>{};
    return result
        .where(
          (r) =>
              seen.add('${r.containsKey('node_key') ? 'c' : 'i'}:${r['id']}'),
        )
        .take(limit)
        .map((r) {
          if (!r.containsKey('node_key')) {
            return r;
          }
          final zh = translations(r['code_normalized'] as String);
          return {
            ...r,
            'title_zh_tw': zh.isEmpty ? null : zh.first['title_zh_tw'],
            'translation_status': zh.isEmpty
                ? null
                : zh.first['mapping_status'],
          };
        })
        .toList();
  }

  List<DataRow> children(int? parent) => rows(
    'SELECT * FROM code_nodes WHERE parent_id IS ? ORDER BY sort_order,id',
    [parent],
  );
  List<DataRow> indexChildren(
    int? parent,
    String type, {
    int? limit,
    int offset = 0,
  }) => rows(
    'SELECT * FROM index_entries WHERE parent_id IS ? AND entry_type=? ORDER BY display_order,id LIMIT ? OFFSET ?',
    [parent, type, limit ?? -1, offset],
  );
  List<String> availableScopes() => [
    'all',
    'tabular',
    ...rows('SELECT DISTINCT entry_type FROM index_entries ORDER BY entry_type')
        .map((r) => r['entry_type'] as String),
  ];
  DataRow detail(int id) {
    final node = rows('SELECT * FROM code_nodes WHERE id=?', [id]).single;
    final ancestors = rows(
      'WITH RECURSIVE a(id,parent_id,code,title_en,depth) AS (SELECT id,parent_id,code,title_en,0 FROM code_nodes WHERE id=? UNION ALL SELECT n.id,n.parent_id,n.code,n.title_en,a.depth+1 FROM code_nodes n JOIN a ON n.id=a.parent_id WHERE a.depth<100) SELECT * FROM a ORDER BY depth DESC',
      [id],
    );
    final notes = <DataRow>[];
    for (final a in ancestors) {
      notes.addAll(
        rows(
          'SELECT * FROM notes WHERE owner_node_id=? ORDER BY display_order,id',
          [a['id']],
        ).map(
          (n) => {
            ...n,
            'owner_code': a['code'],
            'owner_title': a['title_en'],
            'inherited': a['id'] != id,
          },
        ),
      );
    }
    final code = node['code_normalized'] as String;
    return {
      ...node,
      'ancestors': ancestors,
      'notes': notes,
      'translations': translations(code),
      'references': translations(code, includeUnresolved: true),
      'children': children(id),
      if (manifest.isPcs) ...pcsAxes(notes, node['code'] as String),
      'related_index': rows(
        "SELECT * FROM index_entries WHERE replace(upper(target_code),'.','')=? ORDER BY display_order LIMIT 100",
        [code],
      ),
    };
  }

  DataRow indexDetail(int id) {
    final node = rows('SELECT * FROM index_entries WHERE id=?', [id]).single;
    final target = node['target_code'] as String?;
    return {
      ...node,
      'crossrefs': rows(
        'SELECT * FROM index_crossrefs WHERE index_entry_id=? ORDER BY display_order,id',
        [id],
      ),
      'cells': rows(
        'SELECT * FROM table_cells WHERE index_entry_id=? ORDER BY display_order,id',
        [id],
      ),
      'children': rows(
        'SELECT * FROM index_entries WHERE parent_id=? ORDER BY display_order,id',
        [id],
      ),
      'target_nodes': target == null ? <DataRow>[] : resolveTarget(target),
      'pcs_prefix_candidates':
          manifest.isPcs &&
              target != null &&
              RegExp(r'^[0-9A-HJ-NP-Z]{3,6}$').hasMatch(normalizeCode(target))
          ? rows(
              "SELECT * FROM code_nodes WHERE billable=1 AND code_normalized GLOB ? ORDER BY code_normalized LIMIT 100",
              ['${normalizeCode(target)}*'],
            )
          : <DataRow>[],
    };
  }

  List<DataRow> resolveTarget(String target) {
    // Exact targets are exact. Ranges/incomplete suffixes NEVER silently resolve.
    final key = normalizeCode(target);
    if (!(manifest.isPcs
            ? RegExp(r'^(?:[0-9A-HJ-NP-Z]{3}|[0-9A-HJ-NP-Z]{7})$')
            : RegExp(r'^[A-Z][A-Z0-9]{2,6}$'))
        .hasMatch(key)) {
      return [];
    }
    return rows('SELECT * FROM code_nodes WHERE code_normalized=?', [key]);
  }

  List<DataRow> compare(DictionaryRepository other) =>
      rows("SELECT * FROM code_nodes WHERE code!='' ORDER BY code_normalized")
          .expand((r) {
            final candidate = other.rows(
              'SELECT * FROM code_nodes WHERE code_normalized=?',
              [r['code_normalized']],
            );
            final right = candidate.isEmpty ? null : candidate.first;
            if (right == null) {
              return [
                {...r, 'change': 'removed'},
              ];
            }
            final oldNotes = rows(
              'SELECT note_type,note_text FROM notes WHERE owner_node_id=? ORDER BY display_order,id',
              [r['id']],
            );
            final newNotes = other.rows(
              'SELECT note_type,note_text FROM notes WHERE owner_node_id=? ORDER BY display_order,id',
              [right['id']],
            );
            return r['title_en'] != right['title_en'] ||
                    r['state'] != right['state'] ||
                    oldNotes.toString() != newNotes.toString()
                ? [
                    {...r, 'change': 'changed', 'new_title': right['title_en']},
                  ]
                : <DataRow>[];
          })
          .followedBy(
            other
                .rows(
                  "SELECT * FROM code_nodes WHERE code!='' ORDER BY code_normalized",
                )
                .where(
                  (r) => rows(
                    'SELECT id FROM code_nodes WHERE code_normalized=?',
                    [r['code_normalized']],
                  ).isEmpty,
                )
                .map((r) => {...r, 'change': 'added'}),
          )
          .toList();
}

Map<String, Object?> pcsAxes(List<DataRow> notes, String code) {
  final axes = <Map<String, Object?>>[];
  final rows = <Map<String, Object?>>[];
  for (final note in notes.where((n) => n['note_type'] == 'pcs_table')) {
    final raw = note['note_text'] as String;
    if (raw.length > 1024 * 1024) {
      throw PackException('PCS table metadata 超出限制');
    }
    final table = jsonDecode(raw) as Map<String, dynamic>;
    if (table['prefix'] !=
        code.substring(0, code.length < 3 ? code.length : 3)) {
      continue;
    }
    final shared = table['axes'] as List;
    for (final sourceRow in table['rows'] as List) {
      final rowAxes = sourceRow['axes'] as List;
      final matches =
          code.length == 7 &&
          rowAxes.every(
            (a) => (a['labels'] as List).any(
              (l) => l['code'] == code[(a['position'] as int) - 1],
            ),
          );
      if (code.length == 7 && !matches) continue;
      rows.add({
        'order': sourceRow['order'],
        'axes': rowAxes,
        'source_reference': note['source_reference'],
      });
      if (matches) {
        for (final a in [...shared, ...rowAxes]) {
          final label = (a['labels'] as List).firstWhere(
            (l) => l['code'] == code[(a['position'] as int) - 1],
          );
          axes.add({
            'position': a['position'],
            'title': a['title'],
            'definition': a['definition'],
            ...Map<String, Object?>.from(label),
          });
        }
      }
    }
  }
  return {'pcs_axes': axes, 'pcs_rows': rows};
}

Future<List<DataRow>> computeDiff(
  String left,
  PackManifest lm,
  String right,
  PackManifest rm,
) => Isolate.run(() {
  if (lm.classification != rm.classification) {
    throw PackException('CM 與 PCS 是不同分類，不能直接作版間比較');
  }
  final a = DictionaryRepository(left, lm), b = DictionaryRepository(right, rm);
  try {
    return a.compare(b);
  } finally {
    a.close();
    b.close();
  }
});
