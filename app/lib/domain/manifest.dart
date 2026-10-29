import 'dart:convert';

const contentTables = [
  'code_nodes',
  'notes',
  'index_entries',
  'index_crossrefs',
  'table_cells',
  'translations',
  'zh_ngrams',
];

class PackException implements Exception {
  final String message;
  PackException(this.message);
  @override
  String toString() => message;
}

class PackManifest {
  final Map<String, dynamic> json;
  PackManifest._(this.json);
  String get id => json['package_id'] as String;
  String get edition => json['edition'] as String;
  String get kind => json['kind'] as String;
  bool get sample => json['is_sample'] as bool;
  String get label => '$edition · $id${sample ? ' · SAMPLE' : ''}';
  Map<String, dynamic> get counts => json['row_counts'] as Map<String, dynamic>;
  List<String> get bases =>
      List<String>.from(json['compatible_base_package_ids'] as List? ?? [id]);
  factory PackManifest.parse(String source) {
    rejectDuplicateJsonKeys(source);
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw PackException('manifest 必須為 JSON object');
    }
    final m = decoded;
    const strings = [
      'format',
      'schema_version',
      'package_id',
      'package_version',
      'kind',
      'classification',
      'jurisdiction',
      'edition',
      'release_id',
      'effective_from',
      'effective_to',
      'language',
      'source_organization',
      'created_at',
      'content_filename',
      'content_sha256',
      'required_app_schema_min',
    ];
    const optional = [
      'translation_edition',
      'translation_revision',
      'mapping_policy',
      'compatible_base_package_ids',
    ];
    const other = ['is_sample', 'source_urls', 'source_files', 'row_counts'];
    if (m.keys.any((k) => ![...strings, ...optional, ...other].contains(k))) {
      throw PackException('manifest 未知欄位');
    }
    for (final k in strings) {
      if (m[k] is! String || (m[k] as String).isEmpty) {
        throw PackException('manifest 缺少 $k');
      }
    }
    if (m['format'] != 'icdpack' ||
        m['classification'] != 'ICD-10-CM' ||
        m['content_filename'] != 'content.sqlite') {
      throw PackException('非 ICD-10-CM 資料包');
    }
    if (m['schema_version'] != '1.0.0' ||
        m['required_app_schema_min'] != '1.0.0') {
      throw PackException('不相容 schema，請升級 App；原資料未更動');
    }
    if (![
          'icd10cm_en',
          'icd10cm_zh_tw',
          'icd10cm_combined',
        ].contains(m['kind']) ||
        m['is_sample'] is! bool) {
      throw PackException('資料種類或 SAMPLE 標示錯誤');
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,127}$').hasMatch(m['package_id']) ||
        !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(m['package_version']) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(m['content_sha256'])) {
      throw PackException('ID、版本或 SHA256 格式錯誤');
    }
    for (final k in ['effective_from', 'effective_to']) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(m[k])) {
        throw PackException('有效日期格式錯誤');
      }
    }
    if ((m['effective_to'] as String).compareTo(m['effective_from']) < 0) {
      throw PackException('有效期間錯誤');
    }
    if (m['row_counts'] is! Map<String, dynamic>) {
      throw PackException('缺少資料列數');
    }
    final counts = m['row_counts'] as Map<String, dynamic>;
    if (counts.length != contentTables.length ||
        contentTables.any(
          (t) =>
              counts[t] is! int ||
              (counts[t] as int) < 0 ||
              (counts[t] as int) > 100000000,
        )) {
      throw PackException('資料列數錯誤');
    }
    if (m['source_urls'] is! List ||
        (m['source_urls'] as List).isEmpty ||
        (m['source_urls'] as List).any(
          (v) =>
              v is! String ||
              !(v.startsWith('https://') || v.startsWith('sample://')),
        )) {
      throw PackException('來源網址錯誤（僅記錄，不會連線）');
    }
    if (m['source_files'] is! List || (m['source_files'] as List).isEmpty) {
      throw PackException('缺少原檔來源');
    }
    for (final f in m['source_files'] as List) {
      if (f is! Map ||
          f.keys.length != 2 ||
          f['name'] is! String ||
          (f['name'] as String).isEmpty ||
          f['sha256'] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(f['sha256'])) {
        throw PackException('原始檔 hash 錯誤');
      }
    }
    for (final k in optional.take(3)) {
      if (m.containsKey(k) && m[k] is! String) {
        throw PackException('中譯欄位錯誤');
      }
    }
    if (m.containsKey('compatible_base_package_ids') &&
        (m['compatible_base_package_ids'] is! List ||
            (m['compatible_base_package_ids'] as List).any(
              (v) => v is! String,
            ))) {
      throw PackException('中譯 base 清單錯誤');
    }
    if (m['kind'] == 'icd10cm_zh_tw' &&
        ((m['compatible_base_package_ids'] as List? ?? []).isEmpty ||
            optional.take(3).any((k) => !m.containsKey(k)))) {
      throw PackException('中譯包必須宣告版別與 base 相容清單');
    }
    if (m['is_sample'] == true &&
        !(m['source_organization'] as String).contains('SAMPLE')) {
      throw PackException('SAMPLE 缺少警示');
    }
    return PackManifest._(m);
  }
}

// jsonDecode normally accepts duplicate object keys. Reject them before decoding
// so publisher metadata cannot mean different things to the Python/Dart sides.
void rejectDuplicateJsonKeys(String source) {
  final tokens = RegExp(r'"(?:[^"\\]|\\.)*"|[{}\[\]:,]|[^\s{}\[\]:,]+')
      .allMatches(source)
      .map((m) => m[0]!)
      .toList();
  var i = 0;
  void value(int depth) {
    if (depth > 64 || i >= tokens.length) {
      throw PackException('JSON 過深或截斷');
    }
    final token = tokens[i++];
    if (token == '{') {
      final keys = <String>{};
      if (i < tokens.length && tokens[i] == '}') {
        i++;
        return;
      }
      while (i < tokens.length) {
        final key = jsonDecode(tokens[i++]);
        if (key is! String || !keys.add(key)) {
          throw PackException('JSON 重複欄位');
        }
        if (i >= tokens.length || tokens[i++] != ':') {
          throw PackException('JSON 冒號錯誤');
        }
        value(depth + 1);
        if (i >= tokens.length) {
          throw PackException('JSON 截斷');
        }
        final sep = tokens[i++];
        if (sep == '}') {
          return;
        }
        if (sep != ',') {
          throw PackException('JSON 格式錯誤');
        }
      }
    } else if (token == '[') {
      if (i < tokens.length && tokens[i] == ']') {
        i++;
        return;
      }
      while (i < tokens.length) {
        value(depth + 1);
        if (i >= tokens.length) {
          throw PackException('JSON 截斷');
        }
        final sep = tokens[i++];
        if (sep == ']') {
          return;
        }
        if (sep != ',') {
          throw PackException('JSON 格式錯誤');
        }
      }
    }
  }

  value(0);
  if (i != tokens.length) {
    throw PackException('JSON 多餘內容');
  }
}
