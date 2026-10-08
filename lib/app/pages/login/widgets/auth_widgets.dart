import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../api/soft_service.dart';
import '../../../models/ui_config.dart';
import '../../../design/adaptive.dart';
import '../../../design/kit.dart';
import '../../../design/ui.dart';

/// 认证页共用组件（登录 / 注册 / 找回）
///
/// v40 重构：三页统一视觉 —— 光晕背景 + 玻璃卡片 + 大圆角输入框，
/// 抽出共用件避免三份重复代码。

/// 页面外壳：光晕背景 + 返回按钮 + 标题
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.showBack = true,
  });

  @override
  /// v52m #8：auth_template classic / gradient / minimal
  List<Widget> _header(
      BuildContext context, String title, String subtitle, IconData icon) {
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.authTemplate ?? 'classic';
    if (tpl == 'gradient') {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            gradient: C.brandGradient,
            borderRadius: BorderRadius.circular(R.xl),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(46),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withAlpha(210),
                            fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
      ];
    }
    if (tpl == 'minimal') {
      return [
        Text(title,
            style: Ty.display.copyWith(color: context.t1)),
        const SizedBox(height: 7),
        Text(subtitle, style: Ty.small.copyWith(color: context.t3)),
        const SizedBox(height: 26),
      ];
    }
    if (tpl == 'banner_top') {
      // v52t：顶部全宽横幅（图占满，无圆角）
      return [
        Container(
          margin: const EdgeInsets.only(bottom: 22),
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
          decoration: BoxDecoration(gradient: C.brandGradient),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }
    if (tpl == 'centered') {
      // v52t：居中窄卡模板（小图标居中 + 居中标题）
      return [
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: Deco.brandGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(title,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.t1)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style: Ty.small.copyWith(color: context.t3)),
        ),
        const SizedBox(height: 26),
      ];
    }
    return [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: Deco.brandGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: C.brand.withAlpha(80),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
      const SizedBox(height: 18),
      ShaderMask(
        shaderCallback: (r) => Deco.aurora().createShader(r),
        child: Text(title, style: Ty.display.copyWith(color: Colors.white)),
      ),
      const SizedBox(height: 7),
      Text(subtitle, style: Ty.small.copyWith(color: context.t3)),
      const SizedBox(height: 26),
    ];
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  // 顶栏
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        context.pagePadding, 8, context.pagePadding, 0),
                    child: Row(
                      children: [
                        if (showBack)
                          GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
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
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 16, color: context.t1),
                            ),
                          ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          context.pagePadding, 12, context.pagePadding, 30),
                      children: [
                        // v52m #8：认证页三模板
                        ..._header(context, title, subtitle, icon),
                        const SizedBox(height: 26),
                        ...children,
                      ],
                    ),
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

/// 统一风格的输入框（玻璃质感 + 圆角 + 内联错误）
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final String? error;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final int? maxLength;
  final List<TextInputFormatter>? formatters;
  final Widget? suffix;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint = '',
    this.obscure = false,
    this.onToggleObscure,
    this.keyboard,
    this.action,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.maxLength,
    this.formatters,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withAlpha(10) : Colors.white,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(
              color: (error != null && error!.isNotEmpty)
                  ? C.danger.withAlpha(140)
                  : (context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(10)),
              width: (error != null && error!.isNotEmpty) ? 1.2 : 0.9,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: context.t3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboard,
                  textInputAction: action,
                  maxLength: maxLength,
                  inputFormatters: formatters,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
                  style: TextStyle(fontSize: 14.5, color: context.t1),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint.isEmpty ? null : hint,
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 15),
                    labelStyle: TextStyle(fontSize: 13.5, color: context.t3),
                    floatingLabelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: C.brand),
                  ),
                ),
              ),
              if (onToggleObscure != null)
                GestureDetector(
                  onTap: onToggleObscure,
                  child: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: context.t3),
                ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
        if (error != null && error!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6, top: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 13, color: C.danger),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(error!,
                      style: const TextStyle(
                          fontSize: 12, color: C.danger)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}

/// 服务器级错误条（内联，不遮挡）
class AuthError extends StatelessWidget {
  final String message;
  const AuthError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: C.danger.withAlpha(context.isDark ? 40 : 24),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.danger.withAlpha(90), width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: C.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13, color: C.danger, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// 主按钮（统一大圆角渐变）
class AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AuthButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : Deco.brandGradient,
          color: onPressed == null ? context.t3.withAlpha(60) : null,
          borderRadius: BorderRadius.circular(R.full),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: C.brand.withAlpha(90),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(R.full),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                        ],
                        Text(label,
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 玻璃卡片容器（包裹表单区）
class AuthCard extends StatelessWidget {
  final List<Widget> children;
  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Deco.glass(
      context,
      radius: R.xl,
      alpha: 0.07,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
