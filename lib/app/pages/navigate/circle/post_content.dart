import 'package:flutter/material.dart';

import '../../../design/ui.dart';

/// 1109：帖子正文渲染（轻量富文本，零外部依赖）
/// ① Markdown 子集：标题 / 列表 / 引用 / 分割线 / 粗体 / 图片 / 表格
/// ② HTML 子集：<p> <br> <h1-3> <b>/<strong> <ul>/<li> <blockquote> <img> <table> 自动识别并转换
class PostContent extends StatelessWidget {
  final String text;
  final List<String> images;

  const PostContent({super.key, required this.text, this.images = const []});

  static bool _looksLikeHtml(String s) {
    final t = s.trimLeft();
    return RegExp(
            r'<\s*(p|div|br|h[1-6]|ul|ol|li|strong|b|em|blockquote|img|table|tr|td|span)[\s>/]',
            caseSensitive: false)
        .hasMatch(t);
  }

  static String _strip(String s) {
    var t = s.replaceAll(RegExp(r'<[^>]+>'), '');
    const map = {
      '&nbsp;': ' ',
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&ldquo;': '“',
      '&rdquo;': '”',
    };
    map.forEach((k, v) => t = t.replaceAll(k, v));
    return t;
  }

  static String _htmlToMd(String html) {
    var s = html;
    final tables = <String>[];
    s = s.replaceAllMapped(RegExp(r'<table[\s\S]*?</table>', caseSensitive: false),
        (m) {
      final rows = <String>[];
      final trs = RegExp(r'<tr[\s\S]*?</tr>', caseSensitive: false)
          .allMatches(m.group(0)!)
          .map((x) => x.group(0)!)
          .toList();
      for (var i = 0; i < trs.length; i++) {
        final cells =
            RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false)
                .allMatches(trs[i])
                .map((c) => _strip(c.group(1) ?? '').trim())
                .toList();
        if (cells.isEmpty) continue;
        rows.add('| ' + cells.join(' | ') + ' |');
        if (i == 0) {
          final sep = List.filled(cells.length, '---').join('|');
          rows.add('|' + sep + '|');
        }
      }
      tables.add(rows.join('\n'));
      return '\n\n@@T${tables.length - 1}@@\n\n';
    });

