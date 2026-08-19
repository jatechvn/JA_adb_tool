import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

void main() {
  group('XAPK archive path validation', () {
    test('accepts normal relative archive paths', () {
      expect(isSafeXapkEntryPath('base.apk'), isTrue);
      expect(isSafeXapkEntryPath('Android/obb/main.1.com.example.obb'), isTrue);
    });

    test('rejects traversal and absolute archive paths', () {
      expect(isSafeXapkEntryPath('../outside.apk'), isFalse);
      expect(isSafeXapkEntryPath('nested/../../outside.apk'), isFalse);
      expect(isSafeXapkEntryPath('/absolute.apk'), isFalse);
      expect(isSafeXapkEntryPath(r'C:\outside.apk'), isFalse);
    });
  });
}
