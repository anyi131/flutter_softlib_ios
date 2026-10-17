import 'package:flutter/material.dart';
import '../../design/kit.dart';
import '../../design/adaptive.dart';
import '../../routes/app_pages.dart';
import '../../design/ui.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/app_item.dart';
import '../../api/soft_service.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_card.dart';

/// 软件搜索页（搜索已入库软件，含服务器直传 + 蓝奏云两种来源）
class AppSearchPage extends StatefulWidget {
  const AppSearchPage({super.key});

  @override
  State<AppSearchPage> createState() => _AppSearchPageState();
}

class _AppSearchPageState extends State<AppSearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  final SoftService _service = SoftService.instance;

  List<AppItem> _results = [];
  bool _loading = false;
  bool _searched = false;
  String _keyword = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) {
      ToastUtil.error('请输入搜索关键词');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _keyword = kw;
    });
    try {
      final list = await _service.fetchApps(keyword: kw);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
      ToastUtil.error('网络异常，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('软件搜索', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? scheme.surfaceContainerHighest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '输入软件名称关键词',
                        hintStyle:
                            TextStyle(fontSize: 14, color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search,
                            size: 20, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    onPressed: _loading ? null : _search,
                    child: const Text('搜索'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SkeletonList(count: 7);
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (!_searched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: Colors.grey.withAlpha(90)),
            const SizedBox(height: 12),
            Text('输入关键词，搜索软件库资源',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      // ★ 1016 待办：搜索无结果 → 引导「求软件」，不再只给一行灰字
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: C.brand.withAlpha(context.isDark ? 30 : 18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.travel_explore_rounded, size: 42, color: C.brand.withAlpha(170)),
              ),
              const SizedBox(height: 18),
              Text('没找到「$_keyword」',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.t1)),
              const SizedBox(height: 8),
              Text('换个关键词试试，或者告诉我们你想要什么',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: context.t3)),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Get.toNamed(Routes.message),
                icon: const Icon(Icons.add_comment_rounded, size: 17),
                label: const Text('求这个软件'),
                style: FilledButton.styleFrom(
                  backgroundColor: C.brand,
                  minimumSize: const Size(160, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.maybePop(context),
                child: Text('返回软件库浏览', style: TextStyle(fontSize: 12.5, color: context.t3)),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: _results.length,
      itemBuilder: (context, index) => AppCard(
        item: _results[index],
        onTap: () => Get.toNamed(Routes.appDetails, arguments: {
          'appId': _results[index].id.toString(),
          'item': _results[index],
        }),
      ),
    );
  }
}
