// 1031r：app_links 接入——Deep Link 分享直达
//
// 链接格式（分享文案里的 shareUrl 可逐步换成这些）：
//   softlib://app?id=123            → 软件详情
//   softlib://post?id=45            → 帖子详情
//   softlib://message               → 消息中心
//   softlib://invite?code=XXXX      → 邀请页（带邀请码）
//   softlib://vip                   → 会员页
// 同时兼容 https://<host>/app?id=123 形式（浏览器打开再唤起由后续 App Links 补）。
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../routes/app_pages.dart';
import 'toast_util.dart';

class DeepLinks {
  DeepLinks._();
  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static bool _bound = false;

  /// 启动绑定：冷启动直达（getInitialLink）+ 运行中唤醒（uriLinkStream）
  static void bind() {
    if (_bound) return;
    _bound = true;
    // 冷启动：App 已被链接拉起时拿初始链接
    () async {
      try {
        final Uri? initial = await _links.getInitialLink();
        if (initial != null) _open(initial);
      } catch (_) {}
    }();
    // 运行中：App 在后台被链接再次拉起
    _sub = _links.uriLinkStream.listen(
      (uri) => _open(uri),
      onError: (_) {},
    );
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _bound = false;
  }

  static void _open(Uri uri) {
    // 兜底延迟：冷启动时 GetMaterialApp 可能还没就绪
    Future.delayed(const Duration(milliseconds: 600), () => _route(uri));
  }

  static void _route(Uri uri) {
    try {
      final host = uri.host.toLowerCase();
      final path = uri.path.replaceFirst('/', '');
      // softlib://app?id=1 或 https://host/app?id=1
      final page =
          host == 'app' ? 'app' : (host.isEmpty ? path : host);
      final id = uri.queryParameters['id'] ?? '';
      switch (page) {
        case 'app':
          if (id.isNotEmpty) {
            Get.toNamed(Routes.appDetails,
                arguments: {'appId': id, 'item': null});
          }
          break;
        case 'post':
          if (id.isNotEmpty) {
            Get.toNamed(Routes.postDetail, arguments: {'id': id});
          }
          break;
        case 'message':
          Get.toNamed(Routes.message);
          break;
        case 'invite':
          Get.toNamed(Routes.invite,
              arguments: {'code': uri.queryParameters['code'] ?? ''});
          break;
        case 'vip':
          Get.toNamed(Routes.vip);
          break;
        default:
          ToastUtil.info('暂不支持打开该链接');
      }
    } catch (_) {}
  }
}
