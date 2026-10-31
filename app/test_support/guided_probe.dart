import 'package:icd_dictionary/data/repository.dart';

const guidanceQueries = [
  'Diabetes, diabetic',
  'diabetes diabetic',
  'diabetic diabetes',
  'diabetes kidney',
  'kidney diabetes',
  'diab neph',
  'betes',
  'diabetes type 1',
  'diabetes type 2',
];
Map<String, Object?> guidedProbe(DictionaryRepository repo) {
  final snapshots = <String, Object?>{};
  for (final q in guidanceQueries) {
    final page = repo.searchPage(q, scope: 'alphabetic', limit: 500);
    snapshots[q] = {
      'total': page.total,
      'rows': page.rows
          .map(
            (r) => {
              for (final k in [
                'id',
                'parent_id',
                'term_path',
                'target_code',
                'display_order',
                'index_depth',
                'context_only',
              ])
                k: r[k],
            },
          )
          .toList(),
    };
  }
  return snapshots;
}
