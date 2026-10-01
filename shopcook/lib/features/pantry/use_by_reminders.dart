import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_notifications.dart';
import '../../core/localization.dart';
import '../../data/local/database.dart';
import 'pantry_screen.dart';

/// Reminders ids sit in their own range, apart from cooking timers'.
const _firstId = 20000;
const _idRange = 1000000;

/// The payload a reminder carries, which opens the pantry when tapped.
const _payload = 'pantry';

/// When the reminder for something used by [day] goes out: nine in the
/// morning the day before, early enough to plan the evening around it.
DateTime reminderTime(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1, 9);

/// A notification id that stays the same for an item across launches, so
/// a changed date replaces the old reminder instead of adding a second.
/// FNV-1a: String.hashCode is not stable between runs.
int reminderId(String userId, String key) {
  var hash = 0x811c9dc5;
  for (final unit in '$userId/$key'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return _firstId + hash % _idRange;
}

/// Keeps the phone's scheduled use-by reminders matching the pantry: one
/// for each dated item whose reminder is still to come, none for the rest.
///
/// Matching the whole set, rather than scheduling on each edit, covers
/// every way the pantry changes — a date set or cleared, an item removed,
/// signing out (an empty pantry) — and puts reminders back on start after
/// anything that wiped them. Lives in the tab shell; also opens the pantry
/// when a reminder is tapped.
class UseByReminders extends ConsumerStatefulWidget {
  final Widget child;

  const UseByReminders({super.key, required this.child});

  @override
  ConsumerState<UseByReminders> createState() => _UseByRemindersState();
}

class _UseByRemindersState extends ConsumerState<UseByReminders> {
  StreamSubscription<String>? _taps;

  /// What was last scheduled in this session, so an unchanged pantry is
  /// not rescheduled on every update.
  final _scheduled = <int, String>{};

  @override
  void initState() {
    super.initState();
    _taps = LocalNotifications.taps.listen(_open);
    // fireImmediately: the pantry as it is at start counts too, which is
    // what puts reminders back after a restart.
    ref.listenManual(pantryProvider, (_, next) {
      final items = next.valueOrNull;
      if (items != null) _sync(items);
    }, fireImmediately: true);
    LocalNotifications.launchPayload().then((payload) {
      if (payload != null) _open(payload);
    });
  }

  void _open(String payload) {
    if (payload != _payload || !mounted) return;
    GoRouter.of(context).push('/pantry');
  }

  Future<void> _sync(List<PantryItem> items) async {
    if (!mounted) return;
    final l10n = context.l10n;
    final now = DateTime.now();
    final wanted = <int, PantryItem>{
      for (final item in items)
        if (item.useBy != null && reminderTime(item.useBy!).isAfter(now))
          reminderId(item.userId, item.key): item,
    };

    for (final id in await LocalNotifications.pending()) {
      final ours = id >= _firstId && id < _firstId + _idRange;
      if (ours && !wanted.containsKey(id)) {
        await LocalNotifications.cancel(id);
        _scheduled.remove(id);
      }
    }

    for (final MapEntry(key: id, value: item) in wanted.entries) {
      final signature = '${item.name}|${item.useBy}';
      if (_scheduled[id] == signature) continue;
      await LocalNotifications.schedule(
        id: id,
        when: reminderTime(item.useBy!),
        title: l10n.useByReminderTitle(item.name),
        body: l10n.useByReminderBody,
        payload: _payload,
        details: AndroidNotificationDetails(
          'use_by',
          l10n.useByChannel,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFF2E7D32),
        ),
      );
      _scheduled[id] = signature;
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
