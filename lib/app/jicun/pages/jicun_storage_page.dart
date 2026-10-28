////////////////////////////////////////////////////////////////////////////////
// 即存（jicun）· 存储位置设置页
// 只维护一个文件夹名（JicunPrefs.saveDirName）；做成可编辑 + 校验 + 保存。
// 注意：这里不会真的移动任何文件，文件夹名只供下载落盘时使用。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter/material.dart';

import '../../design/adaptive.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../jicun_prefs.dart';

/// 「存储位置」二级页。
class JicunStoragePage extends StatefulWidget {
  const JicunStoragePage({super.key});

  @override
  State<JicunStoragePage> createState() => _JicunStoragePageState();
}

class _JicunStoragePageState extends State<JicunStoragePage> {
  final TextEditingController _ctrl = TextEditingController();
  String _shownName = JicunPrefs.instance.saveDirName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.text = _shownName;
    _syncFromDisk();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 启动时若没 load 过，补读一次；用户已经改过输入框就不覆盖。
  Future<void> _syncFromDisk() async {
    await JicunPrefs.instance.load();
    if (!mounted) return;
    final name = JicunPrefs.instance.saveDirName;
    if (name == _shownName) return;
    if (_ctrl.text != _shownName) return;
    setState(() {
      _shownName = name;
      _ctrl.text = name;
    });
  }

  /// 返回 null 表示合法；否则是给用户看的原因。
  String? _validate(String name) {
    if (name.isEmpty) return '文件夹名称不能为空';
    if (name.length > JicunPrefs.maxSaveDirNameLength) {
      return '最多 ${JicunPrefs.maxSaveDirNameLength} 个字符';
    }
    if (!JicunPrefs.isValidSaveDirName(name)) {
      return '不能包含 / \\ : * ? " < > |';
    }
    return null;
  }

  void _save() {
    final name = _ctrl.text.trim();
    final error = _validate(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _shownName = name;
    });
    // setSaveDirName 内部会再校验一次；非法值不会落盘。
    JicunPrefs.instance.setSaveDirName(name);
    _ctrl.text = name;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('已保存到本机'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Deco.pageBackground(context),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      context.pagePadding,
                      6,
                      context.pagePadding,
                      32 + context.safeBottom,
                    ),
                    children: [
                      Text(
                        '自定义即存下载时的文件夹名称。',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: context.t3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      KitCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '文件夹名称',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: context.t2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _ctrl,
                              maxLines: 1,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                // 同时刷新右侧字数统计，并清掉上一次的报错。
                                setState(() => _error = null);
                              },
                              onSubmitted: (_) => _save(),
                              style: TextStyle(
                                fontSize: 14,
                                color: context.t1,
                              ),
                              decoration: InputDecoration(
                                hintText: '例如：安逸软件汇',
                                errorText: _error,
                                errorMaxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${_ctrl.text.trim().length}'
                                '/${JicunPrefs.maxSaveDirNameLength}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.t3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            PrimaryButton(
                              label: '保存',
                              height: 48,
                              onPressed: _save,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '当前保存目录：${JicunPrefs.instance.saveDirName}',
                        style: TextStyle(fontSize: 12, color: context.t3),
                      ),
                      const SizedBox(height: 10),
                      _note(context),
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

  Widget _note(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: context.t3),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '文件保存在系统相册 / 应用文档目录，此名称仅用于文件夹',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.55,
                color: context.t3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶栏：左返回 + 居中标题。
  Widget _topBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: context.t1,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '存储位置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: context.t1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
