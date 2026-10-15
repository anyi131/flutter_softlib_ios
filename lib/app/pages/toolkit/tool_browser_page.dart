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
  final bool blockAds;

  const ToolBrowserPage({
    super.key,
    required this.title,
    required this.url,
    this.allowArbitraryNav = true,
    this.blockAds = true,
  });

  @override
  State<ToolBrowserPage> createState() => _ToolBrowserPageState();
}

class _ToolBrowserPageState extends State<ToolBrowserPage> {
  late final WebViewController _c;
  int _progress = 0;
  bool _loading = true;
  String? _err;
  late bool _adBlock = widget.blockAds;

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
            if (mounted) setState(() => _progress = p);
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
            if (mounted) setState(() => _loading = false);
            if (_adBlock) _cleanAds();
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
  }

  Future<void> _openExternal(String u) async {
    ToastUtil.info('已交给系统处理：$u');
  }

  /// ★ 1015：页面内广告清理
  ///   思路：注入一段 JS，做三件事
  ///     ① CSS 隐藏常见广告位（class/id 含 ad/banner/popup/promo 等）
  ///     ② 干掉全屏浮层广告 + 自动播放的弹窗
  ///     ③ 定时重复执行（有些广告是懒加载，加载完才插进来）
  ///   注意：不做任何「拦截网络请求」的事，只隐藏页面元素 —— 更稳，也不影响正常内容。
  Future<void> _cleanAds() async {
    const js = r'''
(function () {
  if (window.__anyiAdClean) return;
  window.__anyiAdClean = true;

  var CSS = `
    /* 常见广告容器 */
    [class*="ad-"], [class*="ads-"], [class*="advert"], [class*="banner-ad"],
    [id*="ad-"], [id*="ads-"], [id*="advert"],
    .ad, .ads, .adsbygoogle, .advertisement, .ad-container, .ad-wrapper,
    [class*="popup-ad"], [class*="pop-ad"], [class*="float-ad"],
    [class*="gg-"], [class*="guanggao"], [class*="tuiguang"],
    iframe[src*="doubleclick"], iframe[src*="googlesyndication"],
    iframe[src*="cpro.baidu"], iframe[src*="pos.baidu"],
    [class*="download-app"], [class*="openapp"], [class*="app-guide"],
    [class*="float-layer"], [class*="mask-ad"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      overflow: hidden !important;
    }
    /* 底部悬浮广告条 / 全屏遮罩 */
    body > div[style*="position: fixed"][style*="bottom"],
    body > div[style*="position:fixed"][style*="bottom"] {
      display: none !important;
    }
  `;
  var st = document.createElement('style');
  st.type = 'text/css';
  st.appendChild(document.createTextNode(CSS));
  (document.head || document.documentElement).appendChild(st);

  // ② 干掉看起来像广告的浮层：固定定位 + 覆盖大半屏幕 + 层级很高
  function killOverlays() {
    var all = document.body ? document.body.children : [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      try {
        var s = getComputedStyle(el);
        if (s.position !== 'fixed' && s.position !== 'absolute') continue;
        var z = parseInt(s.zIndex || '0', 10);
        var r = el.getBoundingClientRect();
        if (z > 100 && r.width > window.innerWidth * 0.7 && r.height > window.innerHeight * 0.5) {
          var txt = (el.innerText || '').slice(0, 60);
          // 含这些关键词才判定为广告浮层，避免误伤正常弹窗（登录/提示）
          if (/广告|下载APP|打开APP|立即下载|打开软件|点击下载|打开应用/.test(txt)) {
            el.style.display = 'none';
          }
        }
      } catch (e) {}
    }
  }

  // ③ 兜底：清掉 body 的滚动锁（有些广告会给 body 加 overflow:hidden）
  function unlockScroll() {
    try {
      if (document.body && getComputedStyle(document.body).overflow === 'hidden') {
        var hasBigFixed = false;
        var ch = document.body.children;
        for (var i = 0; i < ch.length; i++) {
          var s = getComputedStyle(ch[i]);
          if (s.position === 'fixed' && ch[i].getBoundingClientRect().height > window.innerHeight * 0.8) {
            hasBigFixed = true; break;
          }
        }
        if (!hasBigFixed) document.body.style.overflow = 'auto';
      }
    } catch (e) {}
  }

  var n = 0;
  var t = setInterval(function () {
    killOverlays();
    unlockScroll();
    if (++n > 10) clearInterval(t);   // 最多跑 10 轮（约 10 秒）就停，避免耗电
  }, 1000);
  killOverlays();
})();
''';
    try {
      await _c.runJavaScript(js);
    } catch (_) {}
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
            icon: Icon(
              _adBlock ? Icons.shield_rounded : Icons.shield_outlined,
              size: 20,
              color: _adBlock ? C.brand : context.t3,
            ),
            tooltip: _adBlock ? '广告清理已开' : '广告清理已关',
            onPressed: () {
              setState(() => _adBlock = !_adBlock);
              if (_adBlock) {
                _cleanAds();
              } else {
                _c.reload(); // 关掉就重载，恢复原始页面
              }
              ToastUtil.info(_adBlock ? '已开启广告清理' : '已关闭广告清理');
            },
          ),
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
