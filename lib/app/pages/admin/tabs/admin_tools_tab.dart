import 'package:flutter/material.dart';

import '../../../utils/app_action.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import '../../../api/admin_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// ═══════════════════════════════════════════════════════════════
/// 后台 · 工具箱管理（v3.3.4）
///
/// 三块内容：
///   ① 总览条 —— 分类数 / 工具数 / 启用 / 停用 / 联网 / 本地
///   ② 工具管理 —— 搜索 + 分类筛选 + 每行**启用开关** + 上移下移 +
///                  编辑弹窗（分类/名称/副标题/emoji/类型/接口地址/排序）
///   ③ 分类管理 —— 增删改 + 排序
///
/// 数据走 admin 的 jzs_* 接口（App 端工具箱读的是同一套数据）。
/// ═══════════════════════════════════════════════════════════════
class AdminToolsTab extends StatefulWidget {
  const AdminToolsTab({super.key});

  @override
  State<AdminToolsTab> createState() => _AdminToolsTabState();
}

class _AdminToolsTabState extends State<AdminToolsTab>
    with SingleTickerProviderStateMixin {
  final _svc = AdminService.instance;
  late final TabController _tab = TabController(length: 2, vsync: this);

  bool _loading = true;
  String _err = '';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _tools = [];
  final _kwCtrl = TextEditingController();
  int _filterCat = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _kwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stats = await _svc.toolboxStats();
      final cats = await _svc.jzsCats();
      final tools = await _svc.jzsTools(
        catId: _filterCat,
        keyword: _kwCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _cats = cats;
        _tools = tools;
        _loading = false;
        _err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _err = ErrText.of(e);
      });
    }
  }

  static bool _on(dynamic v) => v == 1 || v == '1' || v == true;
  static int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_err.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 38, color: context.t3),
            const SizedBox(height: 10),
            Text(
              _err,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.t2),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    return Column(
      children: [
        TabBar(
          controller: _tab,
          indicatorColor: C.brand,
          labelColor: C.brand,
          unselectedLabelColor: context.t3,
          labelStyle: Ty.small.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: '工具 ${_tools.length}'),
            Tab(text: '分类 ${_cats.length}'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [_toolPane(), _catPane()],
          ),
        ),
      ],
    );
  }

  // ═══════════ 总览条 ═══════════

  Widget _statsBar() {
    final items = <(String, String, Color)>[
      ('分类', '${_stats['cats'] ?? 0}', C.brand),
      ('工具', '${_stats['tools'] ?? 0}', C.brandBright),
      ('启用', '${_stats['enabled'] ?? 0}', C.success),
      ('停用', '${_stats['disabled'] ?? 0}', C.danger),
      ('联网', '${_stats['online'] ?? 0}', C.cyan),
      ('本地', '${_stats['local'] ?? 0}', C.violet),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: C.brand.withAlpha(context.isDark ? 26 : 12),
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Column(
                children: [
                  Text(
                    it.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: it.$3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    it.$1,
                    style: Ty.tiny.copyWith(fontSize: 10, color: context.t3),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════ 工具页 ═══════════

  Widget _toolPane() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _statsBar(),
        // 搜索 + 新增
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(
                    color: context.isDark
                        ? Colors.white.withAlpha(20)
                        : Colors.black.withAlpha(10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: context.t3),
                    const SizedBox(width: 7),
                    Expanded(
                      child: TextField(
                        controller: _kwCtrl,
                        onSubmitted: (_) => _load(),
                        style: TextStyle(fontSize: 13.5, color: context.t1),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '搜索工具名',
                          hintStyle: TextStyle(fontSize: 13, color: context.t3),
                        ),
                      ),
                    ),
                    AppPressable(
                      onTap: _load,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: C.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppPressable(
              onTap: () => _editTool(null),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '新增',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 分类筛选胶囊
        if (_cats.isNotEmpty)
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _filterChip('全部', 0),
              for (final c in _cats)
                _filterChip('${c['title'] ?? ''}', _int(c['id'])),
            ],
          ),
        const SizedBox(height: 12),
        if (_tools.isEmpty)
          const EmptyState(
            icon: Icons.widgets_outlined,
            text: '还没有工具',
            hint: '点右上「新增」添加，或先在「分类」里建分类',
          )
        else
          ..._tools.map(_toolRow),
      ],
    );
  }

  Widget _filterChip(String label, int id) {
    final sel = _filterCat == id;
    return AppPressable(
      onTap: () {
        setState(() => _filterCat = id);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? C.brand.withAlpha(26)
              : (context.isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(4)),
          borderRadius: BorderRadius.circular(R.full),
          border: Border.all(
            color: sel ? C.brand.withAlpha(150) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sel ? C.brand : context.t2,
          ),
        ),
      ),
    );
  }

  Widget _toolRow(Map<String, dynamic> t) {
    final on = _on(t['enable_switch']);
    final icon = '${t['icon'] ?? ''}';
    final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
    final hasApi = '${t['api_url'] ?? ''}'.isNotEmpty;
    final target = '${t['target'] ?? ''}';
    return AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: on
                      ? C.brand.withAlpha(20)
                      : (context.isDark
                            ? Colors.white.withAlpha(8)
                            : Colors.black.withAlpha(5)),
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                alignment: Alignment.center,
                child: isEmoji
                    ? Text(
                        icon,
                        style: TextStyle(
                          fontSize: 19,
                          color: on ? null : context.t3,
                        ),
                      )
                    : Icon(
                        Icons.widgets_rounded,
                        size: 19,
                        color: on ? C.brand : context.t3,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${t['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: on ? context.t1 : context.t3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: hasApi
                                ? C.cyan.withAlpha(26)
                                : C.violet.withAlpha(26),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            hasApi ? '联网' : '本地',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: hasApi ? C.cyan : C.violet,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t['cat_title'] ?? '未分类'} · ${t['kind'] ?? ''}'
                      '${target.isEmpty ? '' : ' · ${target.length > 28 ? '${target.substring(0, 28)}…' : target}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                  ],
                ),
              ),
              // ★ 启用开关（用户点名要的「开关」）
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: on,
                  activeThumbColor: C.brand,
                  onChanged: (v) async {
                    try {
                      await _svc.saveJzsTool({
                        ...t,
                        'enable_switch': v ? 1 : 0,
                      });
                      setState(() => t['enable_switch'] = v ? 1 : 0);
                      ToastUtil.success(v ? '已启用' : '已停用');
                    } catch (e) {
                      ToastUtil.error(ErrText.of(e));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _miniBtn('上移', Icons.arrow_upward_rounded, () async {
                await _svc.moveJzsTool(t, -1);
                _load();
              }),
              _miniBtn('下移', Icons.arrow_downward_rounded, () async {
                await _svc.moveJzsTool(t, 1);
                _load();
              }),
              _miniBtn('编辑', Icons.edit_outlined, () => _editTool(t)),
              const Spacer(),
              _miniBtn('删除', Icons.delete_outline_rounded, () async {
                await _svc.deleteJzsTool(_int(t['id']));
                ToastUtil.success('已删除');
                _load();
              }, danger: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final col = danger ? C.danger : context.t2;
    return AppPressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: danger
              ? C.danger.withAlpha(20)
              : (context.isDark
                    ? Colors.white.withAlpha(8)
                    : Colors.black.withAlpha(4)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: col),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: col,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════ 分类页 ═══════════

  Widget _catPane() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _statsBar(),
        Row(
          children: [
            Text('分类列表', style: Ty.h3.copyWith(color: context.t1)),
            const Spacer(),
            AppPressable(
              onTap: () => _editCat(null),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Deco.brandGradient,
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '新增分类',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_cats.isEmpty)
          const EmptyState(
            icon: Icons.category_outlined,
            text: '还没有分类',
            hint: '先建分类，再往里面加工具',
          )
        else
          ..._cats.map(_catRow),
      ],
    );
  }

  Widget _catRow(Map<String, dynamic> c) {
    final on = _on(c['enable_switch']);
    final cnt = ((c['tools'] as List?) ?? []).length;
    return AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c['title'] ?? ''}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: on ? context.t1 : context.t3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${c['hint'] ?? ''}${cnt > 0 ? ' · $cnt 个工具' : ''}',
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t3,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.82,
                child: Switch(
                  value: on,
                  activeThumbColor: C.brand,
                  onChanged: (v) async {
                    try {
                      await _svc.saveJzsCat({...c, 'enable_switch': v ? 1 : 0});
                      setState(() => c['enable_switch'] = v ? 1 : 0);
                      ToastUtil.success(v ? '已启用' : '已停用');
                    } catch (e) {
                      ToastUtil.error(ErrText.of(e));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _miniBtn('上移', Icons.arrow_upward_rounded, () async {
                await _svc.moveJzsCat(c, -1);
                _load();
              }),
              _miniBtn('下移', Icons.arrow_downward_rounded, () async {
                await _svc.moveJzsCat(c, 1);
                _load();
              }),
              _miniBtn('编辑', Icons.edit_outlined, () => _editCat(c)),
              const Spacer(),
              _miniBtn('删除', Icons.delete_outline_rounded, () async {
                await _svc.deleteJzsCat(_int(c['id']));
                ToastUtil.success('已删除分类及其工具');
                _load();
              }, danger: true),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════ 编辑弹窗 ═══════════

  Future<void> _editTool(Map<String, dynamic>? t) async {
    final isNew = t == null;
    final title = TextEditingController(text: '${t?['title'] ?? ''}');
    final subtitle = TextEditingController(text: '${t?['subtitle'] ?? ''}');
    final icon = TextEditingController(text: '${t?['icon'] ?? ''}');
    final kind = TextEditingController(text: '${t?['kind'] ?? 'local'}');
    final route = TextEditingController(text: '${t?['route'] ?? 'local'}');
    final target = TextEditingController(text: '${t?['target'] ?? ''}');
    final apiUrl = TextEditingController(text: '${t?['api_url'] ?? ''}');
    final weigh = TextEditingController(text: '${t?['weigh'] ?? 0}');
    // ★ 1015：通用接口工具配置（后台配参数就能出工具，不用改 App）
    final apiPath = TextEditingController(text: '${t?['api_path'] ?? ''}');
    final fTitle = TextEditingController(text: '${t?['f_title'] ?? ''}');
    final fSub = TextEditingController(text: '${t?['f_sub'] ?? ''}');
    final fImage = TextEditingController(text: '${t?['f_image'] ?? ''}');
    final fLink = TextEditingController(text: '${t?['f_link'] ?? ''}');
    final fExtra = TextEditingController(text: '${t?['f_extra'] ?? ''}');
    var catId = _int(
      t?['cat_id'] ?? (_cats.isNotEmpty ? _cats.first['id'] : 0),
    );
    var on = t == null || _on(t['enable_switch']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 30,
          ),
          title: Text(isNew ? '新增工具' : '编辑工具'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ddl<String>(
                    '所属分类',
                    _cats.isEmpty ? '（请先建分类）' : null,
                    value: _cats.any((c) => _int(c['id']) == catId)
                        ? '$catId'
                        : (_cats.isNotEmpty ? '${_cats.first['id']}' : '0'),
                    items: [
                      for (final c in _cats) ('${c['id']}', '${c['title']}'),
                    ],
                    onPick: (v) => catId = int.tryParse(v) ?? 0,
                  ),
                  _f('工具名称', title),
                  _f('副标题（列表里的小字）', subtitle),
                  _f('图标 emoji（如 🔥 🎬 🌤️）', icon),
                  _f('kind（决定打开哪个内置页）', kind),
                  _f('route（兼容字段，一般填 local）', route),
                  _f('外部链接 target（kind 未命中时打开）', target),
                  _f('接口地址 api_url（联网工具用）', apiUrl),
                  // ★ 1015：通用接口工具 —— 配好下面 6 项，App 不用改就能出新工具
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 13,
                          decoration: BoxDecoration(
                            color: C.brand,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '通用接口工具（填了就给 App 出界面）',
                          style: Ty.small.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  _f('列表路径 api_path（如 data.list）', apiPath),
                  _f('标题字段 f_title（如 title）', fTitle),
                  _f('副标题字段 f_sub（可空）', fSub),
                  _f('图片字段 f_image（可空）', fImage),
                  _f('链接字段 f_link（可空，点击打开）', fLink),
                  _f('额外字段 f_extra（可空，如热度）', fExtra),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '提示：只填 api_url 不填 api_path → 当作普通外链在 App 内打开；\n'
                      '两个都填 → 用通用列表页渲染（自动解析 JSON、自动兜底路径）',
                      style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
                    ),
                  ),
                  _f('排序权重（越大越靠前）', weigh),
                  Row(
                    children: [
                      Text(
                        '启用',
                        style: TextStyle(fontSize: 13.5, color: ctx.t1),
                      ),
                      const Spacer(),
                      Switch(
                        value: on,
                        activeThumbColor: C.brand,
                        onChanged: (v) => setD(() => on = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: C.brand.withAlpha(16),
                      borderRadius: BorderRadius.circular(R.sm),
                    ),
                    child: Text(
                      'kind 可选：hotsearch 热榜 / news 日报 / epic / earthquake '
                      '/ poem / hitokoto / movie 影视 / music 音乐 / '
                      'shortvideo(或 drama) 短剧 / comic 漫画 / heroes 王者 '
                      '/ wallpaper 壁纸 / translate 翻译 / exchange 汇率 / '
                      'ipquery IP查询 / weather 天气 / qrcode 二维码 / '
                      'stopwatch 秒表 / countdown 倒计时 / unit 单位换算 / '
                      'bmi / loan 房贷 / base64 / random 随机数 / '
                      'password 密码 / relative 亲戚称呼\n'
                      '★ kind 留空或填 local 时，必须填「外部链接 target」，'
                      '否则点开只会提示「暂未开放」。',
                      style: Ty.tiny.copyWith(
                        fontSize: 10.5,
                        color: context.t2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  ToastUtil.error('工具名称不能为空');
                  return;
                }
                final data = <String, dynamic>{
                  'id': _int(t?['id']),
                  'cat_id': catId,
                  'title': title.text.trim(),
                  'subtitle': subtitle.text.trim(),
                  'icon': icon.text.trim(),
                  'kind': kind.text.trim(),
                  'route': route.text.trim(),
                  'target': target.text.trim(),
                  'api_url': apiUrl.text.trim(),
                  'api_path': apiPath.text.trim(),
                  'f_title': fTitle.text.trim(),
                  'f_sub': fSub.text.trim(),
                  'f_image': fImage.text.trim(),
                  'f_link': fLink.text.trim(),
                  'f_extra': fExtra.text.trim(),
                  'weigh': int.tryParse(weigh.text.trim()) ?? 0,
                  'enable_switch': on ? 1 : 0,
                };
                // ★ 1020：保存加 loading，避免点了没反应反复点
                final ok = await AppAction.act(
                  () => _svc.saveJzsTool(data),
                  loading: '保存中…',
                  success: '已保存',
                );
                if (ok) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCat(Map<String, dynamic>? c) async {
    final isNew = c == null;
    final title = TextEditingController(text: '${c?['title'] ?? ''}');
    final hint = TextEditingController(text: '${c?['hint'] ?? ''}');
    final weigh = TextEditingController(text: '${c?['weigh'] ?? 0}');
    var on = c == null || _on(c['enable_switch']);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(isNew ? '新增分类' : '编辑分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _f('分类名称（如「实时热榜」）', title),
              _f('英文副标题（如 Trending）', hint),
              _f('排序权重', weigh),
              Row(
                children: [
                  Text('启用', style: TextStyle(fontSize: 13.5, color: ctx.t1)),
                  const Spacer(),
                  Switch(
                    value: on,
                    activeThumbColor: C.brand,
                    onChanged: (v) => setD(() => on = v),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  ToastUtil.error('分类名称不能为空');
                  return;
                }
                try {
                  await _svc.saveJzsCat({
                    'id': _int(c?['id']),
                    'title': title.text.trim(),
                    'hint': hint.text.trim(),
                    'weigh': int.tryParse(weigh.text.trim()) ?? 0,
                    'enable_switch': on ? 1 : 0,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ToastUtil.success('已保存');
                  _load();
                } catch (e) {
                  ToastUtil.error(ErrText.of(e));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _f(String label, TextEditingController c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: c,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm)),
      ),
    ),
  );

  Widget _ddl<T>(
    String label,
    String? emptyTip, {
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onPick,
  }) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          emptyTip ?? '无选项',
          style: Ty.tiny.copyWith(color: C.warning),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        initialValue: items.any((e) => e.$1 == value) ? value : items.first.$1,
        isDense: true,
        items: [
          for (final it in items)
            DropdownMenuItem(value: it.$1, child: Text(it.$2)),
        ],
        onChanged: (v) => onPick(v ?? ''),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.sm)),
        ),
      ),
    );
  }
}
