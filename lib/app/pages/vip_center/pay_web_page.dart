import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api/pay_service.dart';
import '../../api/user_service.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// App 内支付页（不跳转外部浏览器）
///
/// 流程：打开收银台 URL → 用户完成支付 →
///   · 命中 return_url（同步跳转）→ 直接判定完成
///   · 同时后台轮询订单状态兜底（部分支付渠道不回归 return_url）
/// 到账后自动返回并刷新会员状态。
class PayWebPage extends StatefulWidget {
  const PayWebPage({super.key});

  @override
  State<PayWebPage> createState() => _PayWebPageState();
}

class _PayWebPageState extends State<PayWebPage> {
  late final String _url;
  late final String _outTradeNo;
  late final String _amount;

  /// 完成后的回调（余额充值用它刷新余额；会员续费不传）
  Future<void> Function()? _onReturn;
  late final String _title;
  late final WebViewController _controller;
  Timer? _poll;
  bool _done = false;
  bool _loading = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final m = args is Map ? args : const {};
    _url = (m['pay_url'] ?? '').toString();
    _outTradeNo = (m['out_trade_no'] ?? '').toString();
    _amount = (m['money'] ?? '').toString();
    _title = (m['title'] ?? '会员开通').toString();
    final cb = m['onReturn'];
    if (cb is Future<void> Function()) _onReturn = cb;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          // ★ 1015：加载失败兜底
          onWebResourceError: (e) {
            if (mounted && e.isForMainFrame == true) {
              setState(() => _loading = false);
            }
          },
          onPageStarted: (u) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (u) {
            if (mounted) setState(() => _loading = false);
            // 命中支付站的同步返回地址 → 认为已支付
            if (u.contains('/api/softlib/pay/return')) {
              _finish(true);
            }
          },
          onProgress: (p) {
            // ★ 1015 性能：进度的每 1% 都 setState 会引发重建风暴 → 卡顿
            if (mounted &&
                (p.round() % 10 == 0 || p.round() == 100) &&
                _progress != p.round()) {
              setState(() => _progress = p.round());
            }
          },
          onNavigationRequest: (req) {
            // 拦截支付完成后的同步跳转，避免加载到我们自己的结果页
            if (req.url.contains('/api/softlib/pay/return')) {
              _finish(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_url));

    // 兜底轮询：有些渠道不会回归 return_url
    _startPolling();
  }

  void _startPolling() {
    var tick = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (_done) {
        t.cancel();
        return;
      }
      tick++;
      if (await PayService.instance.isPaid(_outTradeNo)) {
        _finish(true);
        return;
      }
      if (tick > 200) t.cancel(); // 10 分钟
    });
  }

  Future<void> _finish(bool paid) async {
    if (_done) return;
    _done = true;
    _poll?.cancel();
    if (paid) {
      await UserService.instance.refreshProfile();
      if (_onReturn != null) {
        try {
          await _onReturn!();
        } catch (_) {}
      }
      if (mounted) {
        ToastUtil.success('支付成功，已到账');
        Get.back(result: true);
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : C.lbg0,
      body: Column(
        children: [
          // 顶栏：标题 + 金额 + 关闭
          Container(
            padding: EdgeInsets.only(
              top: topInset + 6,
              bottom: 10,
              left: 12,
              right: 12,
            ),
            color: context.isDark ? C.bg1 : Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? Colors.white.withAlpha(14)
                          : Colors.black.withAlpha(6),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        style: Ty.h3.copyWith(fontSize: 15, color: context.t1),
                      ),
                      if (_amount.isNotEmpty)
                        Text(
                          '应付 ¥$_amount',
                          style: Ty.tiny.copyWith(color: C.gold),
                        ),
                    ],
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          // 进度条
          if (_loading && _progress > 0 && _progress < 100)
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
