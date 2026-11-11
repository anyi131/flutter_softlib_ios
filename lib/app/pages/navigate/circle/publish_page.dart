import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../../api/forum_service.dart';
import '../../../api/post_service.dart';
import '../../../api/soft_service.dart';
import '../../../api/user_service.dart';
import '../../../design/buttons.dart';
import '../../../design/lucide.dart';
import '../../../design/ui.dart';
import '../../../design/components.dart';
import '../../../utils/err_text.dart';
import '../../../utils/toast_util.dart';
import 'post_content.dart';

/// 发帖（富文本编辑器版）
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.sections, this.sectionId});
  final List<Map<String, dynamic>> sections;
  final int? sectionId;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _title = TextEditingController();
  late final q.QuillController _quill = q.QuillController.basic();
  late int _section = widget.sectionId ??
      (widget.sections.isNotEmpty
          ? int.tryParse('${widget.sections.first['id']}') ?? 0
          : 0);

  bool _sending = false;
  bool _preview = false;
  bool _payOn = false;
  final _payPrice = TextEditingController();
  final _payBody = TextEditingController();
  final List<File> _images = [];
  bool _uploading = false;

  @override
  void dispose() {
    _title.dispose();
    _quill.dispose();
    _payPrice.dispose();
    _payBody.dispose();
    super.dispose();
  }

  // ───────── 内容读写 ─────────
  String get _plain => _quill.document.toPlainText().trim();

  String get _html {
    try {
      final delta = _quill.document.toDelta().toJson();
      return QuillDeltaToHtmlConverter(delta, ConverterOptions())
          .convert();
    } catch (_) {
      return _plain;
    }
  }

  void _insertText(String text) {
    final sel = _quill.selection;
    final index = sel.isValid ? sel.start : _quill.document.length - 1;
    _quill.document.insert(index.clamp(0, _quill.document.length - 1), text);
  }

  // ───────── 图片 ─────────
  Future<void> _pick() async {
    if (_images.length >= 9) return ToastUtil.info('最多 9 张图');
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 82);
      if (picked.isEmpty) return;
      setState(() {
        for (final x in picked.take(9 - _images.length)) {
          _images.add(File(x.path));
        }
      });
    } catch (_) {
      ToastUtil.error('选图失败');
    }
  }

  /// 在正文光标处插图（上传后写入图片嵌入）
  Future<void> _insertImageAtCursor() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
      if (picked == null) return;
      setState(() => _uploading = true);
      final url = await PostService.instance.uploadImage(File(picked.path));
      if (url.isEmpty) throw Exception('上传失败');
      final index = _quill.selection.start.clamp(0, _quill.document.length);
      _quill.document.insert(index, q.BlockEmbed.image(url));
      ToastUtil.success('已插入图片');
    } catch (_) {
      ToastUtil.error('插图失败');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ───────── 付费 ─────────
  void _markPay() {
    final sel = _quill.selection;
    if (!sel.isValid || sel.start == sel.end) {
      ToastUtil.info('请先选中要隐藏的段落');
      return;
    }
    _insertText('\n');
    final startIndex = sel.start;
    _quill.document.insert(startIndex, '[pay]');
    _quill.document.insert(sel.end + 5, '[/pay]');
    if (!_payOn) setState(() => _payOn = true);
    ToastUtil.success('已标记为付费可见，记得填打赏金额');
  }

  // ───────── 导入链接 ─────────
  Future<void> _importLink() async {
    final ctrl = TextEditingController();
    final go = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('导入链接内容',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('粘贴网页链接，自动抓取标题、正文和首图',
            style: TextStyle(fontSize: 12, color: context.t3)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(hintText: 'https://', isDense: true),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        FilledButton(
            onPressed: () => Get.back(result: true), child: const Text('导入')),
      ],
    ));
    if (go != true) return;
    final url = ctrl.text.trim();
    if (url.isEmpty) return;
    ToastUtil.info('正在抓取…');
    try {
      final d = await ForumService.instance.fetchLink(url);
      if (!mounted) return;
      final t = '${d['title'] ?? ''}'.trim();
      final tx = '${d['content'] ?? d['text'] ?? ''}'.trim();
      setState(() {
        if (_title.text.trim().isEmpty && t.isNotEmpty) _title.text = t;
        if (tx.isNotEmpty) {
          _quill.document.insert(_quill.document.length - 1, '$tx\n');
        }
      });
      ToastUtil.success('已导入，右上角可预览');
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ───────── 发布 ─────────
  Future<void> _submit() async {
    final t = _title.text.trim();
    if (t.length < 2) return ToastUtil.info('标题至少 2 个字');
    if (_plain.length < 2) return ToastUtil.info('正文至少 2 个字');
    if (_section <= 0) return ToastUtil.info('请选择板块');
    if (_payOn && (double.tryParse(_payPrice.text.trim()) ?? 0) <= 0) {
      return ToastUtil.info('请填写打赏金额');
    }
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final urls = <String>[];
      if (_images.isNotEmpty) {
        setState(() => _uploading = true);
        for (final f in _images) {
          try {
            final u = await PostService.instance.uploadImage(f);
            if (u.isNotEmpty) urls.add(u);
          } catch (_) {}
        }
        if (mounted) setState(() => _uploading = false);
      }
      await ForumService.instance.publish(
        title: t,
        section: _section,
        text: _html,
        images: urls,
        payNeed: _payOn ? (double.tryParse(_payPrice.text.trim()) ?? 0) : 0,
        payContent: _payOn ? _payBody.text.trim() : '',
      );
      if (!mounted) return;
      final needReview =
          (SoftService.instance.cachedConfig?.uiConfig.forumReview ?? false) &&
              !(UserService.instance.user?.isAdmin == true);
      ToastUtil.success(needReview ? '已提交，等待管理员审核' : '发布成功');
      Get.back(result: true);
    } catch (e) {
      ToastUtil.error(ErrText.of(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ───────── 工具栏 ─────────
  Widget _toolbar() {
    Widget b(IconData icon, String tip, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppChip('', icon: icon, dense: true, onTap: onTap),
        );

    void fmt(q.Attribute a) {
      final cur = _quill.getSelectionStyle().attributes[a.key];
      _quill.formatSelection(cur == a ? q.Attribute.clone(a, null) : a);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        b(Icons.format_bold, '粗体', () => fmt(q.Attribute.bold)),
        b(Icons.format_italic, '斜体', () => fmt(q.Attribute.italic)),
        b(Icons.format_underline, '下划线', () => fmt(q.Attribute.underline)),
        b(Icons.title, 'H1', () => fmt(q.Attribute.h1)),
        b(Icons.text_fields, 'H2', () => fmt(q.Attribute.h2)),
        b(Icons.format_quote, '引用', () => fmt(q.Attribute.blockQuote)),
        b(Icons.format_list_bulleted, '列表', () => fmt(q.Attribute.ul)),
        b(Icons.format_list_numbered, '有序', () => fmt(q.Attribute.ol)),
        b(Icons.code, '代码块', () => fmt(q.Attribute.codeBlock)),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppChip('链接', icon: Icons.link, dense: true, onTap: _addLink),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppChip('插入图片', icon: Lz.image, dense: true, onTap: _insertImageAtCursor),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppChip('设为付费', icon: Lz.lock, dense: true, onTap: _markPay),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: AppChip('导入链接', icon: Lz.link, primary: true, dense: true, onTap: _importLink),
        ),
      ]),
    );
  }

  Future<void> _addLink() async {
    final ctrl = TextEditingController();
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('插入链接', style: TextStyle(fontSize: 16)),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://'),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('取消')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('插入')),
      ],
    ));
    if (ok != true) return;
    final url = ctrl.text.trim();
    if (url.isEmpty) return;
    final sel = _quill.selection;
    final text = sel.isValid && sel.start != sel.end
        ? _quill.document.getPlainText(sel.start, sel.end - sel.start)
        : url;
    if (sel.isValid && sel.start != sel.end) {
      _quill.document.replace(sel.start, sel.end - sel.start, text);
    } else {
      _insertText(text);
    }
    _quill.formatSelection(q.LinkAttribute(url));
  }

  // ───────── 预览 ─────────
  Widget _previewView(BuildContext context) {
    final secName = widget.sections
        .where((s) => int.tryParse('${s["id"]}') == _section)
        .map((s) => '${s['name'] ?? ''}')
        .join();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
      children: [
        Text(_title.text.trim().isEmpty ? '（未填写标题）' : _title.text.trim(),
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, height: 1.4, color: context.t1)),
        const SizedBox(height: 10),
        Row(children: [
          if (secName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: C.brand.withAlpha(context.isDark ? 30 : 14),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(secName,
                  style: TextStyle(
                      fontSize: 11.5, color: C.brand, fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          Text('预览效果', style: TextStyle(fontSize: 10.5, color: context.t3)),
        ]),
        const SizedBox(height: 16),
        if (_html.trim().isEmpty)
          Text('（正文为空）', style: TextStyle(fontSize: 13, color: context.t3))
        else
          PostContent(text: _html),
        const SizedBox(height: 22),
        Text('以上即发布后其他用户看到的样子',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.t3)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : Colors.white,
      appBar: AppBar(
        title: const Text('发帖', style: TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          AppChip(_preview ? '编辑' : '预览',
              icon: _preview ? Lz.pencil : Lz.eye,
              dense: true,
              onTap: () => setState(() => _preview = !_preview)),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _sending ? null : _submit,
            child: Text(
                _sending ? (_uploading ? '上传图片…' : '发布中…') : '发布',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: C.brand)),
          ),
        ],
      ),
      body: _preview
          ? _previewView(context)
          : ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 40 + MediaQuery.of(context).viewInsets.bottom),
              children: [
                TextField(
                  controller: _title,
                  maxLength: 60,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: context.t1),
                  decoration: InputDecoration(
                    hintText: '标题',
                    hintStyle: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: context.t3),
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
                      AppChip('${s['name'] ?? ''}',
                          dense: true,
                          primary: _section == int.tryParse('${s['id']}'),
                          onTap: () =>
                              setState(() => _section = int.tryParse('${s['id']}') ?? 0)),
                  ],
                ),
                const SizedBox(height: 12),
                _toolbar(),
                Container(
                  constraints: const BoxConstraints(minHeight: 220),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.isDark ? C.bg2 : C.lbg1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.isDark ? C.bg3 : C.lbg2),
                  ),
                  child: q.QuillEditor.basic(
                    controller: _quill,
                    config: const q.QuillEditorConfig(
                      placeholder: '分享你的想法、问题或资源…',
                      padding: EdgeInsets.zero,
                      expands: false,
                    ),
                  ),
                ),
                // 付费区
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                  decoration: BoxDecoration(
                    color: C.gold.withAlpha(context.isDark ? 22 : 10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.gold.withAlpha(60)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      const Icon(Icons.card_giftcard_rounded, size: 16, color: C.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('付费可见（打赏后解锁）',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.t1)),
                      ),
                      Switch(
                          value: _payOn,
                          onChanged: (v) => setState(() => _payOn = v)),
                    ]),
                    if (_payOn) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _payPrice,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: '打赏金额（元）', hintText: '1.00', isDense: true),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _payBody,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: '打赏后可见的内容（可选）',
                          hintText: '链接 / 提取码 / 图片地址',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ]),
                ),
                // 附件图
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (int i = 0; i < _images.length; i++)
                    Stack(children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: context.isDark ? C.bg2 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: context.isDark ? C.bg3 : C.lbg2)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_images[i],
                              width: 74, height: 74, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: AppRemoveBadge(
                            onTap: () => setState(() => _images.removeAt(i))),
                      ),
                    ]),
                  if (_images.length < 9)
                    GestureDetector(
                      onTap: _pick,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: context.isDark ? C.bg2 : C.brand.withAlpha(8),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: C.brand.withAlpha(context.isDark ? 40 : 26)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 22, color: C.brand),
                            const SizedBox(height: 2),
                            Text('添加图片',
                                style: TextStyle(fontSize: 9.5, color: C.brand)),
                          ],
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text('发布即表示同意社区规范，违规内容会被删除。',
                    style: TextStyle(fontSize: 11, color: context.t3)),
              ],
            ),
    );
  }
}
