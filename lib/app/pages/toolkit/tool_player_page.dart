import 'dart:async';

import '../../widgets/mpv_core.dart';

import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../design/ad.dart';
import '../../design/adaptive.dart';
import '../../design/app_anim.dart';
import '../../design/kit.dart';
import '../../design/ui.dart';
import '../../utils/toast_util.dart';

/// 工具箱 · 通用播放器（1015 新增）
///
/// 为什么需要它：
///   之前影视/短剧/音乐的「播放」都是 JumpUtil.openUrl → 丢给系统浏览器。
///   结果：用户被弹出 App，而浏览器多半也放不了 m3u8，体感就是「不能看」。
///   现在统一用这个页内播放器：
///     · 视频（mp4 / m3u8）→ 内置播放
///     · 音频（mp3 / m4a）→ 内置播放（显示封面 + 进度）
///   ★ 关键：必须带 User-Agent 请求头，很多源站不带 UA 直接 403。
import 'player_next.dart';

class ToolPlayerPage extends StatefulWidget {
  final String url;
  final String title;
  final String? cover;
  final String? subtitle;
  final bool isAudio;

  /// 播放列表（可选）：传入后显示选集/选歌
  final List<(String, String)>? playlist;
  final int initialIndex;

  /// 音乐列表：只有歌名/歌手，直链要按序号现取
  final Future<String> Function(int index)? resolveUrl;

  const ToolPlayerPage({
    super.key,
    required this.url,
    this.title = '',
    this.cover,
    this.subtitle,
    this.isAudio = false,
    this.playlist,
    this.initialIndex = 0,
    this.resolveUrl,
  });

  @override
  State<ToolPlayerPage> createState() => _ToolPlayerPageState();
}

class _ToolPlayerPageState extends State<ToolPlayerPage> {
  late String _url = widget.url;

  @override
  Widget build(BuildContext context) {
    // ★ 1016：内部完全交给新版 VideoPage（media_kit 内核 + 重做的 UI）
    //   对外类名与参数保持不变，音乐页/影视页 8 处调用无需改动。
    return VideoPage(
      url: _url,
      title: widget.title,
      poster: widget.cover,
      subtitle: widget.subtitle ?? '',
      isAudio: widget.isAudio,
      episodes: widget.playlist ?? const [],
      initialIndex: widget.initialIndex,
      resolveUrl: widget.resolveUrl,
      onSelectEpisode: (u) => setState(() => _url = u),
    );
  }
}
