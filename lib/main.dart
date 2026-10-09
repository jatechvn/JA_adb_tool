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
import 'modules/services/app_power_manager.dart';
import 'modules/ui/app_power_gate.dart';

void main(List<String> args) async {
  if (args.contains('-debug') ||
      args.contains('--debug') ||
      args.contains('-d')) {
    BuildInfo.isCliDebug = true;
  }
  WidgetsFlutterBinding.ensureInitialized();
  AppPowerManager.instance.onLifecycleStateChanged(
    WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
  );

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
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) =>
              AppPowerManager.instance.recordUserInteraction(),
          onPointerMove: (_) =>
              AppPowerManager.instance.recordUserInteraction(),
          onPointerHover: (_) =>
              AppPowerManager.instance.recordUserInteraction(),
          onPointerSignal: (_) =>
              AppPowerManager.instance.recordUserInteraction(),
          child: Focus(
            autofocus: false,
            onKeyEvent: (_, _) {
              AppPowerManager.instance.recordUserInteraction();
              return KeyEventResult.ignored;
            },
            child: AppPowerGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      home: const MainWindow(),
    );
  }
}
