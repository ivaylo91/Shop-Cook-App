import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifications the phone shows by itself, with nothing from a server:
/// cooking timers and use-by reminders. (Shared-list notifications come
/// from Firebase; see features/notifications/push.dart.)
///
/// Everything here is best effort and silent on failure, like push: a
/// phone that refuses notifications still has the timer on screen and the
/// dates in the pantry.
class LocalNotifications {
  LocalNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static final _taps = StreamController<String>.broadcast();

  /// The payload of each notification tapped while the app is running.
  static Stream<String> get taps => _taps.stream;

  /// Starts the plugin. Called once from `main`.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        },
      );
      _ready = true;
    } catch (_) {
      // No notifications then; timers still run on screen.
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _ready
      ? _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  /// Asks to notify (Android 13 and later), at the moment it starts to
  /// matter rather than at first launch. True when notifications can show.
  static Future<bool> askPermission() async {
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether alarms may go off at the exact minute. Android 14 and later
  /// leave this off until the user allows it in settings; without it a
  /// scheduled notification can come minutes late.
  static Future<bool> canRingOnTime() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system page where "Alarms & reminders" is allowed.
  static Future<void> openRingOnTimeSettings() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// The payload of the notification that opened the app, if one did.
  static Future<String?> launchPayload() async {
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  /// Shows a notification now, or replaces the one with the same [id].
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
      );
    } catch (_) {}
  }

  /// Shows a notification at [when], replacing whatever has [id] then.
  /// [exact] for a timer that must ring on the minute; a reminder can come
  /// a little late and saves the battery.
  static Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
    bool exact = false,
    String? payload,
  }) async {
    if (!_ready) return;
    final mode = exact && await canRingOnTime()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id: id,
        // An instant, so UTC does: the phone's own time zone only matters
        // for working out [when], which DateTime has already done.
        scheduledDate: tz.TZDateTime.from(when, tz.UTC),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        androidScheduleMode: mode,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Takes back a notification: removes it if shown, and calls it off if
  /// it was still to come.
  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  /// The ids of notifications still to come.
  static Future<Set<int>> pending() async {
    if (!_ready) return const {};
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return {for (final request in requests) request.id};
    } catch (_) {
      return const {};
    }
  }
}
