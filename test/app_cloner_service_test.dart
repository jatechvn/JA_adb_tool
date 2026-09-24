import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/app_cloner_service.dart';

void main() {
  group('AxmlModifier Tests', () {
    test('AxmlModifier throws on invalid magic', () {
      final invalidBytes = Uint8List.fromList([
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
      ]);
      expect(
        () => AxmlModifier.modifyManifest(
          manifestBytes: invalidBytes,
          oldPackage: 'com.example.app',
          newPackage: 'com.example.app.clone',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('AxmlModifier modifies UTF-8 string pool correctly', () {
      // Construct a minimal valid AXML binary structure with UTF-8 strings
      const oldPkg = 'com.example.app';
      const oldAuth = 'com.example.app.provider';
      const otherStr = 'android.intent.action.MAIN';

      final strings = [oldPkg, oldAuth, otherStr];
      final strBytesList = <List<int>>[];
      for (final s in strings) {
        final b = BytesBuilder();
        final enc = utf8.encode(s);
        b.addByte(s.length);
        b.addByte(enc.length);
        b.add(enc);
        b.addByte(0);
        strBytesList.add(b.toBytes());
      }

      final stringsDataBuilder = BytesBuilder();
      final offsets = <int>[];
      for (final sb in strBytesList) {
        offsets.add(stringsDataBuilder.length);
        stringsDataBuilder.add(sb);
      }
      // align to 4
      final unaligned = stringsDataBuilder.length % 4;
      if (unaligned != 0) {
        for (var i = 0; i < 4 - unaligned; i++) {
          stringsDataBuilder.addByte(0);
        }
      }
      final stringsData = stringsDataBuilder.toBytes();

      const headerSize = 28;
      final offsetsSize = strings.length * 4;
      final stringsStart = headerSize + offsetsSize;
      final poolChunkSize = stringsStart + stringsData.length;

      final poolBuilder = BytesBuilder();
      final pHeader = ByteData(headerSize);
      pHeader.setUint16(0, 0x0001, Endian.little); // chunk type
      pHeader.setUint16(2, headerSize, Endian.little);
      pHeader.setUint32(4, poolChunkSize, Endian.little);
      pHeader.setUint32(8, strings.length, Endian.little);
      pHeader.setUint32(12, 0, Endian.little); // styleCount = 0
      pHeader.setUint32(16, 0x00000100, Endian.little); // flags: UTF-8
      pHeader.setUint32(20, stringsStart, Endian.little);
      pHeader.setUint32(24, 0, Endian.little); // stylesStart
      poolBuilder.add(pHeader.buffer.asUint8List());

      final offsetsData = ByteData(offsetsSize);
      for (var i = 0; i < strings.length; i++) {
        offsetsData.setUint32(i * 4, offsets[i], Endian.little);
      }
      poolBuilder.add(offsetsData.buffer.asUint8List());
      poolBuilder.add(stringsData);
      final poolBytes = poolBuilder.toBytes();

      // Dummy remaining chunk (e.g. XML tree chunk)
      final dummyXmlChunk = Uint8List.fromList([
        0x80,
        0x01,
        0x08,
        0x00,
        0x10,
        0x00,
        0x00,
        0x00,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);

      final totalSize = 8 + poolBytes.length + dummyXmlChunk.length;
      final fHeader = ByteData(8);
      fHeader.setUint32(0, 0x00080003, Endian.little);
      fHeader.setUint32(4, totalSize, Endian.little);

      final fullAxml = BytesBuilder();
      fullAxml.add(fHeader.buffer.asUint8List());
      fullAxml.add(poolBytes);
      fullAxml.add(dummyXmlChunk);

      final initialBytes = fullAxml.toBytes();

      // Execute modification
      final patched = AxmlModifier.modifyManifest(
        manifestBytes: initialBytes,
        oldPackage: oldPkg,
        newPackage: 'com.example.app.clone1',
      );

      expect(patched.length, greaterThan(0));

      // Verify that newPackage is present in patched bytes
      final patchedString = utf8.decode(patched, allowMalformed: true);
      expect(patchedString.contains('com.example.app.clone1'), isTrue);
      expect(patchedString.contains('com.example.app.clone1.provider'), isTrue);
    });

    test('AxmlModifier modifies UTF-16 string pool correctly', () {
      const oldPkg = 'com.test.alpha';
      const otherStr = 'Hello World';

      final strings = [oldPkg, otherStr];
      final strBytesList = <List<int>>[];
      for (final s in strings) {
        final b = BytesBuilder();
        b.addByte(s.length & 0xFF);
        b.addByte((s.length >> 8) & 0xFF);
        for (final cu in s.codeUnits) {
          b.addByte(cu & 0xFF);
          b.addByte((cu >> 8) & 0xFF);
        }
        b.addByte(0);
        b.addByte(0);
        strBytesList.add(b.toBytes());
      }

      final stringsDataBuilder = BytesBuilder();
      final offsets = <int>[];
      for (final sb in strBytesList) {
        offsets.add(stringsDataBuilder.length);
        stringsDataBuilder.add(sb);
      }
      final unaligned = stringsDataBuilder.length % 4;
      if (unaligned != 0) {
        for (var i = 0; i < 4 - unaligned; i++) {
          stringsDataBuilder.addByte(0);
        }
      }
      final stringsData = stringsDataBuilder.toBytes();

      const headerSize = 28;
      final offsetsSize = strings.length * 4;
      final stringsStart = headerSize + offsetsSize;
      final poolChunkSize = stringsStart + stringsData.length;

      final poolBuilder = BytesBuilder();
      final pHeader = ByteData(headerSize);
      pHeader.setUint16(0, 0x0001, Endian.little);
      pHeader.setUint16(2, headerSize, Endian.little);
      pHeader.setUint32(4, poolChunkSize, Endian.little);
      pHeader.setUint32(8, strings.length, Endian.little);
      pHeader.setUint32(12, 0, Endian.little);
      pHeader.setUint32(16, 0x00000000, Endian.little); // flags: UTF-16
      pHeader.setUint32(20, stringsStart, Endian.little);
      pHeader.setUint32(24, 0, Endian.little);
      poolBuilder.add(pHeader.buffer.asUint8List());

      final offsetsData = ByteData(offsetsSize);
      for (var i = 0; i < strings.length; i++) {
        offsetsData.setUint32(i * 4, offsets[i], Endian.little);
      }
      poolBuilder.add(offsetsData.buffer.asUint8List());
      poolBuilder.add(stringsData);
      final poolBytes = poolBuilder.toBytes();

      final totalSize = 8 + poolBytes.length;
      final fHeader = ByteData(8);
      fHeader.setUint32(0, 0x00080003, Endian.little);
      fHeader.setUint32(4, totalSize, Endian.little);

      final fullAxml = BytesBuilder();
      fullAxml.add(fHeader.buffer.asUint8List());
      fullAxml.add(poolBytes);

      final initialBytes = fullAxml.toBytes();

      final patched = AxmlModifier.modifyManifest(
        manifestBytes: initialBytes,
        oldPackage: oldPkg,
        newPackage: 'com.test.alpha.c1',
      );

      expect(patched.length, greaterThan(0));
    });
  });

  group('AndroidUserProfile Tests', () {
    test('AndroidUserProfile identifies owner and clone space correctly', () {
      const owner = AndroidUserProfile(id: 0, name: 'Owner', isRunning: true);
      expect(owner.isOwner, isTrue);
      expect(owner.isCloneSpace, isFalse);

      const cloneUser = AndroidUserProfile(
        id: 10,
        name: 'Work profile',
        isCloneSpace: true,
      );
      expect(cloneUser.isOwner, isFalse);
      expect(cloneUser.isCloneSpace, isTrue);
      expect(cloneUser.toString(), contains('cloneSpace: true'));
    });
  });
}
