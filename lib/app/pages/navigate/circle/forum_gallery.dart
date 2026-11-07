import 'package:flutter/material.dart';

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
  });

  final List<String> images;
  final int maxVisible;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imgs = images.where((e) => e.isNotEmpty).take(maxVisible).toList();
    if (imgs.isEmpty) return const SizedBox.shrink();

    if (imgs.length == 1) {
      return GestureDetector(
        onTap: () => showImageGallery(context, imgs, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(imgs.first, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      );
    }

    final cols = imgs.length <= 3 ? imgs.length : 3;
    return LayoutBuilder(builder: (c, box) {
      const gap = 4.0;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (int i = 0; i < imgs.length; i++)
            GestureDetector(
              onTap: () => showImageGallery(context, imgs, i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: w,
                  height: w,
                  child: Image.network(imgs[i], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
        ],
      );
    });
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
                child: Image.network(widget.images[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image,
                        color: Colors.white54, size: 48)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
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
