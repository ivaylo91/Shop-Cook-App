import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/local_notifications.dart';

/// A running cooking timer.
class KitchenTimer {
  final int id;

  /// As the step put it: "20 minutes", "1 час".
  final String label;

  /// The recipe it was started from, so a notification says which pot.
  final String recipe;
  final DateTime endsAt;

  /// How its notifications are worded, kept to schedule the ring again.
  final TimerWording wording;

  /// Whether the screen has already rung for it.
  bool rung = false;

  KitchenTimer({
    required this.id,
    required this.label,
    required this.recipe,
    required this.endsAt,
    required this.wording,
  });

  Duration get remaining => endsAt.difference(DateTime.now());
  bool get isUp => !endsAt.isAfter(DateTime.now());

  /// Timers' notification ids sit apart from the reminders' (see
  /// use_by_reminders.dart): the countdown, and the ring at the end.
  int get countdownId => 7000 + id;
  int get ringId => 8000 + id;
}

/// The wording a timer's notifications use, passed in by the screen that
/// starts it: the timers live outside any widget, so have no locale.
class TimerWording {
  final String runningChannel;
  final String doneChannel;
  final String doneTitle;

  const TimerWording({
    required this.runningChannel,
    required this.doneChannel,
    required this.doneTitle,
  });
}

/// Cooking timers, app-wide rather than on the cooking screen: they carry
/// on when the cook leaves the recipe, locks the phone or switches app.
///
/// Each running timer is a notification with a live countdown, which
/// removes itself when the time is up. At that moment a scheduled
/// notification rings on a loud channel that plays as an alarm, so a timer
/// rings even when the app has been closed. It is a new notification rather
/// than the countdown updated in place: Android keeps an updated
/// notification where the silent one was, and it did not alert.
///
/// On screen, cooking mode shows the same timers in its tray.
class KitchenTimers extends Notifier<List<KitchenTimer>> {
  int _nextId = 0;

  @override
  List<KitchenTimer> build() {
    // Back from settings with "Alarms & reminders" allowed, the timers
    // already running are scheduled again, now to ring on the minute.
    final lifecycle = AppLifecycleListener(onResume: _reschedule);
    ref.onDispose(lifecycle.dispose);
    return const [];
  }

  Future<void> _reschedule() async {
    for (final timer in state) {
      if (!timer.isUp) await _scheduleRing(timer);
    }
  }

  Future<void> start({
    required String label,
    required Duration duration,
    required String recipe,
    required TimerWording wording,
  }) async {
    final timer = KitchenTimer(
      id: _nextId++,
      label: label,
      recipe: recipe,
      endsAt: DateTime.now().add(duration),
      wording: wording,
    );
    state = [...state, timer];

    await LocalNotifications.show(
      id: timer.countdownId,
      title: label,
      body: recipe,
      details: AndroidNotificationDetails(
        'kitchen_timers_running',
        wording.runningChannel,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        when: timer.endsAt.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        category: AndroidNotificationCategory.stopwatch,
        timeoutAfter: duration.inMilliseconds,
        color: _accent,
      ),
    );
    await _scheduleRing(timer);
  }

  Future<void> _scheduleRing(KitchenTimer timer) async {
    await LocalNotifications.schedule(
      id: timer.ringId,
      when: timer.endsAt,
      exact: true,
      title: timer.wording.doneTitle,
      body: '${timer.label} · ${timer.recipe}',
      details: AndroidNotificationDetails(
        'kitchen_timers_done',
        timer.wording.doneChannel,
        importance: Importance.max,
        priority: Priority.max,
        // At alarm volume, so it is heard with the ringer down.
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
        vibrationPattern: _ringPattern,
        color: _accent,
      ),
    );
  }

  /// Stops a timer, or clears one that has rung.
  Future<void> stop(KitchenTimer timer) async {
    state = [
      for (final t in state)
        if (t.id != timer.id) t,
    ];
    await LocalNotifications.cancel(timer.countdownId);
    await LocalNotifications.cancel(timer.ringId);
  }
}

final kitchenTimersProvider =
    NotifierProvider<KitchenTimers, List<KitchenTimer>>(KitchenTimers.new);

/// The app's green, for the notification's small icon.
const _accent = Color(0xFF2E7D32);

final _ringPattern = Int64List.fromList([0, 600, 300, 600, 300, 600]);
