import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/apk_signing_setup_dialog.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';

void main() {
  for (final locale in ['en', 'vi', 'zh']) {
    testWidgets('signing setup renders at 1280x800 in $locale', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final language = LanguageProvider.forTesting(locale);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppLogic(initialize: false)),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => language),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ApkSigningSetupDialog()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(language.tr('apk_signing_prepare')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
