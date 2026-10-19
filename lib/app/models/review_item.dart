/// 软件评价
class ReviewItem {
  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final int score;
  final String content;
  final List<String> images;
  final int likeCount;
  final int createtime;
  final String level; // good | mid | bad
  final String timeText;
  final int replyCount;
  final List<ReviewReply> replies;

  ReviewItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.score,
    required this.content,
    required this.images,
    required this.likeCount,
    required this.createtime,
    required this.level,
    required this.timeText,
    this.replyCount = 0,
    this.replies = const [],
  });

  static int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  factory ReviewItem.fromJson(Map j) => ReviewItem(
    id: _i(j['id']),
    userId: _i(j['user_id']),
    nickname: _s(j['nickname']),
    avatar: _s(j['avatar']),
    score: _i(j['score']),
    content: _s(j['content']),
    images: (j['images'] is List)
        ? (j['images'] as List).map((e) => e.toString()).toList()
        : const [],
    likeCount: _i(j['like_count']),
    createtime: _i(j['createtime']),
    level: _s(j['level']),
    timeText: _s(j['createtime_text']),
    replyCount: _i(j['reply_count']),
    replies: (j['replies'] is List)
        ? (j['replies'] as List)
              .whereType<Map>()
              .map((e) => ReviewReply.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : const [],
  );

  static List<ReviewItem> listFrom(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  String get levelText =>
      level == 'good' ? '推荐' : (level == 'mid' ? '一般' : '不推荐');
}

/// 评分统计
class ReviewSummary {
  final double avg;
  final int count;
  final int good;
  final int mid;
  final int bad;
  final int goodRate;

  ReviewSummary({
    required this.avg,
    required this.count,
    required this.good,
    required this.mid,
    required this.bad,
    required this.goodRate,
  });

  factory ReviewSummary.fromJson(Map j) => ReviewSummary(
    avg: double.tryParse('${j['avg'] ?? 0}') ?? 0,
    count: int.tryParse('${j['count'] ?? 0}') ?? 0,
    good: int.tryParse('${j['good'] ?? 0}') ?? 0,
    mid: int.tryParse('${j['mid'] ?? 0}') ?? 0,
    bad: int.tryParse('${j['bad'] ?? 0}') ?? 0,
    goodRate: int.tryParse('${j['good_rate'] ?? 100}') ?? 100,
  );

  static ReviewSummary empty() =>
      ReviewSummary(avg: 0, count: 0, good: 0, mid: 0, bad: 0, goodRate: 100);
}

/// 评价回复
class ReviewReply {
  final int id;
  final int userId;
  final String nickname;
  final String avatar;
  final String replyTo;
  final String content;
  final String timeText;

  ReviewReply({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.replyTo,
    required this.content,
    required this.timeText,
  });

  static int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
  static String _s(dynamic v) => (v ?? '').toString();

  factory ReviewReply.fromJson(Map j) => ReviewReply(
    id: _i(j['id']),
    userId: _i(j['user_id']),
    nickname: _s(j['nickname']),
    avatar: _s(j['avatar']),
    replyTo: _s(j['reply_to']),
    content: _s(j['content']),
    timeText: _s(j['createtime_text']),
  );
}
