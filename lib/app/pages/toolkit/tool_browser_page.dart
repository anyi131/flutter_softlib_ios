import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/app_anim.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../api/soft_service.dart';
import '../../utils/img_saver.dart';
import '../../utils/toast_util.dart';
import '../../widgets/media_preview.dart';
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
      // ★ 1029：内置网页桥 —— 解决 WebView 里「保存图片 / 新窗口」全部失灵
      ..addJavaScriptChannel('MinisWeb', onMessageReceived: _onJsMessage)
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
          onPageFinished: (u) {
            if (!_disposed) {
              setState(() {
                _loading = false;
                // ★ 1029：慢页面 20s 超时后就算最终加载完，超时遮罩原来会一直盖在上面
                //   （用户以为彻底打不开）——页面只要 finish 就撤掉
                if (_err == '加载超时') _err = null;
              });
            }
            // ★ 1029：每个页面加载完都补一次桥脚本（有些站会整页替换 document）
            _injectShim(u);
          },
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              setState(() {
                _loading = false;
                _err = e.description;
              });
              // ★ 1016：外链工具打不开时上报（后台可查 fa_softlib_crash_log）
              try {
                SoftService.reportLogStatic(
                  tag: 'tool',
                  error:
                      '[webview] ${widget.title} ${widget.url} -> ${e.errorCode} ${e.description}',
                ).catchError((_) {});
              } catch (_) {}
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
            // ★ 1029：blob:/data: 下载链接不能交给系统（launchUrl 打不开）——
            //   这正是「保存图片点了没反应」的另一条死路
            if (u.startsWith('blob:') || u.startsWith('data:')) {
              return NavigationDecision.prevent;
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

  /// ★★★ 1015 致命修复（164 个外链工具全部卡死的真因）：
  ///   原来这里弹 Toast「已交给系统处理：$u」。
  ///   但 onNavigationRequest 在页面加载期间会被**调用几十上百次**
  ///   （每个资源请求、每次重定向都触发），于是弹了几十个 Toast → UI 卡死。
  ///   修复：① 用系统真正打开该协议（原来只是弹提示，没真跳转）
  ///        ② 去掉 Toast（避免风暴）
  ///
  /// ★★★ 1015 致命修复（164 个外链工具全部卡死的真因）：
  ///   原来这里弹 Toast「已交给系统处理：$u」。
  ///   但 onNavigationRequest 在页面加载期间会被**调用几十上百次**
  ///   （每个资源请求、每次重定向都触发），于是弹了几十个 Toast → UI 卡死。
  ///   修复：① 用系统真正打开该协议（原来只是弹提示，没真跳转）
  ///        ② 去掉 Toast（避免风暴）
  ///
  /// ★ 1016：只保留「2 秒内同一地址只尝试一次」的去抖 —— 其它一律照原样放行，
  ///   不再做协议白名单（白名单会把一些工具的正常跳转挡掉，属于误伤）。
  /// ★ 1029：注入给所有内置网页用的「补丁脚本」
  ///
  /// 为什么必须打这个补丁（淘宝买家秀/图集秀这类页面的通病）：
  ///   ① WebView 没有 download delegate：`<a download>` + `blob:` 点了一点反应都没有
  ///      （页面自己的保存按钮就是这么写的，还会假提示「已开始下载」）
  ///   ② WebView 没有 onCreateWindow：`window.open(url,'_blank')` 直接返回 null
  ///      （上面那个页面的保存兜底就是 window.open → 同样死路）
  ///   ③ WKWebView 长按图片没有系统菜单，用户连"存储图像"都找不到
  /// 补丁做三件事：window.open 变本页跳转；a[download]/blob 交给 App 存相册；
  /// 长按图片弹 App 自己的预览（可保存）。
  static const String _shimJs = r'''
(function(){
  if (window.__anyiWebShim) { return; }
  window.__anyiWebShim = 1;
  function post(o){ try { MinisWeb.postMessage(JSON.stringify(o)); } catch(e){} }
  try {
    window.open = function(u){ if (u) { post({t:'open', u:String(u)}); } return null; };
  } catch(e){}
  document.addEventListener('click', function(e){
    var a = e.target && e.target.closest ? e.target.closest('a[download]') : null;
    if (!a) { return; }
    var href = a.href || a.getAttribute('href') || '';
    var name = a.getAttribute('download') || '';
    if (!href) { return; }
    e.preventDefault(); e.stopPropagation();
    if (href.indexOf('blob:') === 0) {
      fetch(href).then(function(r){ return r.blob(); }).then(function(b){
        var fr = new FileReader();
        fr.onload = function(){ post({t:'blob', d:String(fr.result), n:name, m:b.type||''}); };
        fr.onerror = function(){ post({t:'err', m:'图片读取失败'}); };
        fr.readAsDataURL(b);
      }).catch(function(){ post({t:'err', m:'图片读取失败'}); });
    } else {
      post({t:'save', u:href, n:name});
    }
  }, true);
  // 长按图片：http 的交给 App 预览；blob: 的（页面自己缓存下来的那张）
  // 不能给 App 当网址用，就地读成 dataURL 再交给 App
  function sendImg(el){
    var u = el.currentSrc || el.src || '';
    if (!u) { return; }
    if (u.indexOf('blob:') === 0) {
      fetch(u).then(function(r){ return r.blob(); }).then(function(b){
        var fr = new FileReader();
        fr.onload = function(){ post({t:'blob', d:String(fr.result), n:'', m:b.type||''}); };
        fr.onerror = function(){ post({t:'err', m:'图片读取失败'}); };
        fr.readAsDataURL(b);
      }).catch(function(){ post({t:'err', m:'图片读取失败'}); });
    } else {
      post({t:'img', u:u});
    }
  }
  var hold = null;
  function clearHold(){ if (hold) { clearTimeout(hold); hold = null; } }
  document.addEventListener('touchstart', function(e){
    var el = e.target;
    if (el && el.tagName === 'IMG') {
      clearHold();
      hold = setTimeout(function(){ sendImg(el); }, 520);
    }
  }, true);
  ['touchend','touchmove','touchcancel','scroll'].forEach(function(k){
    document.addEventListener(k, clearHold, true);
  });
  document.addEventListener('contextmenu', function(e){
    var el = e.target;
    if (el && el.tagName === 'IMG') {
      e.preventDefault();
      sendImg(el);
    }
  }, true);
})();
''';

  void _injectShim(String url) {
    if (_disposed) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;
    _c.runJavaScript(_shimJs).catchError((_) {});
  }

  /// JS 桥回调
  void _onJsMessage(JavaScriptMessage msg) {
    if (_disposed || !mounted) return;
    Map<String, dynamic> m;
    try {
      final o = jsonDecode(msg.message);
      if (o is! Map) return;
      m = Map<String, dynamic>.from(o);
    } catch (_) {
      return;
    }
    final t = '${m['t'] ?? ''}';
    final u = '${m['u'] ?? ''}'.trim();
    final n = '${m['n'] ?? ''}'.trim();
    switch (t) {
      case 'img':
        if (u.startsWith('http') || u.startsWith('data:')) {
          MediaPreview.showImages(context, [u]);
        }
        break;
      case 'save':
        if (u.startsWith('http')) {
          if (_isFileLink(u) || _isFileLink(n)) {
            _openExternal(u);
          } else {
            ImgSaver.saveUrl(u, name: _cleanName(n));
          }
        }
        break;
      case 'blob':
        final d = '${m['d'] ?? ''}';
        final mime = '${m['m'] ?? ''}';
        if (d.startsWith('data:')) {
          if (mime.isEmpty || mime.startsWith('image/')) {
            _saveDataUrl(d, n);
          } else {
            ToastUtil.info('该文件不支持在 App 内下载，请用浏览器打开');
          }
        }
        break;
      case 'open':
        if (u.isEmpty || u == 'about:blank') return;
        if (u.startsWith('http://') || u.startsWith('https://')) {
          _c.loadRequest(Uri.parse(u));
        } else if (!u.startsWith('blob:') && !u.startsWith('data:')) {
          _openExternal(u);
        }
        break;
      case 'err':
        ToastUtil.error('${m['m'] ?? '操作失败'}');
        break;
    }
  }

  bool _isFileLink(String s) {
    final v = s.toLowerCase();
    return ['.apk', '.zip', '.rar', '.7z', '.pdf', '.doc', '.xls']
        .any((e) => v.contains(e));
  }

  /// 网页里的文件名常带乱码（「ä¹°å®¶ç§_1793.jpg」），这里只留安全字符，
  /// 剩下的用时间戳，避免相册里出现一堆看不懂的名字
  String? _cleanName(String n) {
    if (n.trim().isEmpty) return null;
    final base = n.split('/').last;
    final dot = base.lastIndexOf('.');
    var stem = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot).toLowerCase() : '.jpg';
    stem = stem.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    if (stem.length < 2) return null;
    if (stem.length > 40) stem = stem.substring(0, 40);
    return 'anyi_$stem$ext';
  }

  Future<void> _saveDataUrl(String data, String name) async {
    try {
      final i = data.indexOf(',');
      final bytes = base64Decode(i >= 0 ? data.substring(i + 1) : data);
      final nm = _cleanName(name) ??
          'anyi_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await ImgSaver.saveBytes(bytes, name: nm);
    } catch (_) {
      ToastUtil.error('保存失败，请用浏览器打开后再保存');
    }
  }

  String _lastExternal = '';
  int _lastExternalAt = 0;

  Future<void> _openExternal(String u) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (u == _lastExternal && now - _lastExternalAt < 2000) return; // 去抖
    _lastExternal = u;
    _lastExternalAt = now;
    try {
      await launchUrlString(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 打不开就算了（不要弹 Toast，避免风暴）
    }
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.t1,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: context.t1,
          ),
          onPressed: () async {
            if (await _c.canGoBack()) {
              _c.goBack();
            } else if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          // ★ 1029：内置浏览器兜底入口常驻 —— 页面里有 App 处理不了的操作时，
          //   用户不用先「失败」才能找到系统浏览器
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, size: 19, color: context.t1),
            tooltip: '用浏览器打开',
            onPressed: () async {
              final u = await _c.currentUrl() ?? widget.url;
              launchUrlString(u, mode: LaunchMode.externalApplication);
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
          Positioned.fill(child: WebViewWidget(controller: _c)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ToolButton(
                        label: '重试',
                        icon: Icons.refresh_rounded,
                        onPressed: () {
                          setState(() => _err = null);
                          _c.reload();
                        },
                      ),
                      const SizedBox(width: 10),
                      // ★ 1016：内置 WebView 打不开时，允许用系统浏览器打开（兜底可用）
                      ToolButton(
                        label: '用浏览器打开',
                        icon: Icons.open_in_new_rounded,
                        onPressed: () => launchUrlString(
                          widget.url,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
