import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends uncaught errors to the project's own `crash_reports` table.
///
/// Without this, a crash on a tester's phone is simply never heard about.
/// What is sent is the error, its stack, the app version and the OS — no
/// account, no list contents — and nothing leaves a debug build, where the
/// console already shows every error.
class CrashReporter {
  CrashReporter._();

  /// One session reporting the same failure in a loop (a broken frame
  /// rebuilds sixty times a second) would otherwise send it sixty times.
  static final _sent = <String>{};
  static const _maxPerSession = 10;

  static String _version = '?';

  /// Hooks the reporter into Flutter's and the platform's error handlers.
  /// Call once, after Supabase is initialised.
  static Future<void> install() async {
    if (!kReleaseMode) return;

    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      report(details.exception, details.stack, fatal: false);
    };

    // Errors outside any frame: async gaps, platform channels, isolates.
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, fatal: true);
      return true;
    };
  }

  /// Files one report. Never throws: a reporter that crashes while
  /// reporting a crash makes things worse.
  static Future<void> report(
    Object error,
    StackTrace? stack, {
    required bool fatal,
  }) async {
    if (!kReleaseMode) return;

    final errorText = _cap(error.toString(), 2000);
    final stackText = _cap(stack?.toString() ?? '', 8000);
    final key = '$errorText\n${stackText.split('\n').first}';
    if (_sent.length >= _maxPerSession || !_sent.add(key)) return;

    try {
      await Supabase.instance.client.from('crash_reports').insert({
        'app_version': _cap(_version, 40),
        'os': _cap(
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
          200,
        ),
        'fatal': fatal,
        'error': errorText,
        'stack': stackText,
      });
    } catch (_) {
      // Offline, or the server said no. There is nowhere left to report to.
    }
  }

  static String _cap(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);
}
