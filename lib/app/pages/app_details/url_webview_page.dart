import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 通用内置网页（url_type=webview 的软件/文章类内容）
///
/// ★ 1105x：从 webview_flutter 换成 flutter_inappwebview
///   · 支持请求拦截（外部 scheme 交给系统浏览器）
///   · 支持 JS 弹窗/新窗口、文件下载回调
///   · 加载失败可重试，进度条更准
class UrlWebviewPage extends StatefulWidget {
  const UrlWebviewPage({super.key});

  @override
  State<UrlWebviewPage> createState() => _UrlWebviewPageState();
}

class _UrlWebviewPageState extends State<UrlWebviewPage> {
  late String _url;
  late String _title;
  InAppWebViewController? _web;
  bool _loading = true;
  bool _failed = false;
  double _progress = 0;

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
  }

  Future<void> _openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ToastUtil.error('无法打开该链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg1 : C.lbg1,
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              setState(() => _failed = false);
              _web?.reload();
            },
          ),
          IconButton(
            tooltip: '浏览器打开',
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
            onPressed: () => _openExternal(_url),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading)
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: _progress <= 0 ? null : _progress / 100,
                minHeight: 2,
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_url)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    useShouldOverrideUrlLoading: true,
                    mediaPlaybackRequiresUserGesture: false,
                    supportZoom: true,
                    allowsBackForwardNavigationGestures: true,
                    transparentBackground: false,
                  ),
                  onWebViewCreated: (c) => _web = c,
                  onLoadStart: (c, url) {
                    if (mounted) setState(() => _loading = true);
                  },
                  onProgressChanged: (c, p) {
                    if (mounted) setState(() => _progress = p.toDouble());
                  },
                  onLoadStop: (c, url) {
                    if (mounted) setState(() => _loading = false);
                  },
                  onReceivedError: (c, req, err) {
                    if (mounted && req.isForMainFrame == true) {
                      setState(() {
                        _loading = false;
                        _failed = true;
                      });
                    }
                  },
                  shouldOverrideUrlLoading: (c, action) async {
                    final u = action.request.url?.toString() ?? '';
                    // 非 http(s) 的 scheme（tel:/mailto:/支付宝等）交给系统
                    if (u.isNotEmpty &&
                        !u.startsWith('http://') &&
                        !u.startsWith('https://')) {
                      await _openExternal(u);
                      return NavigationActionPolicy.CANCEL;
                    }
                    return NavigationActionPolicy.ALLOW;
                  },
                ),
                if (_failed)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 40, color: context.t3),
                        const SizedBox(height: 12),
                        Text('页面加载失败',
                            style: TextStyle(fontSize: 14, color: context.t2)),
                        const SizedBox(height: 14),
                        PrimaryButton(
                          label: '重试',
                          expand: false,
                          height: 40,
                          onPressed: () {
                            setState(() => _failed = false);
                            _web?.loadUrl(
                              urlRequest: URLRequest(url: WebUri(_url)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
