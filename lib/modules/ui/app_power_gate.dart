import 'package:flutter/widgets.dart';
import '../services/app_power_manager.dart';

/// Place above Navigator so ordinary tickers in routes and overlays are covered.
class AppPowerGate extends StatelessWidget {
  const AppPowerGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AppPowerManager.instance.indicatorsAnimationNotifier,
    child: child,
    builder: (context, enabled, child) =>
        TickerMode(enabled: enabled, child: child!),
  );
}
