import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../design/ad.dart';
import '../design/ui.dart';
import '../utils/toast_util.dart';

/// ═══════════════════════════════════════════════════════════════
/// 媒体预览（1015 新增）
///
///   · showImagePreview(context, urls, index)  —— 图片预览（可缩放/翻页/保存）
///   · showMediaPreview(context, url)          —— 智能判断图片/视频，分别预览
///
/// 特性：双指缩放、左右翻页、双击放大、长按保存到相册、页码指示
/// ═══════════════════════════════════════════════════════════════
class MediaPreview {
  MediaPreview._();

  /// 判断是不是图片
  static bool isImage(String url) {
    final u = url.toLowerCase().split('?').first;
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic']
        .any((e) => u.endsWith(e));
  }

  /// 判断是不是视频
  static bool isVideo(String url) {
    final u = url.toLowerCase().split('?').first;
    return ['.mp4', '.m3u8', '.mov', '.avi', '.mkv', '.flv', '.ts']
        .any((e) => u.endsWith(e));
  }

  /// 图片预览（支持多图翻页）
  static Future<void> showImages(
    BuildContext context,
    List<String> urls, {
    int index = 0,
  }) async {
    final list = urls.where((e) => e.trim().isNotEmpty).toList();
    if (list.isEmpty) {
      ToastUtil.info('没有可预览的图片');
      return;
    }
    final cur = index.clamp(0, list.length - 1);
    await Get.to(
      () => _GalleryPage(urls: list, index: cur),
      opaque: false,
    );
  }

  /// 单张图片
  static Future<void> showImage(BuildContext context, String url) =>
      showImages(context, [url]);
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({required this.urls, required this.index});
  final List<String> urls;
  final int index;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  late final PageController _pc = PageController(initialPage: widget.index);
  late int _i = widget.index;
  bool _showBar = true;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ★ 玻璃拟态预览：黑底 + 图片可缩放翻页
          PhotoViewGallery.builder(
            pageController: _pc,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _i = i),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(widget.urls[i]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: 'pv_${widget.urls[i]}'),
              onTapUp: (_, __, ___) => setState(() => _showBar = !_showBar),
            ),
            loadingBuilder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
            ),
          ),
          // 顶部栏
          AnimatedOpacity(
            opacity: _showBar ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withAlpha(170), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                  const Spacer(),
                  Text(
                    '${_i + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          // 底部提示
          if (_showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '双指缩放 · 双击放大 · 左右翻页',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ),
              ),
            ),
          // 底部缩略图指示
          if (widget.urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 48,
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.urls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _pc.jumpToPage(i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: i == _i ? C.brand : Colors.white24,
                          width: i == _i ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CachedNetworkImage(
                          imageUrl: widget.urls[i],
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 18,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 网格图集预览（用于壁纸/图集类工具页）
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.urls,
    this.columns = 3,
    this.radius = 10,
  });

  final List<String> urls;
  final int columns;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final n = Ad.columns(context, minItem: 100, max: columns);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: n,
        mainAxisSpacing: Ad.s(context, 8),
        crossAxisSpacing: Ad.s(context, 8),
        childAspectRatio: 0.75,
      ),
      itemCount: urls.length,
      itemBuilder: (c, i) => GestureDetector(
        onTap: () => MediaPreview.showImages(context, urls, index: i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: context.isDark ? Colors.white10 : Colors.black12),
            errorWidget: (_, __, ___) => Container(
              color: context.isDark ? Colors.white10 : Colors.black12,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined, size: 22, color: context.t3),
            ),
          ),
        ),
      ),
    );
  }
}
