import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
    final svc = SoftService.instance;
    return Obx(() {
      // ★ 1015：Obx 内只读响应式变量（configVersion），
      //   非响应式的 cachedConfig 在下面单独取，避免 GetX 误用检测
      final ver = svc.configVersion.value;
      final tpl = ver >= 0
          ? (svc.cachedConfig?.uiConfig.authTemplate ?? 'classic')
          : 'classic';
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
  // ═══════════════════════════════════════════════════════════
  // ★ 1016 认证页模板重做：6 套**布局骨架**彻底不同（不是换色）
  //   classic  居中   —— 无头图，白底居中标题 + 玻璃卡
  //   split    左右   —— 左 38% 渐变品牌栏 + 右 62% 表单（横排）
  //   sheet    抽屉   —— 全屏渐变 + 底部白色圆角面板 + 拖拽手柄
  //   banner   细带   —— 顶部 56px 细色带 + 全白正文（无头图）
  //   minimal  极简   —— 纯白、无卡片、无渐变、大标题 + 下划线输入
  //   floating 悬浮   —— 全屏渐变底 + 居中悬浮白卡（四周留白）
  // ═══════════════════════════════════════════════════════════

  /// 表单区（card=true 用玻璃卡；false 用裸列表）
  Widget _formArea({bool card = true, double hPad = 18}) {
    if (card) return AuthCard(children: children);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// 标题块（onGradient=true 时用白字）
  Widget _titleBlock(
    BuildContext context, {
    bool onGradient = false,
    bool center = false,
    double size = 27,
  }) {
    final fg = onGradient ? Colors.white : context.t1;
    final sub = onGradient ? Colors.white.withAlpha(215) : context.t3;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: fg,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(fontSize: 12.5, color: sub, height: 1.55),
        ),
      ],
    );
  }

  Widget _iconBox({bool onGradient = false, double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onGradient ? Colors.white.withAlpha(46) : C.brand.withAlpha(24),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: onGradient ? Colors.white : C.brand,
      ),
    );
  }

  /// ① classic —— 白底居中：返回 + 图标 + 标题 + 玻璃卡
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
                        14,
                        context.pagePadding,
                        40,
                      ),
                      children: [
                        Center(child: _iconBox()),
                        const SizedBox(height: 16),
                        _titleBlock(context, center: true),
                        const SizedBox(height: 22),
                        _formArea(),
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

  /// ② split —— **左右分栏**：左 38% 渐变品牌栏 / 右 62% 表单
  Widget _buildSplit(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: [
            // 左侧品牌栏（渐变，纵向铺满）
            Container(
              width: wide ? MediaQuery.of(context).size.width * 0.34 : 128,
              decoration: BoxDecoration(gradient: Deco.brandGradient),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _backBtn(context, fg: Colors.white),
                      const Spacer(),
                      _iconBox(onGradient: true, size: 46),
                      const SizedBox(height: 14),
                      _titleBlock(
                        context,
                        onGradient: true,
                        size: wide ? 26 : 21,
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
            // 右侧表单（白底，独立滚动）
            Expanded(
              child: Container(
                color: context.isDark ? C.bg0 : Colors.white,
                child: SafeArea(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    children: [_formArea(card: false, hPad: 0)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ③ sheet —— 全屏渐变 + **底部白色圆角面板 + 拖拽手柄**
  Widget _buildSheet(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // 上半：渐变 + 标题（约占 1/3）
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.pagePadding,
                MediaQuery.of(context).padding.top + 10,
                context.pagePadding,
                34,
              ),
              decoration: BoxDecoration(gradient: Deco.brandGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [_backBtn(context, fg: Colors.white)]),
                  const SizedBox(height: 18),
                  _titleBlock(context, onGradient: true),
                ],
              ),
            ),
            // 下半：白色圆角面板（上移覆盖 = 抽屉感）
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.isDark ? C.bg0 : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 拖拽手柄
                      Container(
                        width: 42,
                        height: 4.5,
                        margin: const EdgeInsets.only(top: 10, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(28),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          children: [_formArea(card: false, hPad: 4)],
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

  /// ④ banner —— **顶部 56px 细色带**（很矮，无头图）+ 全白正文
  Widget _buildBanner(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              decoration: BoxDecoration(gradient: Deco.brandGradient),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    _backBtn(context, fg: Colors.white),
                    const SizedBox(width: 12),
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: context.isDark ? C.bg0 : Colors.white,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: context.t3),
                    ),
                    const SizedBox(height: 18),
                    _formArea(card: false, hPad: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⑤ minimal —— **纯白极简**：无渐变、无卡片、大标题 + 下划线输入
  Widget _buildMinimal(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? C.bg0 : Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _backBtn(context),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(26, 34, 26, 30),
                  children: [
                    // 大标题（36 号）+ 左侧竖线
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 38,
                          margin: const EdgeInsets.only(top: 4, right: 12),
                          decoration: BoxDecoration(
                            gradient: Deco.brandGradient,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Expanded(child: _titleBlock(context, size: 30)),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _formArea(card: false, hPad: 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⑥ floating —— **全屏渐变底 + 居中悬浮白卡**（四周留白，卡片浮起来）
  Widget _buildFloating(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // 全屏渐变
            Container(decoration: BoxDecoration(gradient: Deco.brandGradient)),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        _backBtn(context, fg: Colors.white),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      children: [
                        const SizedBox(height: 4),
                        Center(child: _iconBox(onGradient: true, size: 56)),
                        const SizedBox(height: 14),
                        _titleBlock(context, onGradient: true, center: true),
                        const SizedBox(height: 22),
                        // 悬浮白卡
                        Container(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: context.isDark ? C.bg2 : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _formArea(card: false, hPad: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统一风格的输入框（玻璃质感 + 圆角 + 内联错误）
}

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
                      color: Colors.black.withAlpha(context.isDark ? 60 : 14),
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
                  onSubmitted: onSubmitted == null
                      ? null
                      : (_) => onSubmitted!(),
                  style: TextStyle(fontSize: 14.5, color: context.t1),
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: hint.isEmpty ? null : hint,
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    labelStyle: TextStyle(fontSize: 13.5, color: context.t3),
                    floatingLabelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: C.brand,
                    ),
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
                    color: context.t3,
                  ),
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
                const Icon(
                  Icons.error_outline_rounded,
                  size: 13,
                  color: C.danger,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    error!,
                    style: const TextStyle(fontSize: 12, color: C.danger),
                  ),
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
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: C.danger,
                height: 1.4,
              ),
            ),
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
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: Colors.white),
                          const SizedBox(width: 7),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
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
    final noCard =
        tpl == 'split' ||
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
