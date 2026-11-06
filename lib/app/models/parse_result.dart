/// ★ 1105y 蓝奏云解析结果（不可变值对象）
///
/// 说明：原本想用 freezed 生成，但当前 Flutter/Dart（3.38 / Dart 3.9）与
/// build_runner 2.12 的 AOT builder 编译不兼容（`dart compile` 不支持 build hooks），
/// 生成器跑不起来。这里手写等价能力：不可变字段 + copyWith + == / hashCode，
/// 后续换到能跑 freezed 的环境再迁移，接口保持一致。
class ParseResult {
  const ParseResult({
    required this.url,
    this.proxyUrl,
    this.cached = false,
    this.error,
  });

  /// 主下载地址（直连优先）
  final String url;

  /// 服务器中转兜底地址（直连被风控时用）
  final String? proxyUrl;

  /// 是否命中服务端缓存
  final bool cached;

  /// 解析失败原因（url 为空时才有值）
  final String? error;

  /// 是否解析成功
  bool get ok => url.isNotEmpty && error == null;

  /// 是否有中转兜底可用
  bool get hasProxy => (proxyUrl ?? '').isNotEmpty;

  ParseResult copyWith({
    String? url,
    String? proxyUrl,
    bool? cached,
    String? error,
  }) {
    return ParseResult(
      url: url ?? this.url,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      cached: cached ?? this.cached,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParseResult &&
          other.url == url &&
          other.proxyUrl == proxyUrl &&
          other.cached == cached &&
          other.error == error;

  @override
  int get hashCode => Object.hash(url, proxyUrl, cached, error);

  @override
  String toString() =>
      'ParseResult(url: $url, proxyUrl: $proxyUrl, cached: $cached, error: $error)';
}
