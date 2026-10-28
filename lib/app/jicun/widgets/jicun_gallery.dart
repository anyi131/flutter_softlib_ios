import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 即存 · 全屏图片画廊
///
/// 黑底 PhotoViewGallery：双击 / 双指放大、左右翻页；
/// 顶部一条半透明黑底——左边关闭、中间「3 / 12」计数、右边可选「保存」。
/// 关闭走左上角 X（下拉手势留给 PhotoView 自己，避免和缩放拖动抢手势）。
class JicunGalleryPage extends StatefulWidget {
  const JicunGalleryPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.headers = const <String, String>{},
    this.onSave,
  });

  /// 原图地址列表，空字符串会在进页面前剔除
  final List<String> images;

  /// 打开时停在第几张（按剔除空地址后的顺序）
  final int initialIndex;

  /// 图片请求头（B 站图床要 Referer，见 jicunPlaybackHeaders）
  final Map<String, String> headers;

  /// 传了才显示「保存」按钮，参数是当前页码
  final Future<void> Function(int index)? onSave;

  @override
  State<JicunGalleryPage> createState() => _JicunGalleryPageState();
}

class _JicunGalleryPageState extends State<JicunGalleryPage> {
  late final List<String> _images;
  late final PageController _controller;
  late int _index;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 空地址会让 PhotoView 只画一个破图，进页面之前就剔掉
    _images = widget.images
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false);
    _index = _clamp(widget.initialIndex);
    _controller = PageController(initialPage: _index);
  }

  int _clamp(int raw) {
    if (_images.isEmpty) return 0;
    return raw < 0 ? 0 : (raw >= _images.length ? _images.length - 1 : raw);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final onSave = widget.onSave;
    if (onSave == null || _saving) return;
    setState(() => _saving = true);
    try {
      // 成功提示由调用方负责，避免和页面里的 Toast 重复
      await onSave(_index);
    } catch (_) {
      if (!mounted) return;
      _toast('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_images.isEmpty) _emptyView() else _gallery(),
          _topBar(context),
        ],
      ),
    );
  }

  Widget _gallery() {
    return PhotoViewGallery.builder(
      itemCount: _images.length,
      pageController: _controller,
      onPageChanged: (page) {
        if (page == _index) return;
        setState(() => _index = page);
      },
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        return PhotoViewGalleryPageOptions.customChild(
          // 用 Image 当 child 才拿得到 loading / error 回调
          child: Image.network(
            _images[index],
            headers: widget.headers,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                const _LoadFailed(),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        );
      },
    );
  }

  Widget _emptyView() {
    return const Center(
      child: Text(
        '没有可查看的图片',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withAlpha(120),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                if (_images.isNotEmpty)
                  Center(
                    child: Text(
                      '${_index + 1} / ${_images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.onSave != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(
                        onPressed: _saving ? null : _handleSave,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white54,
                          minimumSize: const Size(56, 40),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '保存',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单张图的加载失败占位：图标 + 一句话，保持黑底
class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 44, color: Colors.white60),
          SizedBox(height: 10),
          Text(
            '图片加载失败',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
