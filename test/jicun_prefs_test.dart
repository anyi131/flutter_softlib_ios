////////////////////////////////////////////////////////////////////////////////
// 即存本机偏好测试
// 覆盖：默认值、set 后 getter 立即变化、落盘后重读、目录名非法值不写入。
////////////////////////////////////////////////////////////////////////////////
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_softlib/app/jicun/jicun_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final prefs = JicunPrefs.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs.resetForTest();
  });

  test('默认值：服务端默认 true / 安逸软件汇 / 提醒开 / Wi-Fi 关', () async {
    await prefs.load();

    expect(prefs.autoPaste, isTrue);
    expect(prefs.saveDirName, JicunPrefs.defaultSaveDirName);
    expect(prefs.notifyOnDone, isTrue);
    expect(prefs.notifyOnFail, isTrue);
    expect(prefs.wifiOnly, isFalse);
  });

  test('set 后 getter 立刻变（不等写盘）', () async {
    final a = prefs.setAutoPaste(false);
    expect(prefs.autoPaste, isFalse);

    final b = prefs.setNotifyOnDone(false);
    expect(prefs.notifyOnDone, isFalse);

    final c = prefs.setNotifyOnFail(false);
    expect(prefs.notifyOnFail, isFalse);

    final d = prefs.setWifiOnly(true);
    expect(prefs.wifiOnly, isTrue);

    // 首尾空格会被去掉后入库
    final e = prefs.setSaveDirName('  我的即存  ');
    expect(prefs.saveDirName, '我的即存');

    await a;
    await b;
    await c;
    await d;
    await e;
  });

  test('落盘后清缓存重读，能读回上次的值', () async {
    await prefs.setAutoPaste(false);
    await prefs.setSaveDirName('测试目录');
    await prefs.setNotifyOnDone(false);
    await prefs.setNotifyOnFail(false);
    await prefs.setWifiOnly(true);

    // 丢掉内存缓存，模拟下次启动
    prefs.resetForTest();
    await prefs.load();

    expect(prefs.autoPaste, isFalse);
    expect(prefs.saveDirName, '测试目录');
    expect(prefs.notifyOnDone, isFalse);
    expect(prefs.notifyOnFail, isFalse);
    expect(prefs.wifiOnly, isTrue);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getBool('jicun.autoPaste'), isFalse);
    expect(sp.getString('jicun.saveDirName'), '测试目录');
    expect(sp.getBool('jicun.notifyOnDone'), isFalse);
    expect(sp.getBool('jicun.notifyOnFail'), isFalse);
    expect(sp.getBool('jicun.wifiOnly'), isTrue);
  });

  test('saveDirName 非法值不写入，保留上一次合法值', () async {
    await prefs.setSaveDirName('合法目录');

    const badNames = <String>[
      '',
      '   ',
      'a/b',
      r'a\b',
      'a:b',
      'a*b',
      'a?b',
      'a"b',
      'a<b',
      'a>b',
      'a|b',
      '一二三四五六七八九十一二三四五六七八九十一', // 21 字，超长
    ];
    for (final bad in badNames) {
      await prefs.setSaveDirName(bad);
      expect(prefs.saveDirName, '合法目录', reason: '非法值 "$bad" 不应写入');
    }

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('jicun.saveDirName'), '合法目录');
  });

  test('load 幂等：重复调用不覆盖已经改过的内存值', () async {
    await prefs.load();
    await prefs.setAutoPaste(false);

    await prefs.load();
    expect(prefs.autoPaste, isFalse);
  });
}
