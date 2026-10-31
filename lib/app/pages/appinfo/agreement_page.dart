import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

import '../../design/app_anim.dart';
import '../../api/soft_service.dart';
import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';

/// 用户协议 / 隐私政策（v40 重构）
///
/// 内容全部来自后台配置（sys_config 的 agreement / privacy），
/// 支持富文本（HTML），排版针对移动端优化。
class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key});

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  bool _loading = true;
  String _content = '';
  String _title = '用户协议';

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final type = (args is Map ? '${args['type'] ?? ''}' : '$args');
    _title = type == 'privacy' ? '隐私政策' : '用户协议';
    _load(type);
  }

  Future<void> _load(String type) async {
    try {
      final cfg = await SoftService.instance.fetchConfig();
      if (cfg != null) {
        _content = type == 'privacy' ? cfg.privacy : cfg.agreement;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPrivacy = _title == '隐私政策';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            4,
                            context.pagePadding,
                            context.tabSpace + 30,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _headCard(isPrivacy),
                              const SizedBox(height: 14),
                              if (_content.trim().isEmpty)
                                _emptyCard(isPrivacy)
                              else
                                KitCard(
                                  padding: const EdgeInsets.all(16),
                                  child: HtmlWidget(
                                    _content,
                                    textStyle: TextStyle(
                                      fontSize: 14,
                                      height: 1.85,
                                      color: context.isDark
                                          ? Colors.grey[300]
                                          : C.lt2,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 18),
                              Center(
                                child: Text(
                                  '如有疑问请联系管理员',
                                  style: Ty.tiny.copyWith(color: context.t3),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pagePadding,
        10,
        context.pagePadding,
        10,
      ),
      child: Row(
        children: [
          AppPressable(
            onTap: () => Get.back(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDark
                    ? Colors.white.withAlpha(14)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(8),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: context.t1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(_title, style: Ty.h2.copyWith(fontSize: 20, color: context.t1)),
        ],
      ),
    );
  }

  Widget _headCard(bool isPrivacy) {
    final color = isPrivacy ? C.pink : C.violet;
    final icon = isPrivacy
        ? Icons.privacy_tip_rounded
        : Icons.description_rounded;
    final desc = isPrivacy
        ? '我们非常重视你的隐私。本政策说明我们收集哪些信息、如何使用与保护它们。'
        : '使用本软件即表示你已阅读并同意以下条款，请仔细阅读。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(context.isDark ? 50 : 30),
            color.withAlpha(context.isDark ? 20 : 12),
          ],
        ),
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: Ty.h3.copyWith(fontSize: 15.5, color: context.t1),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: Ty.small.copyWith(
                    fontSize: 12,
                    height: 1.6,
                    color: context.t2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(bool isPrivacy) {
    return KitCard(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.article_outlined, size: 40, color: context.t3),
          const SizedBox(height: 14),
          Text(
            '${isPrivacy ? '隐私政策' : '用户协议'}暂未配置',
            style: Ty.h3.copyWith(fontSize: 14, color: context.t1),
          ),
          const SizedBox(height: 8),
          Text(
            '管理员可在「后台管理 → 配置」中填写内容',
            textAlign: TextAlign.center,
            style: Ty.small.copyWith(fontSize: 12, color: context.t3),
          ),
        ],
      ),
    );
  }
}
