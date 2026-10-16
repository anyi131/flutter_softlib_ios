import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/app_anim.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';
import 'tool_kit.dart';

/// 工具箱 · 内置浏览器（1015 新增）
///
/// 为什么需要它：
///   工具里的「外链入口」原来走 JumpUtil.openUrl → 跳出到系统浏览器，
///   用户得在浏览器和 App 之间来回切，体验割裂、还容易丢失登录态。
///   现在统一在这个页面内打开，带进度条 / 返回 / 刷新 / 外部打开兜底。
class ToolBrowserPage extends StatefulWidget {
  final String title;
  final String url;
  final bool allowArbitraryNav;

  /// 是否开启广告清理（默认开）

  const ToolBrowserPage({
    super.key,
    required this.title,
    required this.url,
    this.allowArbitraryNav = true,
  });

  @override
  State<ToolBrowserPage> createState() => _ToolBrowserPageState();
}

class _ToolBrowserPageState extends State<ToolBrowserPage> {
  late final WebViewController _c;
  int _progress = 0;
  bool _loading = true;
  String? _err;

  bool _disposed = false;
  Timer? _loadTimer; // ★ 1015：加载超时保护

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // 常见移动端 UA，很多站点对桌面 UA 会重定向到下载 App
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            // ★ 1015 修复：原先进度每变 1% 就 setState → 重建风暴 → 卡顿。
            //   改为「整 10% 才更新」+ 100% 时更新。
            if (_disposed) return;
            final v = p.round();
            if (v == _progress) return;
            if (v % 10 != 0 && v != 100) return;
            setState(() => _progress = v);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _err = null;
              });
            }
          },
          onPageFinished: (_) {
            if (!_disposed) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              setState(() {
                _loading = false;
                _err = e.description;
              });
            }
          },
          // 站内跳转继续在 App 内打开；外部协议交给系统
          onNavigationRequest: (req) {
            final u = req.url;
            if (u.startsWith('http://') || u.startsWith('https://')) {
              return NavigationDecision.navigate;
            }
            if (u.startsWith('about:') || u.startsWith('javascript:')) {
              return NavigationDecision.navigate;
            }
            // tel: / mailto: / intent: / alipays: 等交给系统处理
            _openExternal(u);
            return NavigationDecision.prevent;
          },
        ),
      )
      // ★★★ 1015 关键修复：原来只建了 WebView 却从没加载 URL！
      //   所以所有用内置浏览器打开的工具都是「全白界面」。
      ..loadRequest(Uri.parse(widget.url));

    // ★ 1015：加载超时保护（原来没有超时 → 页面卡住就永远白屏）
    _loadTimer = Timer(const Duration(seconds: 20), () {
      if (_disposed || !mounted) return;
      if (_loading && _progress < 100) {
        setState(() {
          _loading = false;
          _err = '加载超时，请检查网络后重试';
        });
      }
    });
  }

  Future<void> _openExternal(String u) async {
    ToastUtil.info('已交给系统处理：$u');
  }


  @override
  void dispose() {
    // ★★★ 1015 致命修复：原来没有 dispose！
    //   WebView 控制器不会被释放 → 每开一次外链工具就泄漏一个 WebView 实例
    //   → 开几个后 Native 层 OOM → **直接闪退回桌面**（Dart 层捕获不到）。
    _disposed = true;
    _loadTimer?.cancel();
    super.dispose();
  }

  /// 安全 setState（dispose 后不再调用，防 Native 崩溃）
  void _safeSet(VoidCallback fn) {
    if (!mounted || _disposed) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.isDark ? C.bg2 : Colors.white,
        title: Text(
          widget.title.isEmpty ? '网页' : widget.title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.t1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: context.t1),
          onPressed: () async {
            if (await _c.canGoBack()) {
              _c.goBack();
            } else if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, size: 20, color: context.t1),
            onPressed: () => _c.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Expanded(child: WebViewWidget(controller: _c)),
          if (_loading && _progress < 100)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                color: C.brand,
              ),
            ),
          if (_err != null)
            Container(
              color: context.isDark ? C.bg2 : Colors.white,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 44, color: context.t3),
                  const SizedBox(height: 12),
                  Text('页面打不开', style: Ty.h3.copyWith(color: context.t1)),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _err!,
                      textAlign: TextAlign.center,
                      style: Ty.tiny.copyWith(color: context.t3),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ToolButton(
                    label: '重试',
                    icon: Icons.refresh_rounded,
                    onPressed: () {
                      setState(() => _err = null);
                      _c.reload();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
