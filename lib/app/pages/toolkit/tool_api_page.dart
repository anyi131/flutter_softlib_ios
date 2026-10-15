import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../api/soft_service.dart';
import '../../design/app_anim.dart';
import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_browser_page.dart';
import 'tool_cache.dart';
import 'tool_kit.dart';

/// 工具箱 · 通用接口工具（1015 新增）
///
/// 设计目标：**后台配好参数就能出工具，不用改 App、不用发版**
///
/// 后台配置项（工具编辑里的「接口」分组）：
///   api_url   接口地址（会走服务端代理，避免 UA/CORS 拦截）
///   api_path  列表在 JSON 里的路径，如 `data.cards.0.content` 或 `data.list`
///   f_title   标题字段名，如 `word` / `title`
///   f_sub     副标题字段名（可空）
///   f_image   图片字段名（可空）
///   f_link    点击跳转链接字段（可空，有则点击用内置浏览器打开）
///   f_extra   额外展示字段，如热度 `hot_value` / 描述 `desc`（可空）
///
/// 路径语法：
///   · 用 `.` 分隔层级
///   · 数组用数字下标，如 `data.cards.0.content`
///   · 自动容错：路径找不到时，会在顶层递归找第一个「像列表」的数组
class ApiToolPage extends StatefulWidget {
  final String title;
  final String apiUrl;
  final Map<String, dynamic> cfg;
  const ApiToolPage({
    super.key,
    required this.title,
    required this.apiUrl,
    required this.cfg,
  });

  @override
  State<ApiToolPage> createState() => _ApiToolPageState();
}

