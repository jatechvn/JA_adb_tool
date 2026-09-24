import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

void main() {
  late AppLogic logic;
  setUp(() {
    logic = AppLogic(initialize: false);
    logic.latestMedia.addAll(
      List.generate(
        6,
        (i) => AndroidMediaItem(
          path: '/media/$i',
          dateAdded: 100 - i,
          name: '$i',
          isVideo: i.isEven,
        ),
      ),
    );
  });
  tearDown(() => logic.dispose());

  test('photo presets exclude videos and replace previous selection', () {
    logic.selectLatestNMedia(50);
    logic.selectLatestNMedia(2, isVideo: false);
    expect(logic.selectedMediaPaths, {'/media/1', '/media/3'});
  });
  test('video presets exclude photos and clamp to matching count', () {
    for (final n in [10, 25, 50]) {
      logic.selectLatestNMedia(n, isVideo: true);
      expect(logic.selectedMediaPaths, {'/media/0', '/media/2', '/media/4'});
    }
  });
  test('all preserves ordering; zero, negative and empty clear selection', () {
    logic.selectLatestNMedia(2);
    expect(logic.selectedMediaPaths, {'/media/0', '/media/1'});
    for (final n in [0, -1]) {
      logic.selectLatestNMedia(n);
      expect(logic.selectedMediaPaths, isEmpty);
    }
    logic.latestMedia.clear();
    logic.selectLatestNMedia(50, isVideo: false);
    expect(logic.selectedMediaPaths, isEmpty);
  });
}
