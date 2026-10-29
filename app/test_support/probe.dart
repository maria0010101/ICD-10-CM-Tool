import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:icd_dictionary/data/repository.dart';

const probeQueries = <String>[
  'I50.9',
  'I509',
  ' i509 ',
  'i50.9',
  'Ｉ５０９',
  'I50',
  'I5',
  'heart failure',
  'failure heart',
  'heart',
  'failure',
  'hear',
  'fail',
  'heart OR failure',
  'heart " failure',
  'kidney',
  'acute kidney',
  'failure acute',
  'N17.9',
  'N179',
  ' n179 ',
  'N17',
  '腎衰竭',
  '心臟衰竭',
  '心臟',
  '衰竭',
  '心',
  '腎',
  '未確認跨版翻譯',
  'S00.0',
  'S000',
  'S00',
  'injury',
  'placeholder',
  'seventh',
  'Failure > heart',
  'SAMPLE',
  'substance',
  'neoplasm',
  'notpresentword',
  '',
  '  ',
  '*',
  '"',
  'OR',
  'heart failure unspecified',
  'acute failure unspecified',
  'S00-S09',
  'Failure unspecified',
  'initial encounter',
];
Map<String, Object?> queryProbe(DictionaryRepository repo, String hash) {
  final results = <Object?>[];
  for (final q in probeQueries) {
    final rows = repo
        .search(q)
        .map(
          (r) => {
            for (final key in [
              'id',
              'code',
              'code_normalized',
              'term_path',
              'billable',
              'state',
              'title_en',
              'title_zh_tw',
              'translation_status',
            ])
              if (r.containsKey(key)) key: r[key],
          },
        )
        .toList();
    results.add({'query': q, 'results': rows});
  }
  final target = repo.resolveTarget('I50.9');
  final notes = target.isEmpty
      ? []
      : repo.detail(target.first['id'] as int)['notes'];
  final snapshot = {
    'queries': results,
    'notes': notes,
    'index_crossrefs': repo.rows(
      'SELECT * FROM index_crossrefs ORDER BY id LIMIT 50',
    ),
    'table_cells': repo.rows('SELECT * FROM table_cells ORDER BY id LIMIT 50'),
    'row_counts': repo.manifest.counts,
  };
  return {
    'package_sha256': hash,
    'query_count': probeQueries.length,
    'sqlite_version': repo
        .rows('SELECT sqlite_version() AS version')
        .single['version'],
    'snapshot_sha256': sha256
        .convert(utf8.encode(jsonEncode(snapshot)))
        .toString(),
    'snapshot': snapshot,
  };
}

Map<String, Object?> benchmark(
  DictionaryRepository repo, {
  int iterations = 1000,
}) {
  final report = <String, Object?>{};
  final operations = <String, void Function()>{
    'code': () => repo.resolveTarget('I50.9'),
    'english': () => repo.search('heart failure', scope: 'tabular'),
    'chinese': () => repo.search('心臟衰竭', scope: 'tabular'),
    'tree': () => repo.children(null),
  };
  for (final entry in operations.entries) {
    for (var i = 0; i < 20; i++) {
      entry.value();
    }
    final times = <double>[];
    for (var i = 0; i < iterations; i++) {
      final clock = Stopwatch()..start();
      entry.value();
      times.add(clock.elapsedMicroseconds / 1000);
    }
    times.sort();
    report[entry.key] = {
      'iterations': iterations,
      'p50_ms': times[(iterations * .5).floor()],
      'p95_ms': times[(iterations * .95).floor()],
      'p99_ms': times[(iterations * .99).floor()],
    };
  }
  return report;
}