class _ApiToolPageState extends State<ApiToolPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    // ★ 1015 优化：先显示上次缓存（秒开），再后台刷新
    final ck = 'api_${widget.apiUrl.hashCode}';
    if (items.isEmpty) {
      final cached = await ToolCache.read(ck);
      final cj = cached?['json'];
      if (cj != null && mounted) {
        final l = _extractList(cj, widget.cfg['api_path'] ?? '');
        final lst = l.isNotEmpty ? l : (_findAnyList(cj) ?? []);
        if (lst.isNotEmpty) {
          setState(() {
            items = lst
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            loading = false;
          });
        }
      }
    }
    setState(() {
      loading = items.isEmpty; // 有缓存就不闪 loading
      err = '';
    });
    try {
      final r = await SoftService.instance.toolboxProxy(widget.apiUrl);
      if (!mounted) return;
      final data = (r['data'] as Map?) ?? const {};
      dynamic raw;
      if (data['is_json'] == true) {
        raw = data['json'];
      } else {
        // 非 JSON：当成纯文本一行一条
        final t = '${data['text'] ?? ''}';
        setState(() {
          items = t
              .split('\n')
              .where((e) => e.trim().isNotEmpty)
              .map((e) => {'__line': e.trim()})
              .toList();
          loading = false;
        });
        return;
      }
      // 写缓存供下次秒开
      ToolCache.write(ck, {'json': raw});
      // ★★★ 1015 修复：先看 api_path 是否指向「单个字符串」
      //   如 today-poem 的 data.content = "桂花香雾冷，梧叶西风影。"
      //   这种情况必须走单条模式；否则后面的 _findAnyList 会误抓到
      //   origin.content（诗句数组），把每句当成列表项 → 显示错乱/显示原始 JSON。
      final pathCfg = widget.cfg['api_path'] ?? '';
      bool isSingleByPath = false;
      if (pathCfg.isNotEmpty) {
        final v = _pickPath(raw, pathCfg);
        if (v is String && v.trim().isNotEmpty) isSingleByPath = true;
      }

      List<dynamic> list = [];
      if (isSingleByPath) {
        final single = _extractSingle(raw, widget.cfg['f_title'] ?? '');
        if (single != null) list = [single];
      } else {
        list = _extractList(raw, pathCfg);
        if (list.isEmpty) {
          // 兜底：递归找第一个长度 >0 的数组
          list = _findAnyList(raw) ?? [];
        }
        // 还是没有 → 单条数据结构
        if (list.isEmpty && raw != null) {
          final single = _extractSingle(raw, widget.cfg['f_title'] ?? '');
          if (single != null) list = [single];
        }
      }
      setState(() {
        items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        loading = false;
        if (items.isEmpty) err = '接口返回了数据，但没找到列表（检查「列表路径」配置）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// 按路径取值
  static dynamic _pickPath(dynamic root, String path) {
    if (path.trim().isEmpty) return null;
    dynamic cur = root;
    for (final seg in path.split('.')) {
      if (seg.isEmpty) continue;
      if (cur is List) {
        final i = int.tryParse(seg);
        if (i == null || i < 0 || i >= cur.length) return null;
        cur = cur[i];
      } else if (cur is Map) {
        if (!cur.containsKey(seg)) return null;
        cur = cur[seg];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// 取列表：支持路径直接是数组，或路径指向「数组包在对象里」
  static List<dynamic> _extractList(dynamic root, String path) {
    final node = _pickPath(root, path);
    if (node is List) return node;
    if (node is Map) {
      final found = _findAnyList(node);
      if (found != null) return found;
    }
    return const [];
  }

  /// 单条数据提取：在对象里找「看起来像正文」的字符串
  /// 优先用配置的 f_title；否则按常见键名找；再否则取最长的字符串值
  static Map<String, dynamic>? _extractSingle(dynamic raw, String key) {
    if (raw is! Map) return null;
    // ① 按配置的字段名找（支持 a.b 路径）
    if (key.trim().isNotEmpty) {
      final v = _pickPath(raw, key);
      if (v is String && v.trim().isNotEmpty) {
        return {'content': v.trim()};
      }
    }
    // ② 常见正文键名
    for (final k in const ['content', 'text', 'answer', 'message', 'msg', 'hitokoto', 'words', 'data', 'result']) {
      final v = raw[k];
      if (v is String && v.trim().isNotEmpty) return {'content': v.trim()};
    }
    // ③ 递归进一层（如 {data:{content:...}}）
    for (final v in raw.values) {
      if (v is Map) {
        final r = _extractSingle(v, key);
        if (r != null) return r;
      }
    }
    // ④ 兜底：取最长的字符串值
    String best = '';
    for (final v in raw.values) {
      if (v is String && v.trim().length > best.length) best = v.trim();
      if (v is List || v is Map) continue;
    }
    if (best.length > 4) return {'content': best};
    return null;
  }

  /// 递归找第一个非空数组
  static List<dynamic>? _findAnyList(dynamic node, [int depth = 0]) {
    if (depth > 6) return null;
    if (node is List && node.isNotEmpty) return node;
    if (node is Map) {
      // 优先常见键名
      for (final k in ['list', 'items', 'data', 'content', 'result', 'rows', 'word_list', 'news']) {
        final v = node[k];
        if (v is List && v.isNotEmpty) return v;
      }
      for (final v in node.values) {
        final r = _findAnyList(v, depth + 1);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// 按字段名取值（容错：键名大小写不敏感、找不到时试常见别名）
  static String _field(Map<String, dynamic> m, String key) {
    if (key.trim().isEmpty) return '';
    // 精确
    if (m.containsKey(key)) {
      final v = m[key];
      return v == null ? '' : '$v';
    }
    // 大小写不敏感
    final lower = key.toLowerCase();
    for (final e in m.entries) {
      if (e.key.toLowerCase() == lower) {
        return e.value == null ? '' : '${e.value}';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: widget.title,
      subtitle: '共 ${items.length} 条',
      scrollable: false,
      actions: [
        AppPressable(
          onTap: loading ? null : load,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.refresh_rounded, size: 20, color: context.t1),
          ),
        ),
      ],
      // ★★★ 1015 关键修复：原来这里多套了一层 Expanded。
      //   ToolScaffold 内部已是 Expanded(child: child)，
      //   双层 Expanded 会让布局约束自引用 → 死循环 → 点开就卡死+闪退！
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : err.isNotEmpty
          ? _errorView()
          : items.isEmpty
          ? _emptyView()
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.separated(
                padding: EdgeInsets.only(
                  left: context.pagePadding,
                  right: context.pagePadding,
                  bottom: context.tabSpace + 30,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (c, i) {
                  // ★ 1015：单条渲染加保护 —— 任何一条异常都不会拖垮整页
                  try {
                    return _card(items[i], i);
                  } catch (e) {
                    debugPrint('[ApiTool] card render: $e');
                    return const SizedBox(height: 1);
                  }
                },
              ),
            ),
    );
  }

  Widget _card(Map<String, dynamic> m, int i) {
    // 纯文本模式
    if (m.containsKey('__line')) {
      return ToolCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i < 3 ? C.danger.withAlpha(30) : C.brand.withAlpha(20),
                borderRadius: BorderRadius.circular(R.xs),
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: i < 3 ? C.danger : C.brand,
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('${m['__line']}', style: Ty.small.copyWith(color: context.t1, height: 1.6))),
          ],
        ),
      );
    }

    final cfg = widget.cfg;
    var t = _field(m, '${cfg['f_title'] ?? ''}');
    var sub = _field(m, '${cfg['f_sub'] ?? ''}');
    final img = _field(m, '${cfg['f_image'] ?? ''}');
    final link = _field(m, '${cfg['f_link'] ?? ''}');
    final extra = _field(m, '${cfg['f_extra'] ?? ''}');
    // 标题兜底
    if (t.isEmpty) {
      for (final k in ['content', 'title', 'word', 'name', 'Title', 'desc']) {
        final v = _field(m, k);
        if (v.isNotEmpty) {
          t = v;
          break;
        }
      }
    }
    if (t.isEmpty && sub.isEmpty) {
      t = m.values.take(1).map((e) => '$e').join();
    }

    return ToolCard(
      onTap: link.isEmpty
          ? null
          : () {
              if (link.startsWith('http')) {
                // 复用内置浏览器（带广告清理）
                Get.to(() => ToolBrowserPage(title: t, url: link));
              } else {
                ToastUtil.info(link);
              }
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text('${i + 1}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: i < 3 ? C.danger : context.t3,
                )),
          ),
          if (img.isNotEmpty && img.startsWith('http')) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(R.sm),
              child: Image.network(
                img,
                width: Ad.w(context, 62),
                height: Ad.h(context, 62),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 62, height: 62),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: context.t1,
                      height: 1.45,
                    )),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(color: context.t3, height: 1.5)),
                ],
                if (extra.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(extra, style: Ty.tiny.copyWith(color: C.brand, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          if (link.startsWith('http'))
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: context.t3),
            ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 44, color: context.t3),
              const SizedBox(height: 12),
              Text('接口暂时取不到数据', style: Ty.h3.copyWith(color: context.t1)),
              const SizedBox(height: 8),
              Text(err, textAlign: TextAlign.center, style: Ty.tiny.copyWith(color: context.t3)),
              const SizedBox(height: 18),
              ToolButton(label: '重试', icon: Icons.refresh_rounded, onPressed: load),
            ],
          ),
        ),
      );

  Widget _emptyView() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 44, color: context.t3),
            const SizedBox(height: 12),
            Text('暂无数据', style: Ty.h3.copyWith(color: context.t1)),
            const SizedBox(height: 18),
            ToolButton(label: '刷新', icon: Icons.refresh_rounded, onPressed: load),
          ],
        ),
      );
}
