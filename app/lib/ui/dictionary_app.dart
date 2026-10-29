import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide DataRow;
import 'package:flutter/services.dart';

import '../app/controller.dart';
import '../data/package_store.dart';
import '../data/repository.dart';
import '../domain/manifest.dart';

int paneCount(double width) => width >= 1180
    ? 3
    : width >= 720
    ? 2
    : 1;

class DictionaryApp extends StatefulWidget {
  final DictionaryController controller;
  const DictionaryApp({super.key, required this.controller});
  @override
  State<DictionaryApp> createState() => _DictionaryAppState();
}

class _DictionaryAppState extends State<DictionaryApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ICD Offline',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176c67)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff5cc5b5),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: DictionaryHome(
      controller: widget.controller,
      onTheme: () => setState(
        () => mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      ),
    ),
  );
}

class DictionaryHome extends StatefulWidget {
  final DictionaryController controller;
  final VoidCallback onTheme;
  const DictionaryHome({
    super.key,
    required this.controller,
    required this.onTheme,
  });
  @override
  State<DictionaryHome> createState() => _DictionaryHomeState();
}

class _DictionaryHomeState extends State<DictionaryHome> {
  DictionaryController get c => widget.controller;
  final input = TextEditingController(), searchFocus = FocusNode();
  bool busy = false;
  int tab = 0;
  double treeWidth = 260, resultWidth = 370;
  @override
  void initState() {
    super.initState();
    c.addListener(changed);
  }

