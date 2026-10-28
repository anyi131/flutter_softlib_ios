import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_softlib/app/jicun/jicun_network.dart';

void main() {
  group('jicunCellularFromInterfaces', () {
    test('iOS 蜂窝 pdp_ip0 判为移动网络', () {
      expect(jicunCellularFromInterfaces(<String>['pdp_ip0']), isTrue);
    });

    test('Android 蜂窝 rmnet_data0 判为移动网络', () {
      expect(
        jicunCellularFromInterfaces(<String>['rmnet_data0', 'dummy0']),
        isTrue,
      );
    });

    test('Wi-Fi 接口判为非移动网络', () {
      expect(jicunCellularFromInterfaces(<String>['en0']), isFalse);
      expect(jicunCellularFromInterfaces(<String>['wlan0']), isFalse);
      expect(jicunCellularFromInterfaces(<String>['eth0']), isFalse);
    });

    test('双栈时有 Wi-Fi 就按 Wi-Fi 算', () {
      expect(
        jicunCellularFromInterfaces(<String>['pdp_ip0', 'en0']),
        isFalse,
      );
      expect(
        jicunCellularFromInterfaces(<String>['rmnet_data0', 'wlan0']),
        isFalse,
      );
    });

    test('认不出的接口返回 null（调用方放行）', () {
      expect(jicunCellularFromInterfaces(<String>['dummy0']), isNull);
      expect(jicunCellularFromInterfaces(<String>[]), isNull);
      expect(jicunCellularFromInterfaces(<String>['', '  ']), isNull);
    });

    test('大小写与空格不影响判断', () {
      expect(jicunCellularFromInterfaces(<String>[' RMNET_DATA0 ']), isTrue);
      expect(jicunCellularFromInterfaces(<String>['WLAN0']), isFalse);
    });
  });
}
