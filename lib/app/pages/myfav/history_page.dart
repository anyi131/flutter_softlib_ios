import 'package:dio/dio.dart';
import '../../api/api_http.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../api/api_host.dart';
import '../../api/user_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/err_text.dart';
import '../../utils/toast_util.dart';
import '../../design/glass.dart';

/// 使用历史
///
/// ★ 1020：原来只能看不能删。现在支持单条删除 + 批量清理。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Dio get _dio => ApiHttp.create(
    BaseOptions(
      baseUrl: ApiHost.base,
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // ★ 1020：服务端只认 POST body 里的 token
      final r = await _dio.post(
        '/api/softlib/jzs/history_list',
        data: {'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        final list = (r.data['data']?['list'] as List?) ?? [];
        if (!mounted) return;
        setState(() {
          _list = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[History] $e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _deleteOne(Map<String, dynamic> h) async {
    final id = (h['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final old = List<Map<String, dynamic>>.from(_list);
    setState(() => _list.removeWhere((e) => '${e['id']}' == '$id'));
    try {
      await _dio.post(
        '/api/softlib/jzs/history_del',
        data: {'tool_id': id, 'token': UserService.instance.token},
      );
      ToastUtil.success('已删除');
    } catch (e) {
      if (!mounted) return;
      setState(() => _list = old);
      ToastUtil.error(ErrText.of(e));
    }
  }

  Future<void> _clearAll() async {
    final pick = await Get.bottomSheet<int>(
      SheetSurface(
        color: context.isDark ? C.bg1 : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        radius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '清理历史记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: context.t1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '只清理工具使用记录，不影响收藏和下载',
              style: Ty.tiny.copyWith(color: context.t3),
            ),
            const SizedBox(height: 12),
            _clearOption('清理 7 天前的记录', 7, C.brand),
            _clearOption('清理 30 天前的记录', 30, C.brand),
            _clearOption('清空全部历史', 0, C.danger),
          ],
        ),
      ),
    );
    if (pick == null) return;
    try {
      final r = await _dio.post(
        '/api/softlib/jzs/history_clear',
        data: {'days': pick, 'token': UserService.instance.token},
      );
      if (r.data is Map && r.data['code'] == 1) {
        ToastUtil.success('${r.data['msg'] ?? '已清理'}');
      }
      _load();
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    }
  }

  Widget _clearOption(String label, int days, Color c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (days == 0) {
            Get.dialog<bool>(
              AppDialog(
                title: const Text('清空全部历史'),
                content: const Text('将删除所有工具使用记录，不可恢复。'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(result: false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Get.back(result: true),
                    child: const Text('清空', style: TextStyle(color: C.danger)),
                  ),
                ],
              ),
            ).then((ok) {
              if (ok == true) Get.back(result: 0);
            });
            return;
          }
          Get.back(result: days);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.withAlpha(context.isDark ? 40 : 18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withAlpha(70)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ),
    );
  }

  String _timeText(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${d.month}-${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding,
                    8,
                    context.pagePadding,
                    8,
                  ),
                  child: Row(
                    children: [
                      AppPressable(
                        onTap: () => Get.back(),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 19,
                          color: context.t1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '使用历史',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: context.t1,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: C.brand.withAlpha(22),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${_list.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: C.brand,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_list.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAll,
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            '清理',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const LoadingState(text: '加载历史…')
                      : (_list.isEmpty
                            ? const EmptyState(
                                icon: Icons.history_rounded,
                                text: '还没有使用记录',
                                hint: '打开过的工具会记录在这里',
                              )
                            : RefreshIndicator(
                                onRefresh: _load,
                                color: C.brand,
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    context.pagePadding,
                                    4,
                                    context.pagePadding,
                                    24,
                                  ),
                                  itemCount: _list.length,
                                  itemBuilder: (c, i) => _tile(_list[i]),
                                ),
                              )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> h) {
    final icon = '${h['icon'] ?? ''}';
    final isEmoji = icon.isNotEmpty && icon.runes.first > 0x2000;
    final ts = (h['usetime'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Dismissible(
        key: ValueKey('hist_${h['id']}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: C.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        onDismissed: (_) => _deleteOne(h),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withAlpha(12) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.isDark
                  ? Colors.white10
                  : Colors.black.withAlpha(7),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      C.brand.withAlpha(context.isDark ? 44 : 20),
                      C.accent.withAlpha(context.isDark ? 28 : 12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isEmoji
                    ? Text(icon, style: const TextStyle(fontSize: 20))
                    : Icon(Icons.widgets_rounded, size: 20, color: C.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${h['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _timeText(ts),
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ],
                ),
              ),
              AppPressable(
                onTap: () => _deleteOne(h),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 17, color: context.t3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
