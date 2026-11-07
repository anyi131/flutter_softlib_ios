import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/forum_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';

/// 发帖
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.sections, this.sectionId});
  final List<Map<String, dynamic>> sections;
  final int? sectionId;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  late int _section = widget.sectionId ?? (widget.sections.isNotEmpty ? int.tryParse('${widget.sections.first['id']}') ?? 0 : 0);
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _title.text.trim();
    final c = _content.text.trim();
    if (t.length < 2) return ToastUtil.info('标题至少 2 个字');
    if (c.length < 2) return ToastUtil.info('正文至少 2 个字');
    if (_section <= 0) return ToastUtil.info('请选择板块');
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final id = await ForumService.instance
          .publish(title: t, section: _section, text: c);
      if (!mounted) return;
      ToastUtil.success('发布成功');
      Get.back(result: true);
      if (id > 0) {
        // 发布后直接进详情
      }
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: const Text('发帖', style: TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _sending ? null : _submit,
            child: Text(_sending ? '发布中…' : '发布',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.brand)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          TextField(
            controller: _title,
            maxLength: 60,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.t1),
            decoration: InputDecoration(
              hintText: '标题',
              hintStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.t3),
              border: InputBorder.none,
              counterStyle: TextStyle(fontSize: 10, color: context.t3),
            ),
          ),
          Divider(color: context.isDark ? Colors.white12 : Colors.black12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in widget.sections)
                AppPressable(
                  onTap: () => setState(() => _section = int.tryParse('${s['id']}') ?? 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _section == int.tryParse('${s['id']}')
                          ? C.brand
                          : (context.isDark ? C.bg2 : C.lbg2),
                      borderRadius: BorderRadius.circular(R.full),
                    ),
                    child: Text('${s['name'] ?? ''}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _section == int.tryParse('${s['id']}')
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _section == int.tryParse('${s['id']}') ? Colors.white : context.t2)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 10,
            maxLines: 30,
            maxLength: 5000,
            style: TextStyle(fontSize: 14, height: 1.7, color: context.t1),
            decoration: InputDecoration(
              hintText: '分享你的想法、问题或资源…',
              hintStyle: TextStyle(fontSize: 14, color: context.t3),
              filled: true,
              fillColor: context.isDark ? C.bg2 : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(R.md),
                borderSide: BorderSide.none,
              ),
              counterStyle: TextStyle(fontSize: 10, color: context.t3),
            ),
          ),
          const SizedBox(height: 8),
          Text('发布即表示同意社区规范，违规内容会被删除。',
              style: TextStyle(fontSize: 11, color: context.t3)),
        ],
      ),
    );
  }
}
