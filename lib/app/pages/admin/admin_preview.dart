import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/ui.dart';
import '../../design/kit.dart';
import 'admin_ui_kit.dart';
import '../../utils/jump_util.dart';

/// ★ 1016：后台「链接预览」—— 粘贴图片/视频链接即可预览
/// 支持：.png/.jpg/.jpeg/.gif/.webp（图片）、.mp4/.mov/.m4v/.webm（视频）
/// 也支持任意 http(s) 链接（用浏览器式 WebView 打开）与后台上传目录的相对路径
class AdminLinkPreviewSheet extends StatefulWidget {
  const AdminLinkPreviewSheet({super.key});

  @override
  State<AdminLinkPreviewSheet> createState() => _AdminLinkPreviewSheetState();
}

class _AdminLinkPreviewSheetState extends State<AdminLinkPreviewSheet> {
  final _ctrl = TextEditingController();
  String _url = '';
  String _kind = ''; // image / video / other

  static const _imgExt = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];
  static const _vidExt = ['.mp4', '.mov', '.m4v', '.webm', '.mkv'];

  void _apply(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return;
    if (u.startsWith('//')) u = 'https:$u';
    // 站内相对路径 → 补全域名
    if (u.startsWith('/')) u = 'https://flrjk.52yfx.cn$u';
    final low = u.toLowerCase();
    String kind = 'other';
    if (_imgExt.any((e) => low.contains(e)))
      kind = 'image';
    else if (_vidExt.any((e) => low.contains(e)))
      kind = 'video';
    setState(() {
      _url = u;
      _kind = kind;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: context.isDark ? C.bg2 : Colors.white,
        borderRadius: BorderRadius.circular(R.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 18, color: C.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '链接预览',
                  style: Ty.h3.copyWith(fontSize: 15, color: context.t1),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, size: 18, color: context.t3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '粘贴图片 / 视频链接，或站内上传后的路径（如 /uploads/xxx.png）',
            style: Ty.tiny.copyWith(fontSize: 11.5, color: context.t3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://... 或 /uploads/xxx.mp4',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(R.md),
                    ),
                  ),
                  onSubmitted: _apply,
                ),
              ),
              const SizedBox(width: 8),
              SoftButton(label: '预览', onPressed: () => _apply(_ctrl.text)),
            ],
          ),
          if (_url.isNotEmpty) ...[
            const SizedBox(height: 12),
            AdCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.md),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: _buildPreview(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _url,
              style: Ty.tiny.copyWith(fontSize: 11, color: context.t3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_kind == 'image') {
      return Image.network(
        _url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _err('图片加载失败（可能 404 或需要鉴权）'),
        loadingBuilder: (c, child, p) => p == null
            ? child
            : const Center(child: CircularProgressIndicator()),
      );
    }
    // 原视频播放依赖主 App 的播放器组件；这里给出可点击的打开方式，
    // 避免在后台引入额外依赖或崩溃风险。
    return _err(
      _kind == 'video' ? '视频链接已识别\n可在浏览器中打开预览' : '非图片链接\n可使用「打开」按钮在浏览器中查看',
    );
  }

  Widget _err(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 26, color: context.t3),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: Ty.tiny.copyWith(fontSize: 12, color: context.t3),
          ),
          if (_url.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => JumpUtil.openUrl(_url),
              child: Text(
                '打开链接',
                style: TextStyle(fontSize: 12.5, color: C.brand),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
