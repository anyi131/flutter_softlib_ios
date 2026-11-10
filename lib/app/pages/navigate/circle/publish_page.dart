import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/forum_service.dart';
import '../../../api/soft_service.dart';
import '../../../api/user_service.dart';
import '../../../api/post_service.dart';
import '../../../design/app_anim.dart';
import '../../../design/ui.dart';
import '../../../design/lucide.dart';
import 'post_content.dart';
import '../../../design/buttons.dart';
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
  final List<File> _images = [];
  bool _uploading = false;
  /// 1109：发布前预览
  bool _preview = false;
  bool _payOn = false;
  final _payPrice = TextEditingController();
  final _payBody = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _payPrice.dispose();
    _payBody.dispose();
    super.dispose();
  }

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
    } catch (e) {
      ToastUtil.error('选图失败');
    }
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
      final id = await ForumService.instance
          .publish(
              title: t,
              section: _section,
              text: c,
              images: urls,
              payNeed: _payOn
                  ? (double.tryParse(_payPrice.text.trim()) ?? 0)
                  : 0,
              payContent: _payOn ? _payBody.text.trim() : '');
      if (!mounted) return;
      final needReview =
          (SoftService.instance.cachedConfig?.uiConfig.forumReview ?? false) &&
              !(UserService.instance.user?.isAdmin == true);
      ToastUtil.success(needReview ? '已提交，等待管理员审核' : '发布成功');
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
  /// 1109：Markdown 工具栏（插入语法，发帖不用背语法）
  void _insertMd(String text) {
    final sel = _content.selection;
    final start = sel.start >= 0 ? sel.start : _content.text.length;
    final end = sel.end >= 0 ? sel.end : _content.text.length;
    final t = _content.text.replaceRange(start, end, text);
    _content.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  /// 1109：在光标处插入图片（上传后写入 Markdown，正文任意位置可插图）
  Future<void> _insertImageAtCursor() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 82);
      if (picked == null) return;
      setState(() => _uploading = true);
      final url = await PostService.instance.uploadImage(File(picked.path));
      if (url.isEmpty) throw Exception('上传失败');
      _insertMd('\n![](' + url + ')\n');
      ToastUtil.success('已插入到光标处');
    } catch (e) {
      ToastUtil.error('插图失败');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// 1109：把选中内容标记为打赏可见
  void _markPay() {
    final sel = _content.selection;
    if (sel.start < 0 || sel.start == sel.end) {
      ToastUtil.info("请先选中要隐藏的段落");
      return;
    }
    final t = _content.text;
    final chosen = t.substring(sel.start, sel.end);
    final nt = t.replaceRange(sel.start, sel.end, "[pay]" + chosen + "[/pay]");
    _content.value = TextEditingValue(
      text: nt,
      selection: TextSelection.collapsed(
          offset: sel.start + 5 + chosen.length + 6),
    );
    ToastUtil.success("已标记为付费可见");
  }

  Widget _mdBar() {
    Widget b(String label, String insert) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppChip(label, onTap: () => _insertMd(insert)),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
                b('粗体', '**粗体**'),
        b('斜体', '*斜体*'),
        b('删除线', '~~删除线~~'),
        b('H1', '\n# 大标题\n'),
        b('H2', '\n## 小标题\n'),
        b('H3', '\n### 更小标题\n'),
        b('列表', '\n- 条目\n'),
        b('有序', '\n1. 第一条\n2. 第二条\n'),
        b('引用', '\n> 引用内容\n'),
        b('代码', '\n```\n代码\n```\n'),
        b('链接', '[文字](https://)'),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppChip('插入图片',
              icon: Lz.image, onTap: _insertImageAtCursor),
        ),
        b('分割线', '\n---\n'),
        b('表格', '\n| 列1 | 列2 |\n|---|---|\n| a | b |\n'),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppChip('设为付费', icon: Lz.lock, onTap: _markPay),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppChip('导入链接', icon: Lz.link, primary: true, onTap: _importLink),
        ),
      ]),
    );
  }

  /// 1109：发布前预览（与帖子详情同一套渲染）
  Widget _previewView(BuildContext context) {
    String secName = '';
    for (final s in widget.sections) {
      final sid = int.tryParse('${s["id"]}') ?? 0;
      if (sid == _section) {
        final nm = s['name'] ?? '';
        secName = '$nm';
        break;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
      children: [
        Text(
          _title.text.trim().isEmpty ? '（未填写标题）' : _title.text.trim(),
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.4,
              color: context.t1),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (secName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: C.brand.withAlpha(context.isDark ? 30 : 14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(secName,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: C.brand,
                      fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          Text('预览效果',
              style: TextStyle(fontSize: 10.5, color: context.t3)),
        ]),
        const SizedBox(height: 16),
        if (_content.text.trim().isEmpty)
          Text('（正文为空）',
              style: TextStyle(fontSize: 13, color: context.t3))
        else
          PostContent(text: _content.text),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(f,
                      width: 104, height: 104, fit: BoxFit.cover),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Text('以上即发布后其他用户看到的样子',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: context.t3)),
      ],
    );
  }

  /// 1109：从链接导入标题/正文/首图
  Future<void> _importLink() async {
    final ctrl = TextEditingController();
    final go = await Get.dialog<bool>(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('导入链接内容',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('粘贴网页链接，自动抓取标题、正文和首图',
              style: TextStyle(fontSize: 12, color: context.t3)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消')),
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
      final img = '';
      setState(() {
        if (_title.text.trim().isEmpty && t.isNotEmpty) {
          _title.text = t;
        }
        final buf = StringBuffer();
        if (tx.isNotEmpty) buf.writeln(tx);
        buf.writeln();
        buf.writeln('来源：' + url);
        if (img.isNotEmpty) {
          buf.writeln();
          buf.writeln('![](' + img + ')');
        }
        final old = _content.text.trim();
        _content.text = old.isEmpty
            ? buf.toString()
            : old + '\n\n' + buf.toString();
      });
      ToastUtil.success('已导入，右上角可预览');
    } catch (e) {
      ToastUtil.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: const Text('发帖', style: TextStyle(fontSize: 15)),
        backgroundColor: context.isDark ? C.bg0 : C.lbg0,
        surfaceTintColor: Colors.transparent,
        actions: [
          AppChip(
            _preview ? '编辑' : '预览',
            icon: _preview ? Lz.pencil : Lz.eye,
            dense: true,
            onTap: () => setState(() => _preview = !_preview),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _sending ? null : _submit,
            child: Text(_sending ? (_uploading ? '上传图片…' : '发布中…') : '发布',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: C.brand)),
          ),
        ],
      ),
      body: _preview ? _previewView(context) : ListView(
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
          _mdBar(),
          TextField(
            controller: _content,
            minLines: 10,
            maxLines: 30,
            maxLength: 5000,
            style: TextStyle(fontSize: 14, height: 1.7, color: context.t1),
            decoration: InputDecoration(
              hintText: '分享你的想法、问题或资源…',
              helperText: '支持 Markdown 与 HTML，右上角「预览」可看效果',
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    // 1109：缩略图加圆角/描边，右上角换成 AppRemoveBadge（白底+红叉+投影）
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.isDark ? C.bg2 : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: context.isDark ? C.bg3 : C.lbg2),
                      ),
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
                        onTap: () => setState(() => _images.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              if (_images.length < 9)
                GestureDetector(
                  onTap: _pick,
                  child: Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: context.isDark ? C.bg2 : C.brand.withAlpha(8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: C.brand.withAlpha(context.isDark ? 40 : 26),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 22, color: C.brand),
                        const SizedBox(height: 2),
                        Text('添加图片',
                            style: TextStyle(fontSize: 9.5, color: C.brand)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
                const Icon(Icons.card_giftcard_rounded,
                    size: 16, color: C.gold),
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
                  onChanged: (v) => setState(() => _payOn = v),
                ),
              ]),
              if (_payOn) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _payPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '打赏金额（元）',
                    hintText: '1.00',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _payBody,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '打赏后可见的内容',
                    hintText: '例如下载链接、提取码、附件说明…',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          Text('发布即表示同意社区规范，违规内容会被删除。',
              style: TextStyle(fontSize: 11, color: context.t3)),
        ],
      ),
    );
  }
}
