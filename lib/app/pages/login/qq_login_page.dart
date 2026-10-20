import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/app_anim.dart';
import '../../api/api_host.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';

/// QQ 快捷登录（WebView 走 QQ 网页授权）
///
/// 流程：打开本站的 qq_authorize → 跳转 QQ → 用户同意 → 回调页
/// 把 token 写进 `window.QQLOGIN`（base64）→ 这里读出来回传给登录页。
class QQLoginPage extends StatefulWidget {
  const QQLoginPage({super.key});

  @override
  State<QQLoginPage> createState() => _QQLoginPageState();
}

class _QQLoginPageState extends State<QQLoginPage> {
  late final WebViewController _c;
  bool _loading = true;
  bool _got = false;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // ★★ 1016：改**桌面 UA**！
      //   原来用手机 UA → QQ 授权页会尝试拉起 QQ 手机版（wtloginmqq://），
      //   第三方 WebView 里拉不起来，就卡在「正在拉起QQ手机版…」，永远登不了。
      //   桌面 UA 下 QQ 给的是「账号密码 + 扫码」网页登录，在 WebView 里能完整走完。
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          // ★ 1015：加载失败兜底
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              setState(() => _loading = false);
            }
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _loading = false);
            await _tryRead();
          },
          // ★ 1016：QQ 授权过程中可能触发 wtloginmqq:// 等私有协议。
          //   WebView 打不开会报 ERR_UNKNOWN_URL_SCHEME（页面「无法打开」），
          //   而且这类跳转在加载期可能被批量触发 → 一律**静默拦截**，
          //   只放行 tel:/mailto:，避免任何拉起风暴导致卡死。
          onNavigationRequest: (req) {
            final u = req.url;
            if (u.startsWith('http://') ||
                u.startsWith('https://') ||
                u.startsWith('about:') ||
                u.startsWith('javascript:')) {
              return NavigationDecision.navigate;
            }
            final low = u.toLowerCase();
            if (low.startsWith('tel:') || low.startsWith('mailto:')) {
              launchUrlString(
                u,
                mode: LaunchMode.externalApplication,
              ).catchError((_) => false);
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('${ApiHost.base}/api/softlib/user/qq_authorize'));
  }

  /// 回调页会把结果放在 window.QQLOGIN（base64 的 JSON）
  Future<void> _tryRead() async {
    if (_got) return;
    try {
      final raw = await _c.runJavaScriptReturningResult('window.QQLOGIN || ""');
      var v = raw.toString();
      if (v.isEmpty || v == '""' || v == 'null') return;
      v = v.replaceAll('"', '');
      final json = utf8.decode(base64.decode(v));
      final m = jsonDecode(json);
      if (m is Map && (m['token'] ?? '').toString().isNotEmpty) {
        _got = true;
        if (mounted) Get.back(result: Map<String, dynamic>.from(m));
      }
    } catch (_) {
      // 还没到回调页，忽略
    }
  }

  @override
  void dispose() {
    // ★★★ 1015 致命修复：WebView 页面原来没有 dispose！
    //   控制器不释放 → 每次打开泄漏一个 WebView → 多次后 Native OOM → 闪退回桌面。
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topInset + 50),
            child: WebViewWidget(controller: _c),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: topInset + 6,
                bottom: 10,
                left: 12,
                right: 12,
              ),
              color: Colors.white,
              child: Row(
                children: [
                  AppPressable(
                    onTap: Get.back,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.t1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'QQ 快捷登录',
                    style: Ty.h3.copyWith(fontSize: 15, color: context.t1),
                  ),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
