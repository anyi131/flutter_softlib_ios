import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 通用内置网页（url_type=webview 的软件/文章类内容）
/// 复用 pay_web_page 的 WebViewController 方案，但不含支付轮询逻辑
class UrlWebviewPage extends StatefulWidget {
  const UrlWebviewPage({super.key});

  @override
  State<UrlWebviewPage> createState() => _UrlWebviewPageState();
}

class _UrlWebviewPageState extends State<UrlWebviewPage> {
  late String _url;
  late final String _title;
  late final WebViewController _controller;
  bool _loading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final m = args is Map ? args : const {};
    _url = (m['url'] ?? '').toString();
    _title = (m['title'] ?? '页面').toString();
    if (_url.isEmpty || Uri.tryParse(_url)?.hasScheme != true) {
      _url = 'about:blank';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ToastUtil.error('无效的网址');
      });
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onProgress: (p) {
          // ★ 1015 性能：进度的每 1% 都 setState 会引发重建风暴 → 卡顿
            if (mounted && (p.round() % 10 == 0 || p.round() == 100) && _progress != p.round()) {
              setState(() => _progress = p.round());
            }
        },
      ))
      ..loadRequest(Uri.parse(_url));
  }


  @override
  void dispose() {
    // ★★★ 1015 致命修复：WebView 页面原来没有 dispose！
    //   控制器不释放 → 每次打开泄漏一个 WebView → 多次后 Native OOM → 闪退回桌面。
    try {
      _controller.loadRequest(Uri.parse('about:blank')); // 先卸载页面释放网页资源
    } catch (_) {}
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        bottom: _progress > 0 && _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                    value: _progress / 100, minHeight: 2),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading && _progress == 0)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
