import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/helper_ime_dialog.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'helper_ime_session_test.dart' show FakeImeAdb;

class HelperDialogLogic extends AppLogic {
  HelperDialogLogic() : super(initialize: false);
  void changeDevice(String device) {
    setSelectedDeviceForTesting(device);
    notifyListeners();
  }
}

void main() {
  for (final locale in ['en', 'vi', 'zh']) {
    testWidgets('explicit opt-in, composing guard and close restore $locale', (
      tester,
    ) async {
      final adb = FakeImeAdb();
      var session = adb.session();
      final logic = HelperDialogLogic()..setSelectedDeviceForTesting('A');
      final lang = LanguageProvider.forTesting(locale);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: lang,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        HelperImeDialog(logic: logic, session: session),
                  ),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(adb.calls, isEmpty);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(lang.tr('helper_enable')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('helper-text')),
      );
      field.controller!.value = const TextEditingValue(
        text: 'Việt',
        composing: TextRange(start: 0, end: 4),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('helper-send')))
            .onPressed,
        isNull,
      );
      field.controller!.value = const TextEditingValue(
        text: 'Việt',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('helper-send')));
      await tester.pumpAndSettle();
      expect(
        adb.calls.where((args) => args.contains('ADB_INPUT_B64')).length,
        1,
      );
      expect(field.controller!.text, isEmpty);
      adb.failRestore = true;
      await tester.tap(find.text(lang.tr('helper_close')));
      await tester.pumpAndSettle();
      expect(find.text(lang.tr('helper_restore_failed')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('helper-send')))
            .onPressed,
        isNull,
      );
      adb.failRestore = false;
      await tester.tap(find.text(lang.tr('helper_close')));
      await tester.pumpAndSettle();
      expect(find.byType(HelperImeDialog), findsNothing);
      expect(adb.enabled, isFalse);
      // Reopen a fresh session, then simulate selection change while active.
      session = adb.session();
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(lang.tr('helper_enable')));
      await tester.pumpAndSettle();
      logic.changeDevice('B');
      await tester.pumpAndSettle();
      expect(find.byType(HelperImeDialog), findsNothing);
      expect(adb.enabled, isFalse);
      expect(adb.calls.every((args) => args[1] == 'A'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      logic.dispose();
      lang.dispose();
    });
  }
}
