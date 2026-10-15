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
  /// ★ v3.3.4：auth_template 6 款**骨架级**模板
  ///   classic  经典居中     —— 顶部返回 + 居中标题 + 玻璃卡表单
  ///   split    上下分栏     —— 上半渐变固定 + 下半独立滚动
  ///   sheet    底部抽屉     —— 渐变铺满 + 白色圆角 sheet + 拖拽手柄
  ///   banner   通栏顶栏     —— 顶部通栏渐变色带 + 白底正文
  ///   minimal  极简线性     —— 无卡片，下划线输入 + 纯文字
  ///   floating 悬浮胶囊     —— 浮动圆形返回 + 胶囊输入
  Widget build(BuildContext context) {
    // ★ 1015 修复：监听 configVersion —— 后台改登录模板后立即重建
    return Obx(() {
      SoftService.instance.configVersion.value; // 订阅
      final tpl =
          SoftService.instance.cachedConfig?.uiConfig.authTemplate ?? 'classic';
      return switch (tpl) {
        'split' => _buildSplit(context),
        'sheet' => _buildSheet(context),
        'banner' => _buildBanner(context),
        'minimal' => _buildMinimal(context),
        'floating' => _buildFloating(context),
        _ => _buildClassic(context),
      };
    });
  }

  Widget _backBtn(BuildContext context, {Color? fg}) {
    if (!showBack) return const SizedBox(width: 38, height: 38);
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: fg != null
              ? Colors.white.withAlpha(40)
              : (context.isDark ? Colors.white.withAlpha(14) : Colors.white),
          shape: BoxShape.circle,
          border: Border.all(
            color: fg != null
                ? Colors.white.withAlpha(70)
                : (context.isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(8)),
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: fg ?? context.t1,
        ),
      ),
    );
  }

  /// ① 经典居中：图标 + 渐变标题 + 玻璃表单卡
  Widget _buildClassic(BuildContext context) {
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      8,
                      context.pagePadding,
                      0,
                    ),
                    child: Row(children: [_backBtn(context), const Spacer()]),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        12,
                        context.pagePadding,
                        30,
                      ),
                      children: [
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
                          shaderCallback: (r) =>
                              Deco.aurora().createShader(r),
                          child: Text(
                            title,
                            style: Ty.display.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          subtitle,
                          style: Ty.small.copyWith(color: context.t3),
                        ),
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

  /// ② 上下分栏：上半固定渐变区（不滚动），表单在下方独立滚动
  Widget _buildSplit(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // 上半：渐变区（含状态栏padding，出血到顶）
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                MediaQuery.of(context).padding.top + 8,
                context.pagePadding,
                30,
              ),
              decoration: BoxDecoration(
                gradient: Deco.brandGradient,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [_backBtn(context, fg: Colors.white)]),
                  const SizedBox(height: 18),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(46),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            // 下半：表单独立滚动（无整体卡，直接排在白底上）
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  22,
                  context.pagePadding,
                  30,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ③ 底部抽屉：渐变铺满全屏，表单作为底部白色大圆角 sheet
  Widget _buildSheet(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // 渐变铺满
            Container(
              decoration: BoxDecoration(gradient: Deco.brandGradient),
            ),
            // 顶部标题与返回
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  8,
                  context.pagePadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [_backBtn(context, fg: Colors.white)]),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(215),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部 sheet：占屏幕下半，内部可滚动
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.62,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.isDark ? C.bg1 : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 拖拽手柄
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.isDark
                                ? Colors.white.withAlpha(30)
                                : Colors.black.withAlpha(18),
                            borderRadius: BorderRadius.circular(R.full),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            context.pagePadding,
                            16,
                            context.pagePadding,
                            24,
                          ),
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ④ 通栏顶栏：全宽渐变通栏顶到状态栏，表单无卡直接排下方
  Widget _buildBanner(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // 通栏：顶到状态栏，无圆角
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                MediaQuery.of(context).padding.top + 8,
                context.pagePadding,
                22,
              ),
              decoration: BoxDecoration(gradient: Deco.brandGradient),
              child: Row(
                children: [
                  _backBtn(context, fg: Colors.white),
                  const SizedBox(width: 12),
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  20,
                  context.pagePadding,
                  30,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⑤ 极简线性：无卡无图标，标题 + 分割线 + 表单
  Widget _buildMinimal(BuildContext context) {
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      8,
                      context.pagePadding,
                      0,
                    ),
                    child: Row(children: [_backBtn(context), const Spacer()]),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        24,
                        context.pagePadding,
                        30,
                      ),
                      children: [
                        Text(
                          title,
                          style: Ty.display.copyWith(color: context.t1),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 34,
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: Deco.brandGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: Ty.small.copyWith(color: context.t3),
                        ),
                        const SizedBox(height: 28),
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

  /// ⑥ 悬浮胶囊：每个输入项各自独立成胶囊（无整体卡）
  Widget _buildFloating(BuildContext context) {
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      8,
                      context.pagePadding,
                      0,
                    ),
                    child: Row(children: [_backBtn(context), const Spacer()]),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        context.pagePadding,
                        30,
                        context.pagePadding,
                        30,
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: Deco.brandGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: C.brand.withAlpha(70),
                                  blurRadius: 24,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 27),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: context.t1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: Ty.small.copyWith(color: context.t3),
                          ),
                        ),
                        const SizedBox(height: 30),
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
/// 当前认证页模板是否为「胶囊输入项」
bool _authFieldPill(BuildContext context) =>
    (SoftService.instance.cachedConfig?.uiConfig.authTemplate ?? '') ==
    'floating';

/// 当前认证页模板是否为「下划线输入项」
bool _authFieldUnderline(BuildContext context) =>
    (SoftService.instance.cachedConfig?.uiConfig.authTemplate ?? '') ==
    'minimal';

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
            // ★ v3.3.4：floating 模板输入项是「胶囊」（全圆角），
            //   minimal 模板是「下划线式」（无边框，仅底部细线）
            borderRadius: BorderRadius.circular(
              _authFieldPill(context) ? R.full : R.md,
            ),
            border: Border.all(
              color: (error != null && error!.isNotEmpty)
                  ? C.danger.withAlpha(140)
                  : (_authFieldUnderline(context)
                        ? Colors.transparent
                        : (context.isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10))),
              width: (error != null && error!.isNotEmpty) ? 1.2 : 0.9,
            ),
            boxShadow: _authFieldPill(context)
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(
                        context.isDark ? 60 : 14,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          margin: EdgeInsets.only(bottom: _authFieldUnderline(context) ? 2 : 0),
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
    // ★ v3.3.4：表单容器跟随认证页模板 ——
    //   split/banner/minimal 模板下不再套玻璃卡（表单直接排在页面底上），
    //   否则「换了骨架但表单还是那张卡」，看起来仍像同款。
    final tpl =
        SoftService.instance.cachedConfig?.uiConfig.authTemplate ?? 'classic';
    final noCard = tpl == 'split' ||
        tpl == 'banner' ||
        tpl == 'banner_top' ||
        tpl == 'minimal';
    if (noCard) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }
    // floating 模板：输入项自带胶囊，容器也去卡
    if (tpl == 'floating') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
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