    s = s.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(
        RegExp(r'</\s*(p|div|h[1-6]|li|tr|blockquote)\s*>', caseSensitive: false),
        '\n');
    s = s.replaceAll(RegExp(r'<\s*h1[^>]*>', caseSensitive: false), '# ');
    s = s.replaceAll(RegExp(r'<\s*h2[^>]*>', caseSensitive: false), '## ');
    s = s.replaceAll(RegExp(r'<\s*h3[^>]*>', caseSensitive: false), '### ');
    s = s.replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '- ');
    s = s.replaceAll(RegExp(r'<\s*blockquote[^>]*>', caseSensitive: false), '> ');
    s = s.replaceAll(RegExp(r'<\s*(strong|b)[^>]*>', caseSensitive: false), '**');
    s = s.replaceAll(RegExp(r'</\s*(strong|b)\s*>', caseSensitive: false), '**');
    s = s.replaceAll(RegExp(r'<\s*hr\s*/?>', caseSensitive: false), '\n---\n');
    s = s.replaceAllMapped(
        RegExp(r'''<\s*img[^>]*src=["']([^"']+)["'][^>]*>''', caseSensitive: false),
        (m) => '\n![](${m.group(1)})\n');
    s = _strip(s);

    for (var i = 0; i < tables.length; i++) {
      s = s.replaceAll('@@T$i@@', tables[i]);
    }
    return s;
  }

  static List<TextSpan> _spans(String src, TextStyle base, TextStyle bold) {
    final out = <TextSpan>[];
    final parts = src.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      out.add(TextSpan(text: parts[i], style: i.isOdd ? bold : base));
    }
    if (out.isEmpty) out.add(TextSpan(text: src, style: base));
    return out;
  }

  static bool _isImageLine(String s) {
    final t = s.trim();
    if (t.startsWith('![')) return true;
    final low = t.toLowerCase();
    return low.startsWith('http') &&
        (low.endsWith('.png') ||
            low.endsWith('.jpg') ||
            low.endsWith('.jpeg') ||
            low.endsWith('.gif') ||
            low.endsWith('.webp'));
  }

  static String? _imageUrlOf(String s) {
    final t = s.trim();
    final m = RegExp(r'!\[[^\]]*\]\(([^)]+)\)').firstMatch(t);
    if (m != null) return m.group(1);
    if (t.startsWith('http')) return t;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final src = _looksLikeHtml(text) ? _htmlToMd(text) : text;
    final base =
        TextStyle(fontSize: 15.5, height: 1.95, letterSpacing: 0.2, color: context.t1);
    final bold = base.copyWith(fontWeight: FontWeight.w800);
    final lines = src.replaceAll('\r\n', '\n').split('\n');
    final blocks = <Widget>[];

    final para = StringBuffer();
    void flushPara() {
      final s = para.toString().trim();
      para.clear();
      if (s.isEmpty) return;
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SelectableText.rich(
            TextSpan(children: _spans(s.replaceAll('\n', ' '), base, bold))),
      ));
    }

    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty) {
        flushPara();
        continue;
      }

      if (t.startsWith('|') && t.endsWith('|')) {
        flushPara();
        final rows = <List<String>>[];
        var j = i;
        while (j < lines.length &&
            lines[j].trim().startsWith('|') &&
            lines[j].trim().endsWith('|')) {
          final raw = lines[j].trim();
          final cells = raw
              .substring(1, raw.length - 1)
              .split('|')
              .map((e) => e.trim())
              .toList();
          final isSep = cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c));
          if (!isSep) rows.add(cells);
          j++;
        }
        i = j - 1;
        if (rows.isNotEmpty) blocks.add(_table(context, rows, base));
        continue;
      }

      if (RegExp(r'^-{3,}$').hasMatch(t)) {
        flushPara();
        blocks.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(
              height: 1,
              color: context.isDark ? Colors.white12 : Colors.black12),
        ));
        continue;
      }

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
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ),
              ),
            ),
          ));
        }
        continue;
      }

      final head = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(t);
      if (head != null) {
        flushPara();
        final level = head.group(1)!.length;
        final size = switch (level) { 1 => 19.0, 2 => 17.0, _ => 15.5 };
        blocks.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 6 : 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: size + 2,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: C.brand, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Text(head.group(2)!,
                    style: TextStyle(
                        fontSize: size,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                        color: context.t1)),
              ),
            ],
          ),
        ));
        continue;
      }

      if (t.startsWith('>')) {
        flushPara();
        final body = t.replaceFirst(RegExp(r'^>\s*'), '');
        blocks.add(Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: C.brand.withAlpha(context.isDark ? 22 : 12),
            border:
                Border(left: BorderSide(color: C.brand.withAlpha(160), width: 3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText.rich(TextSpan(
            children:
                _spans(body, base.copyWith(fontSize: 14, color: context.t2), bold),
          )),
        ));
        continue;
      }

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
                              shape: BoxShape.circle),
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

      if (para.isNotEmpty) para.write('\n');
      para.write(t);
    }
    flushPara();

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
                  child: Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _table(BuildContext context, List<List<String>> rows, TextStyle base) {
    final cols = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        border:
            Border.all(color: context.isDark ? Colors.white12 : Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(
                color:
                    context.isDark ? Colors.white10 : Colors.black.withAlpha(12)),
            verticalInside: BorderSide(
                color:
                    context.isDark ? Colors.white10 : Colors.black.withAlpha(12)),
          ),
          children: [
            for (var r = 0; r < rows.length; r++)
              TableRow(
                decoration: r == 0
                    ? BoxDecoration(color: C.brand.withAlpha(context.isDark ? 30 : 16))
                    : null,
                children: [
                  for (var c2 = 0; c2 < cols; c2++)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        c2 < rows[r].length ? rows[r][c2] : '',
                        style: base.copyWith(
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: r == 0 ? FontWeight.w800 : FontWeight.w500,
                          color: r == 0 ? context.t1 : context.t2,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
