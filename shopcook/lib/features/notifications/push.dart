import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/settings.dart';

/// Notifications about shared lists, when the app is closed: "Ben added
/// Milk". The server decides what to send and words it (see the
/// send-list-notifications function); the app's part is to tell the server
/// which phone this is, and to open the right list when one is tapped.
///
/// Everything here is best effort and silent. A phone without Google Play
/// services, a declined permission or a failed registration costs the
/// notifications and nothing else — the lists still sync when the app is
/// open.

/// Whether Firebase started. False in tests and on a phone it cannot run
/// on; every entry point checks it rather than throw.
bool _ready = false;

/// Starts Firebase. Called once from `main`, before the first frame.
Future<void> initPush() async {
  try {
    await Firebase.initializeApp();
    _ready = true;
  } catch (_) {
    // No Play services, or no configuration: carry on without.
  }
}

/// The language the server should word this phone's notifications in.
String _language(WidgetRef ref) =>
    (ref.read(localeProvider) ?? PlatformDispatcher.instance.locale)
        .languageCode;

Future<void> _register(WidgetRef ref) async {
  if (!_ready) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client.rpc(
      'register_device',
      params: {'device_token': token, 'device_lang': _language(ref)},
    );
  } catch (_) {}
}

/// Asks for permission to notify, then registers this phone. Called after
/// sharing or joining a list — the moment notifications start to mean
/// something — rather than at first launch, when the honest answer to "may
/// this app notify you?" would be "about what?".
Future<void> askForNotifications(WidgetRef ref) async {
  if (!_ready) return;
  try {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    await _register(ref);
  } catch (_) {}
}

/// Stops notifying this phone for the account being signed out of. Must run
/// while still signed in: the server only lets an account remove its own.
Future<void> unregisterPush() async {
  if (!_ready) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await Supabase.instance.client.rpc(
      'unregister_device',
      params: {'device_token': token},
    );
  } catch (_) {}
}

/// Keeps this phone registered while someone is signed in, and opens the
/// list a tapped notification was about. Lives in the tab shell.
class PushHost extends ConsumerStatefulWidget {
  final Widget child;

  const PushHost({super.key, required this.child});

  @override
  ConsumerState<PushHost> createState() => _PushHostState();
}

class _PushHostState extends ConsumerState<PushHost> {
  StreamSubscription<RemoteMessage>? _taps;
  StreamSubscription<String>? _tokens;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (!_ready) return;

    _refresh();
    // Firebase replaces a phone's token now and then.
    _tokens = FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => _register(ref),
      onError: (_) {},
    );
    // A notification that arrives while the app is open is not shown by
    // the system, and is not needed: the list updates in front of the user
    // and the sync says who changed it. So only taps are handled.
    _taps = FirebaseMessaging.onMessageOpenedApp.listen(_open);
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null) _open(message);
        })
        .catchError((_) {});
  }

  /// Re-registers on every start when already allowed, which keeps the
  /// token and the language current. Never asks: that happens at sharing.
  Future<void> _refresh() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _register(ref);
      }
    } catch (_) {}
  }

  Future<void> _open(RemoteMessage message) async {
    final id = message.data['list_id'];
    if (id is! String || _opening || !mounted) return;
    _opening = true;
    try {
      final router = GoRouter.of(context);
      final list = await ref.read(databaseProvider).listById(id);
      if (list == null || !mounted) return;
      // Back to the lists first, then this one on top, as the home screen
      // widget does: one page with Lists behind it, however deep the app
      // was, and never a second copy of a list already open.
      router.go('/lists');
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      router.push('/list/${list.id}', extra: list);
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    _taps?.cancel();
    _tokens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
