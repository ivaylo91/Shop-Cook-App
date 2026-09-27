import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Runs the shared-list sync for as long as someone is signed in.
///
/// A sync is started by a change queued on this phone, by the server saying
/// another member changed something, and by the app coming back to the
/// foreground. Bursts are gathered into one — ticking five items while
/// walking an aisle is one sync, not five — and a failed sync (no signal in
/// the shop) is retried until it goes through.
class ListSyncHost extends ConsumerStatefulWidget {
  final Widget child;

  const ListSyncHost({super.key, required this.child});

  @override
  ConsumerState<ListSyncHost> createState() => _ListSyncHostState();
}

class _ListSyncHostState extends ConsumerState<ListSyncHost> {
  static const _gather = Duration(milliseconds: 700);
  static const _retryAfter = Duration(seconds: 30);

  String? _userId;
  StreamSubscription<int>? _outbox;
  StreamSubscription<bool>? _anyShared;
  StreamSubscription<void>? _remote;
  Timer? _debounce;
  Timer? _retry;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _kick);
    ref.listenManual<String?>(
      currentUserIdProvider,
      (_, userId) => _follow(userId),
      fireImmediately: true,
    );
  }

  void _follow(String? userId) {
    if (userId == _userId) return;
    _stop();
    _userId = userId;
    if (userId == null) return;

    final db = ref.read(databaseProvider);
    _outbox = db.watchOutboxSize().listen((size) {
      if (size > 0) _kick();
    });
    // Listen to the server only while there is something shared to hear
    // about: a realtime connection per phone costs, and most never share.
    _anyShared = db
        .watchSharedLists()
        .map((marks) => marks.isNotEmpty)
        .distinct()
        .listen((shared) {
          _remote?.cancel();
          _remote = shared
              ? ref.read(listSyncProvider).remoteChanges().listen((_) => _kick())
              : null;
        });
    _kick();
  }

  void _kick() {
    if (_userId == null) return;
    _debounce?.cancel();
    _debounce = Timer(_gather, _run);
  }

  Future<void> _run() async {
    final userId = _userId;
    if (userId == null) return;
    _retry?.cancel();
    try {
      await ref.read(listSyncProvider).sync(userId);
    } catch (_) {
      // Offline or the server is unreachable: the queue keeps the changes.
      _retry = Timer(_retryAfter, _kick);
    }
  }

  void _stop() {
    _outbox?.cancel();
    _anyShared?.cancel();
    _remote?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    _outbox = null;
    _anyShared = null;
    _remote = null;
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
