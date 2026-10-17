import 'package:flutter/material.dart';
import '../../../utils/err_text.dart';

import '../admin_ui_kit.dart';

import 'package:get/get.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/toast_util.dart';

/// 后台 · 操作日志
///
/// 展示每个用户的操作记录，含 IP 归属地、手机型号、系统版本。
/// 支持按关键词搜索、按动作筛选、查看单用户详情。
class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({super.key});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  final _svc = AdminService.instance;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _hasMore = false;
  int _page = 1;
  String _kw = '';
  String _action = '';
  // ★ 1016：错误日志模式（崩溃/下载/解析等异常）
  bool _errMode = false;
  List<Map<String, dynamic>> _errList = [];

  static const _actions = <String, String>{
    '': '全部',
    'login': '登录',
    'register': '注册',
    'post': '发帖',
    'comment': '评论',
    'buy': '购买',
    'download': '下载',
  };

  static const _actionIcons = <String, IconData>{
    'login': Icons.login_rounded,
    'register': Icons.person_add_rounded,
    'post': Icons.article_rounded,
    'comment': Icons.mode_comment_rounded,
    'buy': Icons.shopping_bag_rounded,
    'download': Icons.download_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      if (mounted) setState(() => _loading = true);
    }
    try {
      final r = await _svc.opLogs(keyword: _kw, action: _action, page: _page);
      final list = ((r['list'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _list = list;
        } else {
          _list = [..._list, ...list];
        }
        _hasMore = r['has_more'] == true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  /// ★ 1016：加载错误/崩溃日志（含今日分类统计）
  Future<void> _loadErrors({bool reset = true}) async {
    if (reset && mounted) setState(() => _loading = true);
    try {
      final r = await _svc.errorLogs(page: 1, size: 60);
      final list = ((r['list'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _errList = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ★ 1016：操作日志 / 错误日志 切换
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            children: [
              _modeTab('操作日志', !_errMode, () {
                if (_errMode) {
                  setState(() => _errMode = false);
                  _load(reset: true);
                }
              }),
              const SizedBox(width: 8),
              _modeTab('错误日志', _errMode, () {
                if (!_errMode) {
                  setState(() => _errMode = true);
                  _loadErrors();
                }
              }),
            ],
          ),
        ),
        if (!_errMode) ...[
        // 搜索 + 筛选
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onSubmitted: (v) {
                          _kw = v.trim();
                          _load(reset: true);
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '搜索昵称 / IP / 设备',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(R.md),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '清理日志',
                    icon: const Icon(
                      Icons.cleaning_services_rounded,
                      size: 20,
                      color: C.warning,
                    ),
                    onPressed: () async {
                      // ★ 需求 #6：区分「清理30天前」和「清空全部」
                      //   （以前只有 30 天前，用户点完发现最近日志还在，以为没清）
                      final mode = await Get.dialog<String>(
                        AlertDialog(
                          title: const Text('清理日志'),
                          content: const Text('请选择清理方式：'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Get.back(result: 'days'),
                              child: const Text('清理 30 天前'),
                            ),
                            FilledButton(
                              onPressed: () => Get.back(result: 'all'),
                              child: Text(
                                '清空全部',
                                style: TextStyle(color: C.danger),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (mode == null) return;
                      try {
                        await _svc.clearOpLogs(days: 30, all: mode == 'all');
                        ToastUtil.success(mode == 'all' ? '已清空全部日志' : '已清理');
                        _load(reset: true);
                      } catch (e) {
                        ToastUtil.error(
                          ErrText.of(e),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _actions.entries.map((e) {
                    final sel = _action == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _action = e.key);
                          _load(reset: true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? C.brand
                                : (context.isDark
                                      ? Colors.white.withAlpha(12)
                                      : Colors.black.withAlpha(6)),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: sel
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: sel ? Colors.white : context.t2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        ],
        if (_errMode)
          Expanded(
            child: _loading
                ? const LoadingState(text: '加载错误日志…')
                : (_errList.isEmpty
                      ? const EmptyState(
                          text: '暂无错误记录',
                          hint: 'App 崩溃、下载失败、解析失败会自动上报到这里',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadErrors,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                            itemCount: _errList.length,
                            itemBuilder: (context, i) =>
                                _errCard(_errList[i]),
                          ),
                        )),
          ),
        if (!_errMode)
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载操作日志…')
              : (_list.isEmpty
                    ? const EmptyState(
                        text: '暂无操作日志',
                        hint: '用户登录、发帖、购买等操作会记录在这里',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                          itemCount: _list.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _list.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      _page++;
                                      _load();
                                    },
                                    child: const Text('加载更多'),
                                  ),
                                ),
                              );
                            }
                            return _logCard(_list[i]);
                          },
                        ),
                      )),
        ),
      ],
    );
  }

  /// ★ 1016：日志详情（完整字段：UA / 设备 / 归属地 / 时间）
  void _showLogDetail(Map<String, dynamic> r) {
    final action = '${r['action'] ?? ''}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('日志详情',
                        style: Ty.h3.copyWith(fontSize: 15, color: context.t1)),
                  ),
                  Pill(_actions[action] ?? action, small: true),
                ],
              ),
              const SizedBox(height: 12),
              AdKvList(rows: [
                ('用户', '${r['nickname'] ?? '游客'}（ID ${r['user_id'] ?? 0}）'),
                ('行为', _actions[action] ?? action),
                ('详情', '${r['detail'] ?? '-'}'),
                ('时间', '${r['createtime_text'] ?? r['time_text'] ?? '-'}'),
                ('IP', '${r['ip'] ?? '-'}'),
                ('归属地', '${r['address'] ?? '-'}'),
                ('设备', '${r['device'] ?? '-'}'),
                ('系统', '${r['os'] ?? '-'}'),
                if ('${r['ua'] ?? ''}'.isNotEmpty) ('UA', '${r['ua']}'),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SoftButton(
                  label: '关闭',
                  onPressed: () => Navigator.pop(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 模式切换小标签
  Widget _modeTab(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? C.brand : (context.isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6)),
          borderRadius: BorderRadius.circular(R.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
            color: sel ? Colors.white : context.t2,
          ),
        ),
      ),
    );
  }

  /// ★ 1016：错误日志卡片（点开看完整错误与堆栈）
  Widget _errCard(Map<String, dynamic> r) {
    final tag = '${r['tag'] ?? ''}';
    final isCrash = ['crash', 'FlutterError', 'PlatformDispatcher', 'ErrorWidget', 'zone', 'startup'].contains(tag);
    final color = isCrash ? C.rose : C.warning;
    final icon = isCrash ? Icons.bug_report_rounded : Icons.warning_amber_rounded;
    return AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => _showErrDetail(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDark ? 40 : 26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(tag,
                    style: Ty.h3.copyWith(fontSize: 13.5, color: context.t1)),
              ),
              Pill('${r['time_text'] ?? ''}', color: color, small: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${r['error'] ?? ''}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Ty.small.copyWith(fontSize: 12.5, color: context.t2, height: 1.45),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.smartphone_rounded, size: 12, color: context.t3),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${r['device'] ?? '-'} · v${r['version'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
                ),
              ),
              Text('${r['ip'] ?? ''}',
                  style: Ty.tiny.copyWith(fontSize: 11, color: context.t3)),
            ],
          ),
        ],
      ),
    );
  }

  /// ★ 1016：错误详情（完整错误 + 堆栈，可复制）
  void _showErrDetail(Map<String, dynamic> r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: BoxDecoration(
          color: context.isDark ? C.bg2 : Colors.white,
          borderRadius: BorderRadius.circular(R.lg),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('错误详情',
                        style: Ty.h3.copyWith(fontSize: 15, color: context.t1)),
                  ),
                  Pill('${r['tag'] ?? ''}', small: true),
                ],
              ),
              const SizedBox(height: 12),
              AdKvList(rows: [
                ('时间', '${r['time_text'] ?? '-'}'),
                ('设备', '${r['device'] ?? '-'}'),
                ('版本', '${r['version'] ?? '-'}'),
                ('IP', '${r['ip'] ?? '-'}'),
                ('用户ID', '${r['user_id'] ?? 0}'),
              ]),
              const SizedBox(height: 12),
              Text('错误内容',
                  style: Ty.small.copyWith(fontSize: 12, color: context.t3)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(R.sm),
                ),
                child: SelectableText('${r['error'] ?? ''}',
                    style: TextStyle(fontSize: 12, color: context.t1, height: 1.5)),
              ),
              if ('${r['stack'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('堆栈',
                    style: Ty.small.copyWith(fontSize: 12, color: context.t3)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText('${r['stack']}',
                        style: TextStyle(fontSize: 11, color: context.t2, height: 1.45)),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SoftButton(
                  label: '关闭',
                  onPressed: () => Navigator.pop(c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> r) {
    final action = '${r['action'] ?? ''}';
    final label = _actions[action] ?? action;
    final icon = _actionIcons[action] ?? Icons.circle_outlined;
    final color = action == 'login'
        ? C.brand
        : action == 'register'
        ? C.mint
        : action == 'buy'
        ? C.gold
        : action == 'comment' || action == 'post'
        ? C.violet
        : C.cyan;

    return AdCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => _showLogDetail(r), // ★ 1016：点开看完整信息
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(context.isDark ? 40 : 26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${r['nickname'] ?? '游客'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ty.h3.copyWith(fontSize: 13.5, color: context.t1),
                ),
              ),
              Pill(label, color: color, small: true),
            ],
          ),
          if ('${r['detail'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${r['detail']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Ty.small.copyWith(fontSize: 12.5, color: context.t2),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 5,
            children: [
              _meta(Icons.access_time_rounded, '${r['createtime_text'] ?? ''}'),
              _meta(
                Icons.location_on_outlined,
                '${r['ip'] ?? ''}${(r['address'] ?? '') != '' ? ' · ${r['address']}' : ''}',
              ),
              if ('${r['device'] ?? ''}'.isNotEmpty)
                _meta(Icons.phone_android_rounded, '${r['device']}'),
              if ('${r['os'] ?? ''}'.isNotEmpty)
                _meta(Icons.settings_suggest_outlined, '${r['os']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) {
    if (t.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 11.5, color: context.t3),
        const SizedBox(width: 3),
        Text(
          t.trim(),
          style: Ty.tiny.copyWith(fontSize: 10.5, color: context.t3),
        ),
      ],
    );
  }
}
