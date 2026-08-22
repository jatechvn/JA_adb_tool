// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modules/constants.dart';
import 'modules/build_info.dart';
import 'modules/logger_config.dart';
import 'modules/logic.dart';
import 'modules/ui/styles.dart';
import 'modules/ui/main_window.dart';
import 'modules/ui/localization.dart';

void main(List<String> args) async {
  if (args.contains('-debug') ||
      args.contains('--debug') ||
      args.contains('-d')) {
    BuildInfo.isCliDebug = true;
  }
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  await initLogger();

  // Resolve the saved language before the first frame so the UI does not
  // briefly render English and then switch to the user's locale.
  final languageProvider = LanguageProvider();
  await languageProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppLogic()),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: '$appName v$appVersion',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainWindow(),
    );
  }
}
