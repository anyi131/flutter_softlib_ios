import 'dart:async';

import 'collect_ex_views.dart';
import 'collect_ex_views2.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';
import 'collect_account_card.dart';
import 'collect_dirs_view.dart';
import 'collect_logs_view.dart';
import 'collect_lzy_account_view.dart';

/// 后台 · 采集（版权梦）
///
/// 流程：列出采集平台的软件 → 勾选 → 开始采集
///       → 平台把软件上传到「你自己的蓝奏云」
///       → 完成后拿到蓝奏云链接 → 一键导入你的软件库
class AdminCollectTab extends StatefulWidget {
  const AdminCollectTab({super.key});

  @override
  State<AdminCollectTab> createState() => _AdminCollectTabState();
}

class _AdminCollectTabState extends State<AdminCollectTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final _svc = AdminService.instance;
  final _kwCtrl = TextEditingController();
  late final TabController _sub = TabController(length: 8, vsync: this);

  /// 子页：0=采集 1=目录 2=日志 3=蓝奏云账号
  int get _subIndex => _sub.index;

  bool _loading = true;
  bool _loggedIn = false;
  String _user = '';
  int _page = 1;
  int _totalPages = 1;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selected = {};

  /// ★ 1014 需求4：本地库状态筛选 all/in/out/upd
  String _libFilter = 'all';

  /// 当前页已选数量（勾选计数显示）
  int get _pageSelCount => _items
      .where((it) => _selected.contains((it['appid'] ?? '').toString()))
      .length;

  // 采集任务
  String _taskId = '';
  bool _running = false;
  int _cur = 0, _total = 0, _ok = 0, _fail = 0;
  String _status = '';
  String _err = '';
  int _taskAt = 0;
  int _lastLogCount = 0;
  final ScrollController _logScroll = ScrollController();
  List<String> _pendingNames = [];
  List<Map<String, dynamic>> _results = [];
  List<String> _logs = [];

  /// 重试时保留的上一轮结果（成功的 + 未重试的失败项），避免被新一轮覆盖
  List<Map<String, dynamic>> _retryKept = [];

  /// 最近一次提交的采集参数（重试时按 appname 反查 config_id/dir_id）
  List<Map<String, dynamic>> _lastApps = [];
  Timer? _poll;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sub.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _sub.dispose();
    _logScroll.dispose();
    _kwCtrl.dispose();
    super.dispose();
  }

  /// 把原始异常翻成人话（500 这类要给出可操作的建议）
  String _friendly(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.contains('500')) {
      return '服务器处理出错。可尝试：①点击「重新检测」②退出后重新登录采集账号';
    }
    if (s.contains('登录') || s.contains('Cookie')) return s;
    if (s.contains('timeout') || s.contains('超时')) return '网络超时，请重试';
    return s;
  }

  /// 判断一条采集结果是否成功（兼容 bool / 1 / "1" / "true"）
  bool _isOk(Map<String, dynamic> r) {
    final o = r['ok'];
    return o == true || o == 1 || o == '1' || '${o}'.toLowerCase() == 'true';
  }

  /// 失败原因：上游 msg/reason/error 都没给就给个可操作的话术
  String _failMsg(Map<String, dynamic> r) {
    for (final k in ['msg', 'reason', 'error', 'err']) {
      final v = '${r[k] ?? ''}'.trim();
      if (v.isNotEmpty && v != 'null') return v;
    }
    return '上传失败，可重试';
  }

  /// 当前所有失败的结果项
  List<Map<String, dynamic>> get _failedResults =>
      _results.where((r) => !_isOk(r)).toList();

  /// 清洗站点实时日志：
  /// ① base64 / 不可读乱码行整行丢弃（[A-Za-z0-9+/=]{80,} 长串，或可读占比 <60%）
  /// ② 超长行截断到 300 字符加省略号
  /// ③ 最多保留最近 50 行
  static final RegExp _b64Re = RegExp(r'[A-Za-z0-9+/=]{80,}');
  List<String> _cleanLogs(List<String> raw) {
    final out = <String>[];
    for (final line in raw) {
      final s = line.trim();
      if (s.isEmpty) continue;
      // base64 长串直接丢（不占可读占比判定，先卡掉）
      if (_b64Re.hasMatch(s)) continue;
      // 不可读乱码行（中文 + ASCII 可打印占比过低）丢弃
      if (_readableRatio(s) < 0.6) continue;
      out.add(s.length > 300 ? '${s.substring(0, 300)}…' : s);
    }
    // 只保留最近 50 行
    return out.length > 50 ? out.sublist(out.length - 50) : out;
  }

  /// 可读字符（中英文/数字/常见标点）占比
  double _readableRatio(String s) {
    if (s.isEmpty) return 0;
    var n = 0;
    for (final c in s.codeUnits) {
      if ((c >= 0x20 && c < 0x7f) || c > 0x2e7f) n++; // ASCII 可打印 + CJK
    }
    return n / s.length;
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final cfg = await _svc.collectConfig();
      if (!mounted) return;
      setState(() {
        _loggedIn = cfg['logged_in'] == true || cfg['logged_in'] == 1;
        _totalPages = (cfg['total_pages'] as num?)?.toInt() ?? 1;
        _user = (cfg['collect_user'] ?? '').toString();
        _loading = false;
      });
      if (_loggedIn) await _load();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(_friendly(e));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await _svc.collectList(
        page: _page,
        keyword: _kwCtrl.text.trim(),
      );
      if (!mounted) return;
      final items = ((r['items'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _items = items;
        _totalPages = (r['total_pages'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
      // ★ 1014 需求4：列表接口已带回 in_lib/lib_version/lib_updatetime/update_flag，
      //   只有服务端没带时才需要额外调一次 collect_check 兜底。
      final needCheck =
          items.isNotEmpty && !items.any((e) => e.containsKey('in_lib'));
      if (needCheck) unawaited(_annotateLib(items));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 列表拉取失败不再吞掉、也不再误报「Cookie 过期」
        _err = _friendly(e);
      });
    }
  }

  /// ★ 1014 需求4：批量检测本页软件是否已在本地库，并回填
  ///   in_lib / lib_version / lib_updatetime / update_flag
  Future<void> _annotateLib(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    try {
      final r = await _svc.collectCheck(
        items
            .map(
              (e) => {
                'name': '${e['name'] ?? ''}',
                'version': '${e['version'] ?? ''}',
              },
            )
            .toList(),
      );
      final list = (r['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        for (final raw in list) {
          if (raw is! Map) continue;
          final nm = '${raw['name'] ?? ''}';
          if (nm.isEmpty) continue;
          for (final it in _items) {
            if ('${it['name'] ?? ''}' == nm) {
              it['in_lib'] = raw['in_lib'];
              it['lib_version'] = raw['lib_version'];
              it['lib_updatetime'] = raw['lib_updatetime'];
              it['update_flag'] = raw['update_flag'];
            }
          }
        }
      });
    } catch (_) {
      // 检测失败不影响采集流程，静默
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _items.isEmpty && !_loggedIn) {
      return const LoadingState(text: '加载采集数据…');
    }
    if (!_loggedIn) return _needCookie();
    return Column(
      children: [
        _subBar(),
        Expanded(
          child: IndexedStack(
            index: _subIndex,
            children: [
              _collectPane(),
              const CollectDirsView(),
              const CollectLogsView(),
              const CollectLzyAccountView(),
              // ★ 1016：版权梦功能（软件统计 / 自动采集 / 版权配置 / 全局配置）
              const CollectStatsView(),
              const CollectAutoView(),
              const CollectConfigView(
                sub: 'banquan',
                title: '版权配置',
                subtitle: '版权页开关 / 免责声明 / 按钮 / 分享设置',
              ),
              const CollectConfigView(
                sub: 'quanju',
                title: '全局配置',
                subtitle: '退出软件 / 打开网址 / 启动复制文本等',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 子页切换（分段控件）
  Widget _subBar() {
    // ★ 1016：子页增加到 8 个 → 改横向可滚动（手机一行放不下 8 个）
    const items = ['采集', '目录', '日志', '蓝奏云', '软件统计', '自动采集', '版权配置', '全局配置'];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        6,
      ),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withAlpha(10) : Colors.white,
          borderRadius: BorderRadius.circular(R.full),
          border: Border.all(color: C.stroke),
        ),
        padding: const EdgeInsets.all(3),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: List.generate(items.length, (i) {
            final sel = _subIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _sub.animateTo(i)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: sel ? Deco.brandGradient : null,
                  borderRadius: BorderRadius.circular(R.full),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    items[i],
                    style: Ty.tiny.copyWith(
                      fontSize: 12.5,
                      color: sel ? Colors.white : context.t2,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 采集子页
  Widget _collectPane() {
    return Column(
      children: [
        _toolbar(),
        if (_running || _results.isNotEmpty) _progressCard(),
        Expanded(child: _list()),
      ],
    );
  }

  /// 未登录：引导配置采集账号（账号密码自动登录优先，Cookie 兜底）
  Widget _needCookie() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectAccountCard(
            loggedIn: false,
            totalPages: _totalPages,
            onChanged: _init,
          ),
          const SizedBox(height: 12),
          KitCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: C.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '登录后即可浏览采集平台的软件列表，勾选后一键上传到'
                    '「你自己的蓝奏云」，再把生成的链接导入软件库。',
                    style: Ty.tiny.copyWith(color: context.t3, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        6,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kwCtrl,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: '搜索软件名称…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.full),
                    ),
                  ),
                  onSubmitted: (_) {
                    _page = 1;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              SoftButton(
                label: '搜索',
                height: 42,
                onPressed: () {
                  _page = 1;
                  _load();
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _init,
                icon: Icon(Icons.refresh_rounded, color: context.t2, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '第 $_page / $_totalPages 页 · 共 ${_items.length} 条',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
              const Spacer(),
              if (_selected.isNotEmpty) ...[
                Text(
                  _pageSelCount > 0 && _pageSelCount != _selected.length
                      ? '本页已选 $_pageSelCount · 跨页共选 ${_selected.length}'
                      : '已选 ${_selected.length}',
                  style: Ty.tiny.copyWith(color: C.brand),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(_selected.clear),
                  child: Text('清空', style: Ty.tiny.copyWith(color: C.danger)),
                ),
                const SizedBox(width: 10),
              ],
              GestureDetector(
                onTap: _selectAllMatched,
                child: Text(
                  '全选本页',
                  style: Ty.tiny.copyWith(
                    color: C.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // ★ 1014 需求4：本地库状态筛选 + 手动重新检测
          Row(
            children: [
              for (final f in const [
                ('all', '全部'),
                ('in', '已在库'),
                ('out', '未入库'),
                ('upd', '可更新'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _libFilter = f.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _libFilter == f.$1
                            ? C.brand
                            : (context.isDark ? C.bg2 : Colors.white),
                        borderRadius: BorderRadius.circular(R.full),
                        border: Border.all(
                          color: _libFilter == f.$1
                              ? C.brand
                              : (context.isDark
                                    ? Colors.white.withAlpha(20)
                                    : Colors.black.withAlpha(10)),
                        ),
                      ),
                      child: Text(
                        f.$2,
                        style: Ty.tiny.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _libFilter == f.$1 ? Colors.white : context.t2,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _annotateLib(_items),
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 13, color: C.brand),
                    const SizedBox(width: 3),
                    Text(
                      '重新检测',
                      style: Ty.tiny.copyWith(
                        color: C.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ★ 1014 需求4：按本地库状态过滤
  List<Map<String, dynamic>> get _visibleItems {
    switch (_libFilter) {
      case 'in':
        return _items.where((e) => '${e['in_lib'] ?? 0}' == '1').toList();
      case 'out':
        return _items.where((e) => '${e['in_lib'] ?? 0}' != '1').toList();
      case 'upd':
        return _items
            .where((e) => '${e['update_flag'] ?? ''}' == 'updatable')
            .toList();
      default:
        return _items;
    }
  }

  void _selectAllMatched() {
    setState(() {
      for (final it in _items) {
        if (it['matched'] == true) {
          _selected.add((it['appid'] ?? '').toString());
        }
      }
    });
  }

  Widget _list() {
    if (_err.isNotEmpty) {
      return ErrorState(text: '采集数据加载失败', hint: _err, onRetry: _load);
    }
    if (_items.isEmpty) {
      return EmptyState(
        text: '没有采集到数据',
        hint: '可能是 Cookie 已过期，请重新登录采集账号',
        icon: Icons.cloud_download_outlined,
        action: SoftButton(label: '重新检测', onPressed: _init),
      );
    }
    final visible = _visibleItems;
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              context.pagePadding,
              4,
              context.pagePadding,
              12,
            ),
            itemCount: visible.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              // 列表头：采集账号入口（点开可改账号/重新登录）
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _accountEntry(),
                );
              }
              // ★ 1014 需求4：筛选后可见列表
              if (visible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      '当前筛选下没有软件',
                      style: Ty.small.copyWith(color: context.t3),
                    ),
                  ),
                );
              }
              return _itemCard(visible[i - 1]);
            },
          ),
        ),
        _pager(),
        _bottomBar(),
      ],
    );
  }

  /// 已登录时的账号入口条（收起状态，点开抽屉里的完整设置）
  Widget _accountEntry() {
    return KitCard(
      radius: R.md,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: _showAccountSheet,
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, size: 17, color: C.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _user.isEmpty ? '采集账号已登录' : '采集账号：$_user',
              style: Ty.tiny.copyWith(color: context.t2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '账号设置',
            style: Ty.tiny.copyWith(
              color: C.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: C.brand),
        ],
      ),
    );
  }

  void _showAccountSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.isDark ? C.bg2 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(R.lg)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('采集账号设置', style: Ty.h3.copyWith(color: ctx.t1)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: ctx.t2),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              CollectAccountCard(
                loggedIn: _loggedIn,
                totalPages: _totalPages,
                onChanged: () {
                  Navigator.pop(ctx);
                  _init();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> it) {
    final appid = (it['appid'] ?? '').toString();
    final matched = it['matched'] == true;
    final sel = _selected.contains(appid);
    // ★ 1014 需求4：本地软件库状态
    final inLib = '${it['in_lib'] ?? 0}' == '1';
    final libVer = '${it['lib_version'] ?? ''}';
    final libDate = '${it['lib_updatetime'] ?? ''}';
    final flag = '${it['update_flag'] ?? ''}';
    // 本地库版本比采集源新 / 可更新
    final libNewer = flag == 'lib_newer';
    final updatable = flag == 'updatable';
    return KitCard(
      radius: R.md,
      padding: const EdgeInsets.all(11),
      onTap: matched
          ? () => setState(() {
              if (sel) {
                _selected.remove(appid);
              } else {
                _selected.add(appid);
              }
            })
          : () => ToastUtil.info('该软件未匹配到蓝奏云目录，无法采集'),
      child: Row(
        children: [
          Opacity(
            opacity: matched ? 1 : 0.4,
            child: Icon(
              sel
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: sel ? C.brand : context.t3,
            ),
          ),
          const SizedBox(width: 10),
          AppImage(
            url: (it['logo'] ?? '').toString(),
            width: 42,
            height: 42,
            radius: R.sm,
            placeholderIcon: Icons.android,
            errorIcon: Icons.android,
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
                        (it['name'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ty.h3.copyWith(fontSize: 14, color: context.t1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // ★ 1014 需求4：是否已在本地软件库
                    Pill(
                      !inLib
                          ? '未入库'
                          : (updatable ? '可更新' : (libNewer ? '库内已更新' : '已在库')),
                      color: !inLib
                          ? C.t3
                          : (updatable
                                ? C.warning
                                : (libNewer ? C.cyan : C.success)),
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'v${it['version'] ?? ''} · ${it['size'] ?? ''} · ${it['category'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(color: context.t3),
                ),
                // ★ 1014 需求4：显示本地库里的版本与上传时间
                if (inLib && (libVer.isNotEmpty || libDate.isNotEmpty)) ...[
                  const SizedBox(height: 3),
                  Text(
                    '库内 v$libVer'
                    '${libDate.isEmpty ? '' : ' · 上传 $libDate'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ty.tiny.copyWith(color: C.success.withAlpha(200)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Pill(
            matched ? ((it['config_name'] ?? '').toString()) : '未匹配',
            color: matched ? C.mint : C.warning,
            small: true,
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SoftButton(
            label: '上一页',
            height: 36,
            color: _page > 1 ? C.brand : context.t3,
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : () {},
          ),
          const SizedBox(width: 14),
          Text(
            '$_page / $_totalPages',
            style: Ty.small.copyWith(color: context.t2),
          ),
          const SizedBox(width: 14),
          SoftButton(
            label: '下一页',
            height: 36,
            color: _page < _totalPages ? C.brand : context.t3,
            onPressed: _page < _totalPages
                ? () {
                    _page++;
                    _load();
                  }
                : () {},
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    // 当前页已选（真正会被采集的数量）
    final pageCount = _pageSelCount;
    final label = _selected.isEmpty
        ? '请选择要采集的软件'
        : (pageCount == _selected.length
              ? '开始采集（$pageCount）'
              : '开始采集本页（$pageCount） · 跨页共选 ${_selected.length}');
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.pagePadding,
          6,
          context.pagePadding,
          10,
        ),
        child: PrimaryButton(
          label: label,
          icon: Icons.cloud_upload_rounded,
          height: 48,
          // ★ 只有「本页有勾选」才可开始：跨页残留的勾选不会提交
          enabled: pageCount > 0 && !_running,
          onPressed: _start,
        ),
      ),
    );
  }

  /// 按软件名反查上一轮提交时的采集参数（重试用）
  Map<String, dynamic>? _appForName(String name) {
    for (final a in _lastApps) {
      if ('${a['appname'] ?? ''}' == name) return a;
    }
    return null;
  }

  /// 重试单条失败项：复用采集提交链路，只提交这一条
  Future<void> _retryOne(Map<String, dynamic> r) async {
    if (_running) return;
    final name = '${r['name']}';
    final app = _appForName(name);
    if (app == null) {
      ToastUtil.error('找不到该软件的采集参数，请回列表重新勾选采集');
      return;
    }
    // 保留上一轮所有结果，除了正在重试的这一条（避免被新一轮覆盖）
    final keep = _results.where((x) => '${x['name']}' != name).toList();
    await _submitCollect([app], keep: keep);
  }

  /// 批量重试全部失败项
  Future<void> _retryFailed() async {
    if (_running) return;
    final failed = _failedResults;
    if (failed.isEmpty) return;
    final apps = <Map<String, dynamic>>[];
    final failedNames = <String>{};
    for (final r in failed) {
      final app = _appForName('${r['name']}');
      if (app != null) {
        apps.add(app);
        failedNames.add('${r['name']}');
      }
    }
    if (apps.isEmpty) {
      ToastUtil.error('找不到失败软件的采集参数，请回列表重新勾选采集');
      return;
    }
    // 保留上一轮成功的结果；没找到参数的失败项也保留（提示过用户了）
    final keep = _results
        .where((x) => _isOk(x) || !failedNames.contains('${x['name']}'))
        .toList();
    await _submitCollect(apps, keep: keep);
  }

  /// 采集提交（开始采集与失败重试共用）：提交任务 → 清空状态 → 开始轮询
  /// [keep] 为重试场景要保留的上一轮结果（成功的 + 不重跑的失败项）
  Future<void> _submitCollect(
    List<Map<String, dynamic>> apps, {
    List<Map<String, dynamic>> keep = const [],
  }) async {
    try {
      final taskId = await _svc.collectStart(apps);
      if (taskId.isEmpty) {
        ToastUtil.error('任务提交失败');
        return;
      }
      setState(() {
        _taskId = taskId;
        _running = true;
        _cur = 0;
        _total = apps.length;
        _ok = 0;
        _fail = 0;
        _status = '';
        _results = List.of(keep);
        _retryKept = List.of(keep);
        _logs = [];
        _lastLogCount = 0;
        // 记录本次要采集的软件名（完成后到日志页反查链接用）
        _pendingNames = apps
            .map((a) => '${a['appname'] ?? ''}')
            .where((s) => s.isNotEmpty)
            .toList();
      });
      _startPoll();
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _start() async {
    // ★ 需求 #5：跨页勾选只用于「计数展示」，
    //   真正提交采集的始终只有【当前页面】勾选的软件
    final apps = _items
        .where((it) => _selected.contains((it['appid'] ?? '').toString()))
        .map(
          (it) => {
            'appid': it['appid'],
            'appname': it['name'],
            'config_id': it['config_id'],
            'dir_id': it['dir_id'],
            'config_name': it['config_name'],
            'is_fallback': it['is_fallback'],
          },
        )
        .toList();
    if (apps.isEmpty) return;
    _lastApps = apps;
    // ★ 重试场景：新一轮只提交了部分软件（失败项）时，
    //   保留上一轮「不在本次提交名单里」的结果，避免被清空覆盖
    final retryNames = apps.map((a) => '${a['appname'] ?? ''}').toSet();
    _retryKept = _results
        .where((r) => !retryNames.contains('${r['name']}'))
        .toList();
    final extra = _selected.length - apps.length;
    final go = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('开始采集'),
        content: Text(
          '本次将采集【当前页】选中的 ${apps.length} 个软件，上传到'
          '【你自己的蓝奏云】目录，完成后可一键导入软件库。'
          '${extra > 0 ? '\n\n另外 $extra 个是其它页面的勾选，本次不会提交。' : ''}'
          '\n\n是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('开始'),
          ),
        ],
      ),
    );
    if (go != true) return;
    _lastApps = apps;
    await _submitCollect(apps);
  }

  void _startPoll() {
    _poll?.cancel();
    _taskAt = DateTime.now().millisecondsSinceEpoch;
    int expiredTicks = 0;

    _poll = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (_taskId.isEmpty) {
        t.cancel();
        return;
      }
      try {
        final r = await _svc.collectStatus(_taskId);
        if (!mounted) return;

        // 任务记录已被站点清理（任务早已结束）
        if (r['expired'] == true) {
          expiredTicks++;
          if (expiredTicks >= 2 || !_running) {
            t.cancel();
            await _finishFromLog();
          }
          return;
        }
        expiredTicks = 0;

        setState(() {
          _status = (r['status'] ?? '').toString();
          _total = (r['total'] as num?)?.toInt() ?? _total;
          _cur = (r['current'] as num?)?.toInt() ?? _cur;
          _ok = (r['success'] as num?)?.toInt() ?? _ok;
          _fail = (r['fail'] as num?)?.toInt() ?? _fail;
          // ★ 重试时保留上一轮结果（成功的 + 未重试的失败项）
          final fresh = ((r['results'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _results = [..._retryKept, ...fresh];
          // ★ 站点每 2 秒返回真实进度日志，直接展示，用户能实时看到在干什么
          //   （先清洗：超长截断 / 丢不可读与 base64 乱码行 / 最多保留 50 行）
          _logs = _cleanLogs(
            ((r['logs'] as List?) ?? []).map((e) => e.toString()).toList(),
          );
        });
        // 有新日志就自动滚到底部，保证最新一条始终可见
        if (_logs.length != _lastLogCount) {
          _lastLogCount = _logs.length;
          _scrollLogToEnd();
        }
        // 一旦站点给了结果，立刻刷新成功数（不要等任务结束）
        if (_results.isNotEmpty && _ok != _results.where(_isOk).length) {
          setState(() {
            _ok = _results.where(_isOk).length;
          });
        }

        // 进度满了就说明该完成的都完成了（站点可能稍后才给 done）
        if (_status == 'done' ||
            (_results.isNotEmpty && _cur >= _total && _total > 0)) {
          t.cancel();
          await _finishFromLog();
        }
      } catch (e) {
        // 单次查询失败不中断，继续轮询
      }
    });
  }

  /// ★ 任务结束后从站点「采集日志」按软件名反查蓝奏云链接
  ///   （站点 task_status 不返回已完成任务的 results，这是唯一可靠的取法）
  Future<void> _finishFromLog() async {
    final names = _pendingNames.isNotEmpty
        ? _pendingNames
        : _results.map((r) => '${r['name']}').toList();
    // ★ 先保住已经拿到的真实结果：站点 done 时会直接带 results，
    //   这些数据比「事后去日志反查」可靠得多，绝不能被覆盖成失败
    final known = _results.where(_isOk).toList();
    try {
      final r = await _svc.collectResults(names, at: _taskAt);
      if (!mounted) return;
      final fetched = ((r['results'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // 合并：已有成功结果优先，再用反查结果补齐还没拿到的；
      // v52i #3：字段级补全 —— 站点 results 往往只有 name/url/desc，
      // 反查结果（collect_results）带 size/version/logo/preview，空的都填上
      final merged = <Map<String, dynamic>>[];
      final used = <String>{};
      for (final k in known) {
        merged.add(k);
        used.add('${k['name']}');
      }
      for (final f in fetched) {
        final n = '${f['name']}';
        // 命中已有结果 → 只补空字段（size/version/logo/preview/category）
        if (used.contains(n)) {
          final ki = merged.indexWhere((e) => '${e['name']}' == n);
          if (ki >= 0) {
            for (final fk in [
              'size',
              'version',
              'logo',
              'preview',
              'category',
            ]) {
              final cur = '${merged[ki][fk] ?? ''}';
              final inc = '${f[fk] ?? ''}';
              if (cur.isEmpty && inc.isNotEmpty) merged[ki][fk] = inc;
            }
            if ('${merged[ki]['desc'] ?? ''}'.trim().length < 8 &&
                '${f['desc'] ?? ''}'.trim().length > 8) {
              merged[ki]['desc'] = f['desc'];
            }
          }
          continue;
        }
        merged.add(f);
        used.add(n);
      }
      // 一个都没拿到 → 保留原有 results，不要凭空造失败
      if (merged.isEmpty && _results.isNotEmpty) {
        setState(() {
          _running = false;
          _status = 'done';
        });
        return;
      }
      final list = merged.isEmpty ? fetched : merged;
      setState(() {
        _running = false;
        _status = 'done';
        if (list.isNotEmpty) {
          _results = list;
          _ok = list.where(_isOk).length;
          _fail = list.where((x) => !_isOk(x)).length;
          // 进度只增不减，避免把已经跑满的进度条退回去
          _cur = list.length > _cur ? list.length : _cur;
          _total = _cur > _total ? _cur : _total;
        }
      });
      if (_ok > 0) {
        ToastUtil.success('采集完成：成功 $_ok，失败 $_fail');
      } else {
        ToastUtil.info('任务已结束，可到「日志」子页查看结果链接');
      }
    } catch (e) {
      if (!mounted) return;
      // 反查失败也不能抹掉已有的成功结果
      setState(() {
        _running = false;
        _status = 'done';
        _ok = known.length;
        _fail = known.isEmpty && _total > 0 ? _total - _ok : _fail;
      });
      if (known.isNotEmpty) {
        ToastUtil.success('采集完成：成功 ${known.length}');
      } else {
        ToastUtil.info('任务已提交，请到「日志」子页查看结果链接');
      }
    }
  }

  Widget _progressCard() {
    final pct = _total > 0 ? (_cur / _total).clamp(0.0, 1.0) : 0.0;
    final doneLinks = _results.where((r) => r['ok'] == true).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        4,
        context.pagePadding,
        4,
      ),
      child: KitCard(
        radius: R.md,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_running)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.check_circle_rounded, size: 17, color: C.success),
                const SizedBox(width: 8),
                Text(
                  _running ? '正在上传到你的蓝奏云…' : '采集结束',
                  style: Ty.h3.copyWith(fontSize: 13.5, color: context.t1),
                ),
                const Spacer(),
                Text(
                  '$_cur/$_total',
                  style: Ty.small.copyWith(color: context.t2),
                ),
              ],
            ),
            const SizedBox(height: 9),
            KitProgress(value: pct, color: _running ? C.brand : C.success),
            const SizedBox(height: 7),
            Row(
              children: [
                _miniStat('成功', _ok, C.success),
                const SizedBox(width: 14),
                _miniStat('失败', _fail, C.danger),
                const SizedBox(width: 14),
                _miniStat('总数', _total, C.brand),
                const Spacer(),
                if (_running)
                  GestureDetector(
                    onTap: _finishFromLog,
                    child: Text(
                      '立即取结果',
                      style: Ty.tiny.copyWith(
                        color: C.brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            // ★ 站点每 2 秒返回的真实进度日志 —— 直接展示，用户能看到在干什么
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 13, color: context.t3),
                  const SizedBox(width: 5),
                  Text(
                    '实时日志',
                    style: Ty.tiny.copyWith(
                      color: context.t2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(
                height: 132,
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? Colors.black38
                      : const Color(0xFF10131C),
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                // ★ 用 ScrollController 自动滚到底部，新日志自动可见
                child: _logView(),
              ),
            ],
            if (doneLinks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '已生成蓝奏云链接（${doneLinks.length}）',
                style: Ty.tiny.copyWith(
                  color: context.t2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...doneLinks
                  .take(8)
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 13,
                            color: C.success,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${r['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.tiny.copyWith(color: context.t1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: '导入软件库（${doneLinks.length}）',
                icon: Icons.download_done_rounded,
                height: 42,
                onPressed: () => _import(doneLinks),
              ),
            ],
            // ★ 失败分组：结束后展示失败软件 + 原因，可单条或批量重试
            if (!_running && _failedResults.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: C.danger),
                  const SizedBox(width: 5),
                  Text(
                    '失败（${_failedResults.length}）',
                    style: Ty.tiny.copyWith(
                      color: C.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _retryFailed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: C.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(R.sm),
                      ),
                      child: Text(
                        '重试失败项（${_failedResults.length}）',
                        style: Ty.tiny.copyWith(
                          color: C.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ..._failedResults.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.cancel_outlined,
                          size: 13,
                          color: C.danger,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.tiny.copyWith(color: context.t1),
                            ),
                            Text(
                              _failMsg(r),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Ty.tiny.copyWith(
                                fontSize: 10.5,
                                color: context.isDark
                                    ? C.danger.withValues(alpha: 0.85)
                                    : C.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _retryOne(r),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '重试',
                            style: Ty.tiny.copyWith(
                              color: C.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!_running && _logs.isEmpty && doneLinks.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '任务已结束，可到「日志」子页查看结果链接。',
                style: Ty.tiny.copyWith(color: context.t3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 实时日志窗口：新日志自动滚到底部
  Widget _logView() {
    return ListView.builder(
      controller: _logScroll,
      padding: EdgeInsets.zero,
      itemCount: _logs.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text(
          _logs[i],
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.5,
            fontFamily: 'monospace',
            color: Color(0xFF9FE8B5),
          ),
        ),
      ),
    );
  }

  /// 收到新日志后滚到底部（延迟一帧等布局完成）
  void _scrollLogToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScroll.hasClients) return;
      _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  Widget _miniStat(String label, int v, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$v',
        style: Ty.small.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      const SizedBox(width: 3),
      Text(label, style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3)),
    ],
  );

  Future<void> _import(List<Map<String, dynamic>> results) async {
    // ★ 把站点给的完整信息都带上：之前只传 name/url/desc/category，
    //   导致导入后 图标/大小/版本 全为空、描述带脏字符。
    //   ★ 现在再补上 preview（应用截图）——这也是用户反馈「截图没导入」的原因。
    final items = results
        .map(
          (r) => {
            'name': r['name'],
            'url': r['url'],
            'desc': r['desc'],
            'category': r['category'],
            'logo': r['logo'] ?? '',
            'size': r['size'] ?? '',
            'version': r['version'] ?? '',
            'preview': r['preview'] ?? r['screenshots'] ?? '',
          },
        )
        .toList();
    if (items.isEmpty) return;
    // ★ 导入前批量设置 分类 / 会员下载（对应「采集入库前批量设置」需求）
    final batch = await _pickBatchSettings();
    if (batch == null) return; // 用户取消
    // 导入前让用户确认/修改数据（对应需求 #10）
    final edited = await _editBeforeImport(items);
    if (edited == null || edited.isEmpty) return;
    try {
      final r = await _svc.collectImport(
        edited,
        catId: batch['cat_id'] as int?,
        isVip: batch['is_vip'] as int?,
        vipPrice: batch['vip_price'] as String?,
      );
      ToastUtil.success('已导入 ${r['added']} 条，跳过重复 ${r['skipped']} 条');
      setState(() {
        _results = [];
        _logs = [];
      });
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// ★ 导入前批量设置：分类（可跳过=保持默认）+ 会员下载/价格
  /// 返回 {cat_id?, is_vip?, vip_price?}；null=取消导入
  Future<Map<String, dynamic>?> _pickBatchSettings() async {
    List<Map<String, dynamic>> cats = [];
    try {
      cats = await _svc.appCats();
    } catch (_) {}
    int? catId; // null = 不设置（走服务端默认）
    bool isVip = false;
    final price = TextEditingController();
    final go = await Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: StatefulBuilder(
          builder: (ctx, setD) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '批量设置（导入前）',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '为本次导入的软件统一设置分类与下载权限',
                style: Ty.tiny.copyWith(color: ctx.t3),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: catId,
                decoration: const InputDecoration(
                  labelText: '所属分类（不选=未分类）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不设置')),
                  const DropdownMenuItem(value: 0, child: Text('未分类')),
                  ...cats.map(
                    (c) => DropdownMenuItem(
                      value: int.tryParse('${c['id']}') ?? 0,
                      child: Text('${c['title']}'),
                    ),
                  ),
                ],
                onChanged: (v) => setD(() => catId = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 18,
                    color: C.gold,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('会员专享')),
                  Switch(
                    value: isVip,
                    activeThumbColor: C.gold,
                    onChanged: (v) => setD(() => isVip = v),
                  ),
                ],
              ),
              if (isVip)
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '会员价 / 购买价（¥，可留空）',
                    isDense: true,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      child: const Text('取消导入'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Get.back(result: true),
                      child: const Text('下一步'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true) return null;
    return {
      if (catId != null) 'cat_id': catId,
      'is_vip': isVip ? 1 : 0,
      if (isVip) 'vip_price': price.text.trim(),
    };
  }

  /// 导入前编辑：逐条可修改名称/大小/版本/分类/截图，避免脏数据入库
  /// 返回 null 表示用户取消
  Future<List<Map<String, dynamic>>?> _editBeforeImport(
    List<Map<String, dynamic>> items,
  ) async {
    final List<Map<String, dynamic>> draft = items
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return await Get.dialog<List<Map<String, dynamic>>>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: StatefulBuilder(
            builder: (ctx, setD) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: C.brand, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        '导入前确认',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '共 ${draft.length} 条',
                        style: Ty.tiny.copyWith(color: ctx.t3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '可直接修改名称/大小/版本/截图，确认后写入软件库',
                    style: Ty.tiny.copyWith(color: ctx.t3),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: draft.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _importRow(draft, i, setD),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            // 过滤掉名称为空的
                            final ok = draft
                                .where(
                                  (e) => (e['name'] ?? '')
                                      .toString()
                                      .trim()
                                      .isNotEmpty,
                                )
                                .toList();
                            Navigator.pop(ctx, ok);
                          },
                          child: const Text('确认导入'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _importRow(
    List<Map<String, dynamic>> draft,
    int i,
    void Function(void Function()) setD,
  ) {
    final it = draft[i];
    final shots = (it['preview'] ?? '').toString();
    final shotCount = shots.trim().isEmpty
        ? 0
        : shots.split(',').where((s) => s.trim().isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        // v52f #7：浅色模式用浅灰底（C.bg2 是深色板，之前黑块就是这来的）
        color: context.isDark
            ? Colors.white.withAlpha(8)
            : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withAlpha(18)
              : Colors.black.withAlpha(14),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _miniField(
                  '名称',
                  (it['name'] ?? '').toString(),
                  (v) => setD(() => it['name'] = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 95,
                child: _miniField(
                  '分类',
                  (it['category'] ?? '').toString(),
                  (v) => setD(() => it['category'] = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: _miniField(
                  '大小',
                  (it['size'] ?? '').toString(),
                  (v) => setD(() => it['size'] = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: _miniField(
                  '版本',
                  (it['version'] ?? '').toString(),
                  (v) => setD(() => it['version'] = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '应用截图',
                      style: Ty.tiny.copyWith(fontSize: 10, color: context.t3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shotCount > 0 ? '已带 $shotCount 张' : '无',
                      style: Ty.tiny.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: shotCount > 0 ? C.mint : C.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 弹窗内的小输入框（内联保存）
  Widget _miniField(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Ty.tiny.copyWith(fontSize: 10, color: context.t3)),
        const SizedBox(height: 3),
        SizedBox(
          height: 34,
          child: TextFormField(
            initialValue: value,
            onChanged: onChanged,
            style: TextStyle(fontSize: 12.5, color: context.t1),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
