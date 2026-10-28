// 文件名规则的纯函数用例。这里不碰 IO/平台通道，跑 `flutter test` 即可。
import 'package:flutter_softlib/app/jicun/jicun_download_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jicunCleanTitle 标题清洗', () {
    test('中文标题原样通过', () {
      expect(jicunCleanTitle('海边日落 4K 合集'), '海边日落 4K 合集');
    });

    test('百分号编码会解码，裸 % 不抛异常', () {
      expect(jicunCleanTitle('%E6%B5%B7%E8%BE%B9%E6%97%A5%E8%90%BD'), '海边日落');
      expect(jicunCleanTitle('100%好评'), '100%好评');
    });

    test('非法字符 a/b:c*?"<>|d 被清掉', () {
      final cleaned = jicunCleanTitle('a/b:c*?"<>|d');
      expect(cleaned, isNot(matches(RegExp(r'[\\/:*?"<>|]'))));
      expect(cleaned, 'a b c d');
    });

    test('首尾的点与空格去掉，连续空白压成一个', () {
      expect(jicunCleanTitle('  ..标题  副标题..  '), '标题 副标题');
      expect(jicunCleanTitle('...'), '');
    });

    test('emoji 保留且不被切坏', () {
      const title = '🔥夏日限定🌊';
      expect(jicunCleanTitle(title), title);
    });

    test('超长标题按 80 个字符截断', () {
      final cleaned = jicunCleanTitle('视频标题' * 30); // 120 个字符
      expect(cleaned.runes.length, 80);
      expect(cleaned, '视频标题' * 20);
    });

    test('截断 emoji 标题时不留下半个代理对', () {
      final cleaned = jicunCleanTitle('🔥' * 100);
      expect(cleaned.runes.length, 80);
      // 落单的代理会以 D800–DFFF 的码点出现在 runes 里。
      final loners = cleaned.runes
          .where((r) => r >= 0xD800 && r <= 0xDFFF)
          .toList();
      expect(loners, isEmpty);
      expect(cleaned, '🔥' * 80);
    });
  });

  group('jicunExtForUrl 扩展名推断', () {
    test('带 query / fragment 的 mp4', () {
      expect(jicunExtForUrl('https://x/a.mp4?sign=1', kind: 'video'), 'mp4');
      expect(jicunExtForUrl('https://x/a.MP4#t=1', kind: 'video'), 'mp4');
    });

    test('认不出的后缀按 kind 兜底', () {
      expect(jicunExtForUrl('https://x/a.m4s', kind: 'video'), 'mp4');
      expect(jicunExtForUrl('https://x/a.m4s', kind: 'audio'), 'm4a');
      expect(jicunExtForUrl('https://x/a.m4s', kind: 'image'), 'jpg');
      expect(jicunExtForUrl('https://x/stream', kind: 'image'), 'jpg');
    });

    test('query 里出现的 .mp4 不能当成路径后缀', () {
      expect(
        jicunExtForUrl('https://x/stream?file=a.mp4', kind: 'image'),
        'jpg',
      );
    });
  });

  group('jicunUniqueName 重名避让', () {
    test('taken 含 视频.mp4 时依次给 _2、_3', () {
      final taken = <String>{'视频.mp4'};
      expect(jicunUniqueName('视频', 'mp4', taken), '视频_2.mp4');
      taken.add('视频_2.mp4');
      expect(jicunUniqueName('视频', 'mp4', taken), '视频_3.mp4');
    });

    test('不冲突时保留原名，且不修改 taken', () {
      final taken = <String>{'别的.mp4'};
      expect(jicunUniqueName('视频', 'mp4', taken), '视频.mp4');
      expect(taken, <String>{'别的.mp4'});
    });
  });

  group('jicunFileNameFor 组合', () {
    test('标题已带扩展名不重复追加', () {
      expect(
        jicunFileNameFor(
          title: '视频.mp4',
          url: 'https://x/a.mp4',
          kind: 'video',
        ),
        '视频.mp4',
      );
      expect(
        jicunFileNameFor(
          title: '视频.MP4',
          url: 'https://x/a.mp4',
          kind: 'video',
        ),
        '视频.mp4',
      );
    });

    test('空标题给带类型的兜底名', () {
      final name = jicunFileNameFor(
        title: '   ',
        url: 'https://x/a',
        kind: 'video',
      );
      expect(name, startsWith('视频_'));
      expect(name, endsWith('.mp4'));
    });

    test('清洗 + 扩展名 + 重名 一起生效', () {
      final name = jicunFileNameFor(
        title: '标题/带斜杠🎬',
        url: 'https://x/a.mp4?sign=1',
        kind: 'video',
        taken: const <String>{'标题 带斜杠🎬.mp4'},
      );
      expect(name, '标题 带斜杠🎬_2.mp4');
    });

    test('音频按 m4a 兜底', () {
      expect(
        jicunFileNameFor(
          title: '播客 第 1 期',
          url: 'https://x/audio.m4s',
          kind: 'audio',
        ),
        '播客 第 1 期.m4a',
      );
    });
  });
}
