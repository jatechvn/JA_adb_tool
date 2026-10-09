import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Power and GPU Optimization Service for JA ADB Tool.
///
/// Implements the `flutter-power-optimizer` specifications:
/// - Single Source of Truth for window focus, visibility, and user idle state.
/// UI-only animation policy; background services are not gated here.
/// Native CPU/GPU savings require measurement on a rebuilt executable.
class AppPowerManager {
  static final Logger _logger = Logger('AppPowerManager');

  static final AppPowerManager _instance = AppPowerManager._internal();
  static AppPowerManager get instance => _instance;
  factory AppPowerManager() => _instance;

  AppPowerManager._internal();

  static const String keyIdleSleepEnabled = 'power_idle_sleep_enabled';
  static const String keyIdleTimeoutSeconds = 'power_idle_timeout_seconds';

  static const Duration defaultIdleTimeout = Duration(seconds: 12);
  static const Duration interactionThrottle = Duration(milliseconds: 600);

  // Core state
  bool _isWindowFocused = true;
  bool _isWindowVisible = true;
  bool _isUserIdle = false;
  bool _idleSleepEnabled = true;
  Duration _idleTimeout = defaultIdleTimeout;

  Timer? _idleTimer;
  DateTime? _lastInteraction;
  int _configEpoch = 0;
  final ValueNotifier<bool> visibilityNotifier = ValueNotifier<bool>(true);

  // 3 ValueNotifiers
  final ValueNotifier<bool> backgroundAnimationNotifier = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> indicatorsAnimationNotifier = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> marqueeAnimationNotifier = ValueNotifier<bool>(
    true,
  );

  // Getters
  bool get shouldAnimateBackground => backgroundAnimationNotifier.value;
  bool get shouldAnimateIndicators => indicatorsAnimationNotifier.value;
  bool get shouldAnimateMarquee => marqueeAnimationNotifier.value;

  bool get isWindowFocused => _isWindowFocused;
  bool get isWindowVisible => _isWindowVisible;
  bool get isUserIdle => _isUserIdle;
  bool get idleSleepEnabled => _idleSleepEnabled;
  int get idleTimeoutSeconds => _idleTimeout.inSeconds;

  bool get _canAnimateBase => _isWindowFocused && _isWindowVisible;

  void _updateNotifiers() {
    visibilityNotifier.value = _isWindowVisible;
    final base = _canAnimateBase;
    final bg = base && !(_idleSleepEnabled && _isUserIdle);

    if (backgroundAnimationNotifier.value != bg) {
      backgroundAnimationNotifier.value = bg;
    }
    if (indicatorsAnimationNotifier.value != base) {
      indicatorsAnimationNotifier.value = base;
    }
    if (marqueeAnimationNotifier.value != base) {
      marqueeAnimationNotifier.value = base;
    }
  }

  // --- Window / Lifecycle Handlers ---

  void onWindowFocus() {
    _isWindowFocused = true;
    _lastInteraction = DateTime.now();
    _isUserIdle = false;
    _startIdleTimer();
    _updateNotifiers();
  }

  void onWindowBlur() {
    _isWindowFocused = false;
    _cancelIdleTimer();
    _updateNotifiers();
  }

  void onWindowMinimize() {
    _isWindowVisible = false;
    _isWindowFocused = false;
    _cancelIdleTimer();
    _updateNotifiers();
  }

  void onWindowRestore() {
    _isWindowVisible = true;
    // Note: restoring does not necessarily imply focus on Windows Win32.
    // We update based on whether it is already focused or await onWindowFocus().
    if (_isWindowFocused) {
      _startIdleTimer();
    }
    _updateNotifiers();
  }

  void onLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isWindowVisible = true;
        _isWindowFocused = true;
        _lastInteraction = DateTime.now();
        _isUserIdle = false;
        _startIdleTimer();
        break;
      case AppLifecycleState.inactive:
        _isWindowVisible = true;
        _isWindowFocused = false;
        _cancelIdleTimer();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _isWindowVisible = false;
        _isWindowFocused = false;
        _cancelIdleTimer();
        break;
      case AppLifecycleState.detached:
        _isWindowVisible = false;
        _isWindowFocused = false;
        _cancelIdleTimer();
        break;
    }
    _updateNotifiers();
  }

  // --- User Interaction & Idle Timer ---

  void recordUserInteraction({bool force = false}) {
    final now = DateTime.now();

    bool stateChanged = false;
    if (!_isWindowVisible) {
      _isWindowVisible = true;
      stateChanged = true;
    }
    if (!_isWindowFocused) {
      _isWindowFocused = true;
      stateChanged = true;
    }
    if (_isUserIdle) {
      _isUserIdle = false;
      stateChanged = true;
    }

    if (stateChanged) {
      _lastInteraction = now;
      _updateNotifiers();
      _startIdleTimer();
      return;
    }

    // Only throttle if already focused and active
    if (!force && _lastInteraction != null) {
      final elapsed = now.difference(_lastInteraction!);
      if (elapsed < interactionThrottle) return;
    }
    _lastInteraction = now;

    _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    if (!_idleSleepEnabled || !_canAnimateBase) return;

    _idleTimer = Timer(_idleTimeout, () {
      if (_canAnimateBase && !_isUserIdle) {
        _isUserIdle = true;
        _updateNotifiers();
      }
    });
  }

  void cancelIdleTimer() {
    _configEpoch++;
    _cancelIdleTimer();
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  // --- Configuration & Persistence ---

  Future<void> loadConfig() async {
    final epoch = ++_configEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _configEpoch) return;
      _idleSleepEnabled = prefs.getBool(keyIdleSleepEnabled) ?? true;
      final timeoutSec = prefs.getInt(keyIdleTimeoutSeconds) ?? 12;
      _idleTimeout = Duration(seconds: timeoutSec.clamp(5, 300));
    } catch (e) {
      _logger.warning('Failed to load power optimization config: $e');
    }
    if (epoch != _configEpoch) return;
    _startIdleTimer();
    _updateNotifiers();
  }

  Future<void> setIdleSleepEnabled(bool enabled) async {
    _idleSleepEnabled = enabled;
    if (!enabled) {
      _isUserIdle = false;
      _cancelIdleTimer();
    } else {
      _startIdleTimer();
    }
    _updateNotifiers();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIdleSleepEnabled, enabled);
    } catch (e) {
      _logger.warning('Failed to save idleSleepEnabled: $e');
    }
  }

  Future<void> setIdleTimeoutSeconds(int seconds) async {
    _idleTimeout = Duration(seconds: seconds.clamp(5, 300));
    if (_idleSleepEnabled && _canAnimateBase) {
      _startIdleTimer();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyIdleTimeoutSeconds, seconds);
    } catch (e) {
      _logger.warning('Failed to save idleTimeoutSeconds: $e');
    }
  }

  /// Testing helper to reset the singleton state cleanly.
  @visibleForTesting
  void resetForTesting({
    bool focused = true,
    bool visible = true,
    bool idle = false,
    bool idleSleepEnabled = false,
    Duration idleTimeout = const Duration(seconds: 12),
  }) {
    _configEpoch++;
    _cancelIdleTimer();
    _isWindowFocused = focused;
    _isWindowVisible = visible;
    _isUserIdle = idle;
    _idleSleepEnabled = idleSleepEnabled;
    _idleTimeout = idleTimeout;
    _lastInteraction = null;
    _updateNotifiers();
  }
}
