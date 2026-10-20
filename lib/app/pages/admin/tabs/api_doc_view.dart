import 'package:flutter/material.dart';

import '../../../api/admin_service.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import '../admin_ui_kit.dart';

/// 后台 · 接口文档
///
/// ★ 1020：之前接口散落在几个 php 文件里，没有任何文档，
///   排查问题只能靠 grep。现在自动扫描路由表生成，
///   这里按「用户端 / 后台」分组展示，可搜索、可复制。
class ApiDocView extends StatefulWidget {
  const ApiDocView({super.key});

  @override
  State<ApiDocView> createState() => _ApiDocViewState();
}

class _ApiDocViewState extends State<ApiDocView> {
  final _svc = AdminService.instance;
  final _kwCtrl = TextEditingController();

  List<Map<String, dynamic>> _userApi = [];
  List<Map<String, dynamic>> _adminApi = [];
  bool _loading = true;
  bool _adminMode = false;
  String _kw = '';
  String _generatedAt = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool regen = false}) async {
    setState(() => _loading = true);
    try {
      final r = regen ? await _svc.apiDocRegen() : await _svc.apiDoc();
      if (!mounted) return;
      setState(() {
        _userApi = ((r['user_api'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _adminApi = ((r['admin_api'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _generatedAt = '${r['generated_at'] ?? ''}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastUtil.error(ErrText.of(e));
    }
  }

  List<Map<String, dynamic>> get _shown {
    final src = _adminMode ? _adminApi : _userApi;
    if (_kw.isEmpty) return src;
    final k = _kw.toLowerCase();
    return src.where((e) {
      final p = '${e['path'] ?? ''}'.toLowerCase();
      final f = '${e['fn'] ?? ''}'.toLowerCase();
      final d = '${e['doc'] ?? ''}'.toLowerCase();
      final ps = ((e['params'] as List?) ?? []).join(' ').toLowerCase();
      return p.contains(k) || f.contains(k) || d.contains(k) || ps.contains(k);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 模式切换 + 刷新
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            10,
            context.pagePadding,
            4,
          ),
          child: Row(
            children: [
              _chip('用户端 ${_userApi.length}', !_adminMode, () {
                setState(() => _adminMode = false);
              }),
              const SizedBox(width: 8),
              _chip('后台 ${_adminApi.length}', _adminMode, () {
                setState(() => _adminMode = true);
              }),
              const Spacer(),
              IconButton(
                tooltip: '重新扫描',
                onPressed: () => _load(regen: true),
                icon: Icon(Icons.refresh_rounded, size: 19, color: context.t3),
              ),
            ],
          ),
        ),
        // 搜索
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding,
            4,
            context.pagePadding,
            6,
          ),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: context.isDark
                    ? Colors.white12
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 15, color: context.t3),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: _kwCtrl,
                    onChanged: (v) => setState(() => _kw = v.trim()),
                    style: TextStyle(fontSize: 12.5, color: context.t1),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '搜索接口路径 / 函数名 / 参数',
                      hintStyle: TextStyle(fontSize: 12, color: context.t3),
                    ),
                  ),
                ),
                if (_kw.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _kwCtrl.clear();
                      setState(() => _kw = '');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: context.t3,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_generatedAt.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: context.pagePadding,
              right: context.pagePadding,
              bottom: 4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '生成于 $_generatedAt · 共 ${_shown.length} 个',
                style: Ty.tiny.copyWith(fontSize: 9.5, color: context.t3),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const LoadingState(text: '加载接口文档…')
              : (_shown.isEmpty
                    ? const EmptyState(text: '没有匹配的接口')
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          context.pagePadding,
                          4,
                          context.pagePadding,
                          24,
                        ),
                        itemCount: _shown.length,
                        itemBuilder: (c, i) => _item(_shown[i]),
                      )),
        ),
      ],
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? C.brand : context.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? C.brand : C.stroke),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: sel ? Colors.white : context.t2,
          ),
        ),
      ),
    );
  }

  Widget _item(Map<String, dynamic> e) {
    final path = '${e['path'] ?? ''}';
    final params = ((e['params'] as List?) ?? []).map((x) => '$x').toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: AdCard(
        radius: R.md,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              path,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: C.brand,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Text(
                  '${e['fn'] ?? ''}',
                  style: Ty.tiny.copyWith(fontSize: 9.5, color: context.t3),
                ),
                const Spacer(),
                if (params.isNotEmpty)
                  Text(
                    '${params.length} 个参数',
                    style: Ty.tiny.copyWith(fontSize: 9.5, color: C.mint),
                  ),
              ],
            ),
            if (params.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: params
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? Colors.white10
                              : const Color(0xFFF2F4F9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: context.t2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
