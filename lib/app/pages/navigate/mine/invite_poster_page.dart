import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design/adaptive.dart';
import '../../../design/ui.dart';
import '../../../utils/img_saver.dart';
import '../../../utils/toast_util.dart';

/// ★ 1016：邀请海报（生成图片 → 保存 / 分享）
///
/// 设计：品牌渐变底 + Logo + 一句话 + 二维码 + 邀请码
/// 导出：RepaintBoundary 截图成 PNG（1080×1620），直达相册
class InvitePosterPage extends StatefulWidget {
  const InvitePosterPage({
    super.key,
    required this.code,
    this.title = '安逸软件汇',
    this.slogan = '发现宝藏软件，一个就够了',
    this.logoUrl = '',
    this.landingUrl = '',
  });

  final String code;
  final String title;
  final String slogan;
  final String logoUrl;
  final String landingUrl;

  @override
  State<InvitePosterPage> createState() => _InvitePosterPageState();
}

class _InvitePosterPageState extends State<InvitePosterPage> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _saving = false;

  Future<Uint8List?> _capture() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        ToastUtil.error('生成图片失败，请重试');
        return;
      }
      await ImgSaver.saveBytes(bytes, name: 'invite_${widget.code}');
    } catch (e) {
      ToastUtil.error('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final bytes = await _capture();
    if (bytes == null) {
      ToastUtil.error('生成图片失败');
      return;
    }
    try {
      await Share.shareXFiles([
        XFile.fromData(bytes, mimeType: 'image/png', name: 'invite.png'),
      ], text: '我的邀请码：${widget.code}');
    } catch (_) {
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.landingUrl.isEmpty
        ? 'https://flrjk.52yfx.cn/?ref=${widget.code}'
        : widget.landingUrl.replaceAll('{code}', widget.code);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1017),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1017),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '邀请海报',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: SizedBox(width: 330, child: _poster(url)),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 17),
                      label: Text(_saving ? '生成中…' : '保存图片'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withAlpha(50)),
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _share,
                      icon: const Icon(Icons.share_rounded, size: 17),
                      label: const Text('分享'),
                      style: FilledButton.styleFrom(
                        backgroundColor: C.brand,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster(String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4B5EF5), Color(0xFF7C4DFF), Color(0xFF9B5CF6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B5EF5).withAlpha(90),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // 装饰圆
            Positioned(
              right: -46,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(20),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: 120,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部：Logo + 名称
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.logoUrl.isEmpty
                            ? Icon(Icons.apps_rounded, color: C.brand, size: 24)
                            : Image.network(
                                widget.logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.apps_rounded,
                                  color: C.brand,
                                  size: 24,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    widget.slogan,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '注册时填写邀请码，你我各得积分',
                    style: TextStyle(
                      color: Colors.white.withAlpha(215),
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 26),
                  // 卡片：二维码 + 邀请码
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        QrImageView(
                          data: url,
                          version: QrVersions.auto,
                          size: 92,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF151823),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF151823),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '我的邀请码',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.black.withAlpha(120),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.code.isEmpty ? '—' : widget.code,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF4B5EF5),
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '扫码下载 · 注册填码',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black.withAlpha(110),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '安逸软件汇 · 精选软件每日更新',
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
