// lib/modules/native_bridge.dart
import 'dart:io' show Platform;
import 'logger_config.dart';
import 'native/win_core.dart';
import 'native/mac_core.dart';
import 'native/linux_core.dart';

abstract class NativeEngine {
  dynamic heavyCompute(dynamic dataInput);
}

class NativeBridge {
  final String osName;
  NativeEngine? engine;

  NativeBridge() : osName = Platform.operatingSystem {
    _initializeEngine();
  }

  void _initializeEngine() {
    try {
      if (Platform.isWindows) {
        engine = WindowsNativeEngine();
      } else if (Platform.isMacOS) {
        engine = MacNativeEngine();
      } else if (Platform.isLinux) {
        engine = LinuxNativeEngine();
      } else {
        logger.warning(
          '[BRIDGE] OS $osName is not supported by Hybrid Core. Using fallback.',
        );
      }
    } catch (e) {
      logger.severe('[BRIDGE] Failed to initialize engine for $osName: $e');
    }
  }

  dynamic executeHeavyTask(dynamic dataInput) {
    if (engine != null) {
      return engine!.heavyCompute(dataInput);
    }
    return _pureDartFallback(dataInput);
  }

  dynamic _pureDartFallback(dynamic dataInput) {
    logger.info('[BRIDGE] Processing using pure Dart algorithm.');
    return dataInput;
  }
}

final nativeAgent = NativeBridge();
