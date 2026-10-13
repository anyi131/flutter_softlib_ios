/// 广场动态
class PostItem {
  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final String content;
  final List<String> images;
  final String videoUrl;
  final String videoType;
  final String videoCover;
  final String videoSource; // 原始分享链接（直链过期后重新解析用）
  final String ipArea; // IP 属地（发布时定位）
  final int catId;
  final String catTitle;
  final int likeCount;
  final int commentCount;
  final int views;
  final int createtime;

  /// 1013d：status 0=待审 1=通过 2=驳回
  final int status;

  /// 1013d：是否本人发布的动态（服务端 mine 标记）
  final bool mine;
  final bool isAdmin;
  final bool isVip;
  final String title;

  PostItem({
    required this.id,
    this.userId = 0,
    required this.nickname,
    required this.avatar,
    required this.content,
    required this.images,
    this.videoUrl = '',
    this.videoType = '',
    this.videoCover = '',
    this.videoSource = '',
    this.ipArea = '',
    required this.catId,
    required this.catTitle,
    required this.likeCount,
    required this.commentCount,
    required this.views,
    required this.createtime,
    this.status = 1,
    this.mine = false,
    this.isAdmin = false,
    this.isVip = false,
    this.title = '',
  });

  static int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  /// 复制并修改部分字段
  ///
  /// ★ 修复「点赞后视频/图片消失」：以前点赞处是手动 new PostItem(...)，
  ///   只填了一部分字段，导致 videoUrl/videoCover 等被悄悄清空，
  ///   界面看起来像「数据丢失」。统一用 copyWith 避免遗漏。
  PostItem copyWith({
    int? id,
    int? userId,
    String? nickname,
    String? avatar,
    String? content,
    List<String>? images,
    String? videoUrl,
    String? videoType,
    String? videoCover,
    String? videoSource,
    String? ipArea,
    int? catId,
    String? catTitle,
    int? likeCount,
    int? commentCount,
    int? views,
    int? createtime,
    int? status,
    bool? mine,
    bool? isAdmin,
    bool? isVip,
    String? title,
  }) => PostItem(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    nickname: nickname ?? this.nickname,
    avatar: avatar ?? this.avatar,
    content: content ?? this.content,
    images: images ?? this.images,
    videoUrl: videoUrl ?? this.videoUrl,
    videoType: videoType ?? this.videoType,
    videoCover: videoCover ?? this.videoCover,
    videoSource: videoSource ?? this.videoSource,
    ipArea: ipArea ?? this.ipArea,
    catId: catId ?? this.catId,
    catTitle: catTitle ?? this.catTitle,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    views: views ?? this.views,
    createtime: createtime ?? this.createtime,
    status: status ?? this.status,
    mine: mine ?? this.mine,
    isAdmin: isAdmin ?? this.isAdmin,
    isVip: isVip ?? this.isVip,
    title: title ?? this.title,
  );

  factory PostItem.fromJson(Map j) => PostItem(
    id: _i(j['id']),
    userId: _i(j['user_id']),
    nickname: _s(j['nickname']),
    avatar: _s(j['avatar']),
    content: _s(j['content']),
    videoUrl: _s(j['video_url']),
    videoType: _s(j['video_type']),
    videoCover: _s(j['video_cover']),
    videoSource: _s(j['video_source']),
    ipArea: _s(j['ip_area']),
    images: (j['images'] is List)
        ? (j['images'] as List).map((e) => e.toString()).toList()
        : _s(j['images'])
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
    catId: _i(j['cat_id']),
    catTitle: _s(j['cat_title']),
    likeCount: _i(j['like_count']),
    commentCount: _i(j['comment_count']),
    views: _i(j['views']),
    createtime: _i(j['createtime']),
    status: _i(j['status'] ?? 1),
    mine: j['mine'] == 1 || j['mine'] == true,
    isAdmin: j['is_admin'] == 1 || j['is_admin'] == true,
    isVip: j['is_vip'] == 1 || j['is_vip'] == true,
    title: _s(j['title']),
  );

  static List<PostItem> listFrom(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => PostItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// 相对时间
  String get relTime {
    if (createtime <= 0) return '';
    final diff = DateTime.now().millisecondsSinceEpoch ~/ 1000 - createtime;
    if (diff < 60) return '刚刚';
    if (diff < 3600) return '${diff ~/ 60} 分钟前';
    if (diff < 86400) return '${diff ~/ 3600} 小时前';
    if (diff < 86400 * 30) return '${diff ~/ 86400} 天前';
    final d = DateTime.fromMillisecondsSinceEpoch(createtime * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// 广场分类
class PostCat {
  final int id;
  final String title;
  final int count;
  PostCat({required this.id, required this.title, required this.count});

  factory PostCat.fromJson(Map j) => PostCat(
    id: int.tryParse('${j['id']}') ?? 0,
    title: (j['title'] ?? '').toString(),
    count: int.tryParse('${j['count']}') ?? 0,
  );

  static List<PostCat> listFrom(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => PostCat.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
