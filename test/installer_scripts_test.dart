// test/installer_scripts_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Windows Installer & Uninstaller Suite Tests', () {
    test('install.bat, uninstall.bat and uninstall.ps1 exist in root', () {
      expect(File('install.bat').existsSync(), isTrue);
      expect(File('uninstall.bat').existsSync(), isTrue);
      expect(File('uninstall.ps1').existsSync(), isTrue);
    });

    test('install.bat contains valid configuration for JA ADB Tool', () {
      final content = File('install.bat').readAsStringSync();
      expect(content, contains('Programs\\JA_adb_tool'));
      expect(content, contains('ja_adb_tool.exe'));
      expect(content, contains('JA ADB Tool.lnk'));
      expect(content, contains('Uninstall JA ADB Tool.lnk'));
      expect(
        content,
        contains(
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\JA_adb_tool',
        ),
      );
      expect(content, contains('/silent'));
    });

    test('uninstall.bat has staging wrapper logic', () {
      final content = File('uninstall.bat').readAsStringSync();
      expect(content, contains('--staged'));
      expect(content, contains('uninstall.ps1'));
      expect(content, contains('powershell.exe'));
    });

    test('uninstall.ps1 contains valid targets and cleanup logic', () {
      final content = File('uninstall.ps1').readAsStringSync();
      expect(content, contains('Programs\\JA_adb_tool'));
      expect(content, contains('ja_adb_tool.exe'));
      expect(content, contains('Uninstall JA ADB Tool.lnk'));
      expect(
        content,
        contains(
          'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\JA_adb_tool',
        ),
      );
    });

    test('build.bat packages install and uninstall scripts into dist', () {
      final content = File('build.bat').readAsStringSync();
      expect(content, contains('copy /y "install.bat" "dist\\"'));
      expect(content, contains('copy /y "uninstall.bat" "dist\\"'));
      expect(content, contains('copy /y "uninstall.ps1" "dist\\"'));
    });
  });
}
