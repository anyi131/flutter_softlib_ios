import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../jicun/jicun_save_album.dart';
import '../../../utils/toast_util.dart';

/// ★ 1107e 图片九宫格 + 全屏查看（对照 ARC 的 post images 布局）
///   1 张：16:9 宽图
///   2-3 张：三等分方图
///   4+ 张：三列九宫格（最多显示 9 张）
class PostGallery extends StatelessWidget {
  const PostGallery({
    super.key,
    required this.images,
    this.maxVisible = 9,
    this.radius = 8,
    this.allImages,
  });

  final List<String> images;

  /// 1109h：全屏查看用的完整列表（正文图 + 九宫格图）。
  ///   为空时退回 images 本身。修复「点开只能看 1/1」。
  final List<String>? allImages;
  final int maxVisible;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imgs = images.where((e) => e.isNotEmpty).take(maxVisible).toList();
    if (imgs.isEmpty) return const SizedBox.shrink();

    if (imgs.length == 1) {
      return GestureDetector(
        onTap: () => showImageGallery(context, allImages ?? imgs,
                (allImages ?? imgs).indexOf(imgs.first)),
        onLongPress: () => saveForumImage(imgs.first),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
                imageUrl: imgs.first,
                fit: BoxFit.cover,
                memCacheWidth: 720,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (_, __) => Container(color: const Color(0xFFEDEFF4)),
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
          ),
        ),
      );
    }

    // 1109h：4 张图用 2×2，不要 3+1 ——
    //   3 列时第二行只有 1 张，列表卡片高度不够会被裁掉，看起来「4 图只显示 3 张」。
    final int cols;
    if (imgs.length == 4) {
      cols = 2;
    } else if (imgs.length <= 3) {
      cols = imgs.length;
    } else {
      cols = 3;
    }
    return LayoutBuilder(builder: (c, box) {
      const gap = 4.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (int i = 0; i < imgs.length; i++)
            GestureDetector(
              onTap: () => showImageGallery(context, allImages ?? imgs,
                    (allImages ?? imgs).indexOf(imgs[i])),
              onLongPress: () => saveForumImage(imgs[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: w,
                  height: w,
                  child: CachedNetworkImage(
                    imageUrl: imgs[i],
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 120),
                    placeholder: (_, __) => Container(color: const Color(0xFFEDEFF4)),
                    errorWidget: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}


/// 1109：长按/按钮保存图片到系统相册
Future<void> saveForumImage(String url) async {
  try {
    final dir = await getTemporaryDirectory();
    final name = 'anyi_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${dir.path}/$name';
    await Dio().download(url, path);
    final r = await jicunSaveToAlbum(path, kind: 'image', displayName: name);
    if (r.ok) {
      ToastUtil.success(r.message.isEmpty ? '已保存到相册' : r.message);
    } else {
      ToastUtil.error(r.message.isEmpty ? '保存失败' : r.message);
    }
  } catch (_) {
    ToastUtil.error('保存失败，请重试');
  }
}

/// 全屏查看：左右滑动 + 双指缩放
void showImageGallery(BuildContext context, List<String> images, int index) {
  showDialog(
    context: context,
    barrierColor: Colors.black,
    builder: (_) => _GalleryDialog(images: images, index: index),
  );
}

class _GalleryDialog extends StatefulWidget {
  const _GalleryDialog({required this.images, required this.index});
  final List<String> images;
  final int index;

  @override
  State<_GalleryDialog> createState() => _GalleryDialogState();
}

class _GalleryDialogState extends State<_GalleryDialog> {
  late final PageController _p = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _p,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (c, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  memCacheWidth: 1440,
                  placeholder: (_, __) => const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                      color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: '保存到相册',
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                onPressed: () => saveForumImage(widget.images[_i]),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text('${_i + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