  void changed() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    c.removeListener(changed);
    input.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      error(e);
    }
  }

  Future<void> open(DataRow row) async {
    await guard(() async {
      await c.open(row);
      if (!mounted) {
        return;
      }
      if (paneCount(MediaQuery.sizeOf(context).width) == 1) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('代碼 / Index 詳情')),
              body: ListenableBuilder(
                listenable: c,
                builder: (_, _) => detailPanel(),
              ),
            ),
          ),
        );
      }
    });
  }

  Future<void> importPack() async {
    PreparedPack? prepared;
    setState(() => busy = true);
    try {
      final selected = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'ICD package', extensions: ['icdpack']),
        ],
      );
      if (selected == null) {
        return;
      }
      prepared = await c.store.prepare(File(selected.path));
      if (!mounted) {
        return;
      }
      final p = prepared;
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('驗證完成 · 匯入預覽'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                '${p.manifest.label}\n${p.manifest.sample ? 'SAMPLE / NOT FOR CLINICAL CODING\n' : ''}來源：${p.manifest.json['source_organization']}\n有效：${p.manifest.json['effective_from']} – ${p.manifest.json['effective_to']}\n列數：${p.manifest.counts}\n中譯政策：${p.manifest.json['mapping_policy'] ?? '無中譯'}\nSHA256：${p.hash}\n\nSHA256 只驗證完整性；來源宣告不是數位簽章，需另核對官方原檔。\n舊版與個人資料將保留。',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('匯入並啟用'),
            ),
          ],
        ),
      );
      if (yes == true) {
        final hash = await c.store.publish(prepared);
        await c.choose(
          hash,
          translation: prepared.manifest.kind == 'icd10cm_zh_tw',
        );
      }
    } catch (e) {
      error(e);
    } finally {
      if (prepared != null) {
        await c.store.discard(prepared);
      }
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget versionPicker() {
    final installed = c.store.installed
        .where(
          (r) => c.store.manifest(r['hash'] as String).kind != 'icd10cm_zh_tw',
        )
        .toList();
    return DropdownButton<String>(
      isExpanded: true,
      value: c.active,
      hint: const Text('尚未匯入資料包'),
      items: installed
          .map(
            (r) => DropdownMenuItem(
              value: r['hash'] as String,
              child: Text(
                c.store.manifest(r['hash'] as String).label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: busy
          ? null
          : (v) {
              if (v != null) {
                guard(() => c.choose(v));
              }
            },
    );
  }

  Widget searchPanel() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: input,
          focusNode: searchFocus,
          decoration: InputDecoration(
            labelText: '搜尋代碼、英文、中文',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: '清空搜尋',
              onPressed: () {
                input.clear();
                c.query = '';
                guard(c.search);
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          onChanged: c.queueSearch,
          onSubmitted: (_) => guard(() async {
            await c.search();
            if (c.results.isNotEmpty) {
              await open(c.results[c.selected]);
            }
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButton<String>(
                isExpanded: true,
                value: c.scope,
                items: c.scopes
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          {
                                'all': '全部',
                                'tabular': 'Tabular',
                                'alphabetic': 'Alphabetic Index',
                                'external': 'External Causes',
                                'neoplasm': 'Neoplasm',
                                'drugs': 'Drugs & Chemicals',
                              }[s] ??
                              s,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    c.scope = v;
                    guard(c.search);
                  }
                },
              ),
            ),
            FilterChip(
              label: Text(c.any ? 'OR 任一詞' : 'AND 全部詞'),
              selected: c.any,
              onSelected: (v) {
                c.any = v;
                guard(c.search);
              },
            ),
            FilterChip(
              label: const Text('前綴'),
              selected: c.prefix,
              onSelected: (v) {
                c.prefix = v;
                guard(c.search);
              },
            ),
          ],
        ),
      ),
      if (c.searching) const LinearProgressIndicator(),
      if (c.lastError != null)
        Padding(padding: const EdgeInsets.all(8), child: Text(c.lastError!)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${c.results.length} 筆（最多 100 筆）· 排序不代表診斷確立',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
      Expanded(
        child: c.results.isEmpty
            ? const Center(child: Text('無結果；請調整查詢或來源'))
            : ListView.builder(
                itemCount: c.results.length,
                itemBuilder: (context, i) {
                  final r = c.results[i], code = r['code'] as String?;
                  return ListTile(
                    selected: i == c.selected,
                    leading: Icon(
                      code == null
                          ? Icons.account_tree_outlined
                          : Icons.article_outlined,
                    ),
                    title: Text(
                      code == null
                          ? r['term_path'] as String
                          : '$code  ${r['title_en']}',
                    ),
                    subtitle: Text(
                      code == null
                          ? '${r['entry_type']} → ${r['target_code'] ?? 'cross reference'}'
                          : '${r['title_zh_tw'] ?? '該版本無經驗證官方中譯'}\n${r['state']} · ${c.store.manifest(c.active!).edition}',
                    ),
                    isThreeLine: code != null,
                    onTap: () {
                      c.selected = i;
                      c.store.recordSearch(
                        c.store.manifest(c.active!).id,
                        c.query,
                      );
                      open(r);
                    },
                  );
                },
              ),
      ),
    ],
  );
  Widget treePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '分類樹 / 來源結構',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Expanded(
        child: ListView(
          children: [
            ...c.roots.map(
              (r) => HierarchyTile(
                key: ValueKey('${c.active}:c:${r['id']}'),
                row: r,
                controller: c,
                onOpen: open,
              ),
            ),
            for (final type in c.scopes.where(
              (s) => !['all', 'tabular'].contains(s),
            ))
              ExpansionTile(
                title: Text(type),
                children: [
                  IndexRoots(
                    key: ValueKey('${c.active}:$type'),
                    controller: c,
                    type: type,
                    onOpen: open,
                  ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
  Widget detailPanel() {
    final d = c.detail;
    if (d == null) {
      return const Center(child: Text('選擇結果以查看詳情與繼承註記'));
    }
    final m = c.store.manifest(c.active!);
    final index = d.containsKey('term_path');
    if (index) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            d['term_path'] as String,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${d['entry_type']} · ${m.edition}'),
          SelectableText('來源：${d['source_reference']}'),
          const Divider(),
          Text('目標：${d['target_code'] ?? '未指定精確碼'}'),
          if ((d['target_nodes'] as List).isEmpty)
            const Text(
              '範圍、未完整碼或 cross-reference：請先確認 Index → Tabular，不自動推定有效申報碼。',
            ),
          for (final r in d['target_nodes'] as List)
            ListTile(
              title: Text('Tabular → ${r['code']}'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => guard(() => c.open(Map<String, Object?>.from(r))),
            ),
          for (final r in d['crossrefs'] as List)
            ListTile(
              title: Text('${r['ref_type']}: ${r['target_term']}'),
              onTap: () {
                input.text = r['target_term'] as String;
                c.query = input.text;
                c.scope = 'all';
                guard(c.search);
              },
            ),
          for (final r in d['cells'] as List)
            ListTile(
              title: Text('${r['column_label']} → ${r['target_code']}'),
              onTap: () => guard(() async {
                final target = r['target_code'] as String;
                final nodes = await c.read(
                  (repo) => repo.resolveTarget(target),
                );
                if (nodes.isEmpty) {
                  error('範圍 / 未完成碼 $target：需人工確認');
                } else {
                  await c.open(nodes.first);
                }
              }),
            ),
          const Text('子詞'),
          for (final r in d['children'] as List)
            ListTile(
              title: Text(r['term_path'] as String),
              onTap: () => guard(() => c.open(Map<String, Object?>.from(r))),
            ),
        ],
      );
    }
    final zh = d['translations'] as List;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text(d['state'] as String)),
            Chip(label: Text(m.edition)),
            if (m.sample)
              const Chip(label: Text('SAMPLE / NOT FOR CLINICAL CODING')),
          ],
        ),
        SelectableText(
          '${d['code']}  ${d['title_en']}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        if (zh.isEmpty)
          const Text('該版本無經驗證官方中譯')
        else
          for (final t in zh)
            SelectableText(
              '${t['title_zh_tw']}\n${m.sample ? '合成測試中譯' : '來源對照宣告'}：${t['translation_edition']} / ${t['translation_revision']}\n${t['mapping_status'] == 'reviewed_cross_release' ? '非同版，僅供參考（已審核跨版）' : t['mapping_status']} · ${t['source_reference']}',
            ),
        if ((d['references'] as List).length > zh.length)
          ExpansionTile(
            title: const Text('顯示未確認跨版參考（不代表官方相容）'),
            children: [
              const Text('非同版，僅供參考；未用於合格中文搜尋。'),
              for (final t in (d['references'] as List).where(
                (t) =>
                    t['mapping_status'] == 'unresolved' ||
                    t['base_package_id'] != m.id,
              ))
                ListTile(
                  title: Text(t['title_zh_tw'] as String),
                  subtitle: Text(
                    '${t['translation_edition']} / ${t['translation_revision']} · ${t['mapping_status']}\n${t['source_reference']}',
                  ),
                ),
            ],
          ),
        Text(
          '有效期間：${d['valid_from']} – ${d['valid_to']}\n${d['billable'] == 1 ? '來源列為完整碼；仍須依規則確認' : '非完整可申報碼／需要更多字元'}',
        ),
        Wrap(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('複製代碼與來源'),
              onPressed: () => Clipboard.setData(
                ClipboardData(
                  text:
                      '${d['code']} ${d['title_en']}\n${zh.map((t) => t['title_zh_tw']).join(' / ')}\n${m.id} · ${m.edition}',
                ),
              ),
            ),
            TextButton.icon(
              icon: Icon(
                c.store.isFavorite(m.id, d['code'] as String)
                    ? Icons.star
                    : Icons.star_border,
              ),
              label: const Text('收藏'),
              onPressed: () {
                c.store.favorite(
                  m.id,
                  d['code'] as String,
                  !c.store.isFavorite(m.id, d['code'] as String),
                );
                setState(() {});
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('個人註解'),
              onPressed: () => editNote(m, d),
            ),
          ],
        ),
        const Divider(),
        const Text('階層（由上而下）'),
        for (final a in d['ancestors'] as List)
          Text('${a['code']} ${a['title_en']}'),
        const SizedBox(height: 16),
        Text('本層與繼承 notes', style: Theme.of(context).textTheme.titleLarge),
        for (final n in d['notes'] as List)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${n['note_type']} · ${n['inherited'] == true ? '繼承' : '本碼'}：${n['owner_code']} ${n['owner_title']}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  SelectableText(n['note_text'] as String),
                  SelectableText(
                    '來源：${n['source_reference']}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        const Text('子碼'),
        for (final child in d['children'] as List)
          ListTile(
            title: Text('${child['code']} ${child['title_en']}'),
            onTap: () => guard(() => c.open(Map<String, Object?>.from(child))),
          ),
        const Text('相關 Index 候選（仍需核對）'),
        for (final r in d['related_index'] as List)
          ListTile(
            title: Text(r['term_path'] as String),
            onTap: () => guard(() => c.open(Map<String, Object?>.from(r))),
          ),
        SelectableText('來源：${d['source_reference']}'),
      ],
    );
  }

  Future<void> editNote(PackManifest m, DataRow d) async {
    final text = TextEditingController(
      text: c.store.note(m.id, d['code'] as String),
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('個人註解（只存本機 user.sqlite）'),
        content: TextField(controller: text, maxLines: 5),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              c.store.saveNote(m.id, d['code'] as String, text.text);
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    text.dispose();
  }

  Future<void> personalExport() async {
    final target = await getSaveLocation(
      suggestedName: 'icd-personal.json',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (target != null) {
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(c.store.exportPersonal())),
        mimeType: 'application/json',
      ).saveTo(target.path);
    }
  }

  Future<void> personalImport() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file != null) {
      c.store.importPersonal(await file.readAsString());
      setState(() {});
    }
  }

  Widget managePanel() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('本機資料管理', style: Theme.of(context).textTheme.headlineSmall),
      const Text('App、唯讀官方資料與 user.sqlite 獨立；更新保留舊版，無網路下載。'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: busy ? null : importPack,
        icon: const Icon(Icons.file_open),
        label: const Text('選擇 .icdpack · 驗證 · 預覽'),
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () => guard(() async {
                await c.store.rollback();
                await c.refresh();
              }),
        icon: const Icon(Icons.restore),
        label: const Text('回復上一版'),
      ),
      for (final r in c.store.installed)
        Card(
          child: ListTile(
            title: Text(c.store.manifest(r['hash'] as String).label),
            subtitle: SelectableText(
              'SHA256: ${r['hash']}\n${c.store.manifest(r['hash'] as String).counts}',
            ),
            trailing: IconButton(
              tooltip: '啟用此版本',
              icon: Icon(
                r['hash'] == c.active
                    ? Icons.check_circle
                    : Icons.play_circle_outline,
              ),
              onPressed: () => guard(
                () => c.choose(
                  r['hash'] as String,
                  translation:
                      c.store.manifest(r['hash'] as String).kind ==
                      'icd10cm_zh_tw',
                ),
              ),
            ),
          ),
        ),
      if (c.store.installed
              .where(
                (r) =>
                    c.store.manifest(r['hash'] as String).kind !=
                    'icd10cm_zh_tw',
              )
              .length >=
          2)
        OutlinedButton(
          onPressed: () => guard(compareVersions),
          child: const Text('比較兩個英文版本（新增 / 停用 / 描述 / 註記）'),
        ),
      const Divider(),
      SwitchListTile(
        title: const Text('保留本機搜尋紀錄'),
        value: c.store.preference('history') != 'off',
        onChanged: (v) {
          c.store.setPreference('history', v ? 'on' : 'off');
          setState(() {});
        },
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => guard(personalExport),
            child: const Text('匯出收藏／註解'),
          ),
          OutlinedButton(
            onPressed: () => guard(personalImport),
            child: const Text('匯入收藏／註解'),
          ),
        ],
      ),
      const Text('收藏依 package ID 隔離；切版不自動把相同 code 視為語義相同。'),
      for (final f in c.store.user.select(
        'SELECT * FROM favorites ORDER BY package_id,code',
      ))
        ListTile(
          title: Text('★ ${f['code']}'),
          subtitle: Text(
            '${f['package_id']}${c.active != null && f['package_id'] != c.store.manifest(c.active!).id ? ' · 非目前版本，需重新驗碼' : ''}',
          ),
          onTap: () => guard(() async {
            if (c.active == null ||
                f['package_id'] != c.store.manifest(c.active!).id) {
              error('此收藏屬於另一版本；請先切換版本');
              return;
            }
            final result = await c.read(
              (r) => r.resolveTarget(f['code'] as String),
            );
            if (result.isEmpty) {
              error('此版本無此代碼，可能已停用');
            } else {
              await open(result.first);
            }
          }),
        ),
      OutlinedButton(
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'ICD Offline · Demo',
          applicationVersion: '0.1.1',
        ),
        child: const Text('開放原始碼授權'),
      ),
      const Divider(),
      const Text('匯入紀錄（僅本機，不含查詢內容）'),
      for (final r in c.store.user.select(
        'SELECT time,event,hash FROM import_log ORDER BY id DESC LIMIT 20',
      ))
        SelectableText('${r['time']} ${r['event']} ${r['hash']}'),
    ],
  );
  Future<void> compareVersions() async {
    final packs = c.store.installed
        .where(
          (r) => c.store.manifest(r['hash'] as String).kind != 'icd10cm_zh_tw',
        )
        .toList();
    String left = packs.first['hash'] as String,
        right = packs.last['hash'] as String;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('選擇比較版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final first in [true, false])
                DropdownButton<String>(
                  isExpanded: true,
                  value: first ? left : right,
                  items: packs
                      .map(
                        (r) => DropdownMenuItem(
                          value: r['hash'] as String,
                          child: Text(
                            c.store.manifest(r['hash'] as String).label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() {
                    if (v != null) {
                      if (first) {
                        left = v;
                      } else {
                        right = v;
                      }
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('比較'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) {
      return;
    }
    final lp = c.store.contentPath(left),
        rp = c.store.contentPath(right),
        lm = c.store.manifest(left),
        rm = c.store.manifest(right);
    // Isolate operation opens independent readonly handles, with no migration.
    final changes = await computeDiff(lp, lm, rp, rm);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${lm.edition} → ${rm.edition}'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: ListView(
            children: [
              const Text('比較不是官方 lineage／拆分對照表；相同 code 不表示語義完全相同。'),
              for (final r in changes)
                ListTile(
                  title: Text('${r['change']} ${r['code']}'),
                  subtitle: Text('${r['title_en']}\n${r['new_title'] ?? ''}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget divider(bool tree) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragUpdate: (d) => setState(() {
      if (tree) {
        treeWidth = (treeWidth + d.delta.dx).clamp(190, 360);
      } else {
        resultWidth = (resultWidth + d.delta.dx).clamp(300, 500);
      }
    }),
    child: const SizedBox(width: 8, child: VerticalDivider(width: 1)),
  );
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
          searchFocus.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          searchFocus.requestFocus(),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        input.clear();
        c.query = '';
        c.detail = null;
        guard(c.search);
      },
      const SingleActivator(LogicalKeyboardKey.arrowDown): () {
        if (c.results.isNotEmpty) {
          setState(
            () => c.selected = (c.selected + 1).clamp(0, c.results.length - 1),
          );
        }
      },
      const SingleActivator(LogicalKeyboardKey.arrowUp): () {
        if (c.results.isNotEmpty) {
          setState(
            () => c.selected = (c.selected - 1).clamp(0, c.results.length - 1),
          );
        }
      },
      const SingleActivator(LogicalKeyboardKey.enter): () {
        if (c.results.isNotEmpty) {
          open(c.results[c.selected]);
        }
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ICD · Offline Dictionary'),
          actions: [
            IconButton(
              tooltip: '明暗模式',
              onPressed: widget.onTheme,
              icon: const Icon(Icons.contrast),
            ),
            IconButton(
              tooltip: '資料管理',
              onPressed: () => setState(() => tab = tab == 2 ? 0 : 2),
              icon: const Icon(Icons.storage),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: versionPicker(),
            ),
            if (c.active != null && c.store.manifest(c.active!).sample)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.errorContainer,
                padding: const EdgeInsets.all(10),
                child: const Text(
                  'SAMPLE / NOT FOR CLINICAL CODING · 合成測試資料，非臨床用途',
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (tab == 2) {
                    return managePanel();
                  }
                  if (c.active == null) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/branding/icon.png',
                                width: 72,
                                height: 72,
                                semanticLabel: 'ICD Offline 圖示',
                              ),
                              const SizedBox(height: 20),
                              const Text('完全離線 · 資料與程式分離'),
                              const Text('請手動匯入資料包。示例包須另外選取，並標為非臨床用途。'),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: busy ? null : importPack,
                                child: const Text('匯入 .icdpack'),
                              ),
                              if (busy) const LinearProgressIndicator(),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final panes = paneCount(constraints.maxWidth);
                  if (panes == 1) {
                    return tab == 1 ? treePanel() : searchPanel();
                  }
                  if (panes == 2) {
                    return Row(
                      children: [
                        Expanded(child: tab == 1 ? treePanel() : searchPanel()),
                        const VerticalDivider(width: 1),
                        Expanded(child: detailPanel()),
                      ],
                    );
                  }
                  final usable = constraints.maxWidth - 16;
                  final tw = treeWidth.clamp(190, usable * .25).toDouble(),
                      rw = resultWidth.clamp(300, usable * .35).toDouble();
                  return Row(
                    children: [
                      SizedBox(width: tw, child: treePanel()),
                      divider(true),
                      SizedBox(width: rw, child: searchPanel()),
                      divider(false),
                      Expanded(child: detailPanel()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: '搜尋'),
            NavigationDestination(
              icon: Icon(Icons.account_tree_outlined),
              label: '分類',
            ),
            NavigationDestination(icon: Icon(Icons.storage), label: '資料'),
          ],
        ),
      ),
    ),
  );
}

class HierarchyTile extends StatefulWidget {
  final DataRow row;
  final DictionaryController controller;
  final Future<void> Function(DataRow) onOpen;
  final bool index;
  const HierarchyTile({
    super.key,
    required this.row,
    required this.controller,
    required this.onOpen,
    this.index = false,
  });
  @override
  State<HierarchyTile> createState() => _HierarchyTileState();
}

class _HierarchyTileState extends State<HierarchyTile> {
  List<DataRow>? children;
  bool loading = false;
  Future<void> load(bool expanded) async {
    if (!expanded || children != null || loading) {
      return;
    }
    setState(() => loading = true);
    try {
      final id = widget.row['id'] as int,
          type = widget.row['entry_type'] as String?,
          isIndex = widget.index;
      final data = await widget.controller.read(
        (r) => isIndex ? r.indexChildren(id, type!) : r.children(id),
      );
      if (mounted) {
        setState(() => children = data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row,
        title = widget.index
            ? (r['sub_term'] ?? r['main_term']) as String
            : '${r['code']} ${r['title_en']}';
    return ExpansionTile(
      key: PageStorageKey(
        '${widget.controller.active}:${widget.index}:${r['id']}',
      ),
      title: Text(title),
      leading: IconButton(
        tooltip: '開啟詳情',
        icon: const Icon(Icons.open_in_new, size: 20),
        onPressed: () => widget.onOpen(r),
      ),
      onExpansionChanged: load,
      children: loading
          ? [const LinearProgressIndicator()]
          : [
              for (final child in children ?? [])
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: HierarchyTile(
                    row: child,
                    controller: widget.controller,
                    onOpen: widget.onOpen,
                    index: widget.index,
                  ),
                ),
            ],
    );
  }
}

class IndexRoots extends StatefulWidget {
  final DictionaryController controller;
  final String type;
  final Future<void> Function(DataRow) onOpen;
  const IndexRoots({
    super.key,
    required this.controller,
    required this.type,
    required this.onOpen,
  });
  @override
  State<IndexRoots> createState() => _IndexRootsState();
}

class _IndexRootsState extends State<IndexRoots> {
  List<DataRow> entries = [];
  bool loading = false, more = true;
  String? problem;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading || !more) {
      return;
    }
    setState(() => loading = true);
    final type = widget.type, offset = entries.length;
    try {
      final rows = await widget.controller.read(
        (r) => r.indexChildren(null, type, limit: 100, offset: offset),
      );
      if (mounted) {
        setState(() {
          entries.addAll(rows);
          more = rows.length == 100;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => problem = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final row in entries)
        HierarchyTile(
          row: row,
          controller: widget.controller,
          onOpen: widget.onOpen,
          index: true,
        ),
      if (problem != null) Text(problem!),
      if (loading) const LinearProgressIndicator(),
      if (more && !loading)
        TextButton(onPressed: load, child: const Text('載入接下來 100 個主詞')),
    ],
  );
}
