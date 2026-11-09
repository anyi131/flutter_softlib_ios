import 'package:flutter/material.dart';

import '../../../design/ui.dart';

/// 1109：帖子正文渲染（轻量富文本，零外部依赖）
/// 支持：
///   # / ## / ###  标题
///   - 或 *        无序列表
///   1. 2.         有序列表
///   > 引用
///   ---           分割线
///   **粗体**
///   ![](url) 或 独立图片链接  图片
///   空行分段
class PostContent extends StatelessWidget {
  final String text;
  final List<String> images;

  const PostContent({super.key, required this.text, this.images = const []});

  static bool _isImageLine(String s) {
    final t = s.trim();
    if (t.startsWith('![')) return true;
    final low = t.toLowerCase();
    if (low.startsWith('http') &&
        (low.endsWith('.png') ||
            low.endsWith('.jpg') ||
            low.endsWith('.jpeg') ||
            low.endsWith('.gif') ||
            low.endsWith('.webp'))) {
      return true;
    }
    return false;
  }

  static String? _imageUrlOf(String s) {
    final t = s.trim();
    final m = RegExp(r'!\[[^\]]*\]\(([^)]+)\)').firstMatch(t);
    if (m != null) return m.group(1);
    if (t.startsWith('http')) return t;
    return null;
  }

  /// 行内 **粗体** → TextSpan
  static List<TextSpan> _spans(
      String src, TextStyle base, TextStyle bold) {
    final out = <TextSpan>[];
    final parts = src.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      out.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? bold : base,
      ));
    }
    if (out.isEmpty) out.add(TextSpan(text: src, style: base));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 15,
      height: 1.85,
      letterSpacing: 0.2,
      color: context.t1,
    );
    final bold = base.copyWith(fontWeight: FontWeight.w800);
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];

    final para = StringBuffer();
    void flushPara() {
      final s = para.toString().trim();
      para.clear();
      if (s.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SelectableText.rich(TextSpan(
          children: _spans(s.replaceAll('\n', ' '), base, bold),
        )),
      ));
    }

    for (var raw in lines) {
      final line = raw.trimRight();
      final t = line.trim();

      if (t.isEmpty) {
        flushPara();
        continue;
      }

      // 分割线
      if (RegExp(r'^-{3,}$').hasMatch(t)) {
        flushPara();
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(
            height: 1,
            color: context.isDark ? Colors.white12 : Colors.black12,
          ),
        ));
        continue;
      }

      // 图片
      if (_isImageLine(t)) {
        flushPara();
        final url = _imageUrlOf(t);
        if (url != null && url.isNotEmpty) {
          blocks.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                loadingBuilder: (c, child, p) => p == null
                    ? child
                    : Container(
                        height: 160,
                        color: context.isDark ? C.bg2 : C.lbg2,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),
            ),
          ));
        }
        continue;
      }

      // 标题
      final head = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(t);
      if (head != null) {
        flushPara();
        final level = head.group(1)!.length;
        final size = switch (level) { 1 => 19.0, 2 => 17.0, _ => 15.5 };
        blocks.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 6 : 4, bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3,
                height: size + 2,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: C.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  head.group(2)!,
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                    color: context.t1,
                  ),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      // 引用
      if (t.startsWith('>')) {
        flushPara();
        final body = t.replaceFirst(RegExp(r'^>\s*'), '');
        blocks.add(Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 22 : 12),
            border: Border(
              left: BorderSide(color: C.brand.withAlpha(160), width: 3),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText.rich(TextSpan(
            children: _spans(body, base.copyWith(fontSize: 14, color: context.t2), bold),
          )),
        ));
        continue;
      }

      // 列表
      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(t);
      final ordered = RegExp(r'^(\d+)[.、)]\s+(.*)$').firstMatch(t);
      if (bullet != null || ordered != null) {
        flushPara();
        final content = bullet?.group(1) ?? ordered!.group(2)!;
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: ordered != null
                    ? Text('${ordered.group(1)}.',
                        style: base.copyWith(
                            fontSize: 14,
                            height: 1.6,
                            color: C.brand,
                            fontWeight: FontWeight.w800))
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: C.brand.withAlpha(200),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: SelectableText.rich(TextSpan(
                  children: _spans(content, base.copyWith(height: 1.7), bold),
                )),
              ),
            ],
          ),
        ));
        continue;
      }

      // 普通段落（累积，空行时输出）
      if (para.isNotEmpty) para.write('\n');
      para.write(t);
    }
    flushPara();

    // 附带的图片（帖子 images 字段）
    if (images.isNotEmpty) {
      blocks.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            for (final url in images)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}
