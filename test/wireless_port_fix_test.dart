import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

ProcessResult _ok([String text = '']) => ProcessResult(1, 0, text, '');

void main() {
  group('AdbService IP Helper Tests', () {
    test('isValidIpv4 accurately identifies valid and invalid IPv4', () {
      expect(AdbService.isValidIpv4('192.168.1.1'), isTrue);
      expect(AdbService.isValidIpv4('10.0.0.1'), isTrue);
      expect(AdbService.isValidIpv4('172.16.0.50'), isTrue);
      expect(AdbService.isValidIpv4('192.168.137.40'), isTrue);

      expect(AdbService.isValidIpv4(''), isFalse);
      expect(AdbService.isValidIpv4('127.0.0.1'), isFalse); // Loopback excluded
      expect(AdbService.isValidIpv4('256.0.0.1'), isFalse);
      expect(AdbService.isValidIpv4('192.168.1'), isFalse);
      expect(AdbService.isValidIpv4('192.168.1.1.1'), isFalse);
      expect(AdbService.isValidIpv4('invalid_ip'), isFalse);
      expect(AdbService.isValidIpv4('192.168.1.-1'), isFalse);
    });

    test('extractIpv4 extracts IPv4 from ip addr output', () {
      const sampleOutput = '''
28: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 3000
    inet 192.168.137.40/24 brd 192.168.137.255 scope global wlan0
       valid_lft forever preferred_lft forever
    inet6 fe80::d68c:79ff:feb9:1234/64 scope link
''';
      expect(AdbService.extractIpv4(sampleOutput), '192.168.137.40');

      const loopbackOnly = 'inet 127.0.0.1/8 scope host lo';
      expect(AdbService.extractIpv4(loopbackOnly), isNull);

      const empty = 'No inet output here';
      expect(AdbService.extractIpv4(empty), isNull);
    });

    test('extractRouteSrcIpv4 extracts IP from ip route output', () {
      const routeOutput = '''
default via 192.168.137.1 dev wlan0 proto dhcp metric 100
192.168.137.0/24 dev wlan0 proto kernel scope link src 192.168.137.40 metric 100
''';
      expect(AdbService.extractRouteSrcIpv4(routeOutput), '192.168.137.40');

      const noSrc = 'default via 192.168.1.1 dev wlan0';
      expect(AdbService.extractRouteSrcIpv4(noSrc), isNull);
    });
  });

  group('AdbService getDeviceIp Multi-Tier Resolution', () {
    test('Tier 1: uses dhcp.wlan0.ipaddress when available', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          if (args.contains('dhcp.wlan0.ipaddress')) {
            return _ok('192.168.1.101\n');
          }
          return _ok('');
        },
      );

      final ip = await service.getDeviceIp('adb', 'device123');
      expect(ip, '192.168.1.101');
    });

    test('Tier 2: falls back to ip show wlan0 when dhcp is empty', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          if (args.contains('dhcp.wlan0.ipaddress')) {
            return _ok('\n');
          }
          if (args.contains('wlan0')) {
            return _ok(
              '    inet 192.168.1.102/24 brd 192.168.1.255 scope global wlan0\n',
            );
          }
          return _ok('');
        },
      );

      final ip = await service.getDeviceIp('adb', 'device123');
      expect(ip, '192.168.1.102');
    });

    test('Tier 3: falls back to ip route when wlan0 addr fails', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          if (args.contains('route')) {
            return _ok(
              '192.168.1.0/24 dev wlan0 scope link src 192.168.1.103\n',
            );
          }
          return _ok('');
        },
      );

      final ip = await service.getDeviceIp('adb', 'device123');
      expect(ip, '192.168.1.103');
    });
  });

  group('AdbService disconnectStaleEndpoints', () {
    test(
      'disconnects ephemeral endpoints matching host and keeps active port',
      () async {
        final disconnectedCalls = <String>[];
        final service = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            if (args.contains('devices')) {
              return _ok('''
List of devices attached
192.168.137.40:41979\tdevice
192.168.137.40:5555\tdevice
192.168.137.50:5555\tdevice
USB_SERIAL_999\tdevice
''');
            }
            if (args.contains('disconnect')) {
              disconnectedCalls.add(args.last);
              return _ok('disconnected ${args.last}');
            }
            return _ok('');
          },
        );

        final result = await service.disconnectStaleEndpoints(
          'adb',
          '192.168.137.40',
          5555,
        );

        expect(result, ['192.168.137.40:41979']);
        expect(disconnectedCalls, ['192.168.137.40:41979']);
      },
    );
  });

  group('AppLogic fixAndConnectWirelessPort Integration', () {
    test('returns false with message when no device is selected', () async {
      final logic = AppLogic(
        initialize: false,
        adbPath: 'adb',
        processRunner: (exe, args, {stderrEncoding, stdoutEncoding}) async =>
            _ok(),
      );

      final success = await logic.fixAndConnectWirelessPort();
      expect(success, isFalse);
      expect(logic.wirelessFixStatus, contains('No device selected'));
    });

    test('successfully executes full sequence and connects to 5555', () async {
      final executedArgs = <List<String>>[];
      final logic = AppLogic(
        initialize: false,
        adbPath: 'adb',
        processRunner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          executedArgs.add(List.from(args));
          if (args.contains('dhcp.wlan0.ipaddress')) {
            return _ok('192.168.137.40\n');
          }
          if (args.contains('connect')) {
            return _ok('connected to 192.168.137.40:5555\n');
          }
          if (args.contains('devices')) {
            return _ok('''
List of devices attached
192.168.137.40:5555\tdevice
192.168.137.40:41979\tdevice
''');
          }
          if (args.contains('disconnect')) {
            return _ok('disconnected\n');
          }
          return _ok('');
        },
      );

      // Select target device
      await logic.selectDevice('USB_DEVICE_1');
      expect(logic.selectedDevice, 'USB_DEVICE_1');

      // Run fix port 5555
      final success = await logic.fixAndConnectWirelessPort(port: 5555);
      expect(success, isTrue);
      expect(logic.cachedDeviceWifiIp, '192.168.137.40');
      expect(logic.wirelessEndpoints, contains('192.168.137.40:5555'));
      expect(logic.wirelessFixStatus, contains('Port 5555 fixed!'));

      // Check executed commands sequence
      final hasSetpropService = executedArgs.any(
        (a) => a.contains('service.adb.tcp.port') && a.contains('5555'),
      );
      final hasSetpropPersist = executedArgs.any(
        (a) => a.contains('persist.adb.tcp.port') && a.contains('5555'),
      );
      final hasTcpip = executedArgs.any(
        (a) => a.contains('tcpip') && a.contains('5555'),
      );
      final hasConnect = executedArgs.any(
        (a) => a.contains('connect') && a.contains('192.168.137.40:5555'),
      );
      final hasDisconnectStale = executedArgs.any(
        (a) => a.contains('disconnect') && a.contains('192.168.137.40:41979'),
      );

      expect(hasSetpropService, isTrue);
      expect(hasSetpropPersist, isTrue);
      expect(hasTcpip, isTrue);
      expect(hasConnect, isTrue);
      expect(hasDisconnectStale, isTrue);
    });
  });
}
