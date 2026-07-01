import 'package:flutter/services.dart';

/// Controls the native background monitoring foreground service
/// (see MonitorService.kt).
class MonitorControl {
  static const _channel = MethodChannel('fileflow/monitor');

  /// Preference key shared with the native BootReceiver (stored by
  /// shared_preferences with a "flutter." prefix on the native side).
  static const prefKey = 'bg_monitor_enabled';

  static Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('start');
    } on PlatformException {
      // Service could not start (e.g. permission); app still works foreground.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // ignore
    }
  }

  /// Whether the app is exempt from battery optimization. Without this, Samsung
  /// and other OEMs freeze the background service and monitoring stops.
  static Future<bool> isBatteryExempt() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryExempt') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system dialog to allow the app to keep running in the background.
  /// No-op if already granted.
  static Future<void> requestBatteryExemption() async {
    try {
      await _channel.invokeMethod<void>('requestBatteryExemption');
    } on PlatformException {
      // ignore
    }
  }
}
