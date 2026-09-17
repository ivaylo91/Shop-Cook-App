import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/local/database.dart';
import 'widget_snapshot.dart';

const _androidWidget = 'com.shopcook.shopcook.ShoppingListWidget';

final _widgetListsProvider = StreamProvider<List<ShoppingList>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(shoppingListRepositoryProvider).watchLists(userId);
});

final _widgetProductsProvider = StreamProvider<List<Product>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(databaseProvider).watchAllProductsForUser(userId);
});

final widgetSnapshotProvider = Provider<WidgetSnapshot?>((ref) {
  final lists = ref.watch(_widgetListsProvider).valueOrNull;
  final products = ref.watch(_widgetProductsProvider).valueOrNull;
  if (lists == null || products == null) return null;
  return pickWidgetSnapshot(lists, products);
});

/// Keeps the home screen widget in step with the lists, and opens the list
/// the widget was showing when it is tapped.
///
/// The widget itself is plain Android views with no Flutter behind it, so
/// everything it shows is decided and worded here, in the app's language.
class HomeWidgetSync extends ConsumerStatefulWidget {
  final Widget child;

  const HomeWidgetSync({super.key, required this.child});

  @override
  ConsumerState<HomeWidgetSync> createState() => _HomeWidgetSyncState();
}

class _HomeWidgetSyncState extends ConsumerState<HomeWidgetSync> {
  StreamSubscription<Uri?>? _clicks;
  bool _opening = false;
  WidgetSnapshot? _pushed;
  Locale? _pushedLocale;

  @override
  void initState() {
    super.initState();
    // Both fail on a platform without the widget (tests, iOS with no
    // extension); there is nothing to open there, so errors are dropped.
    _clicks = HomeWidget.widgetClicked.listen(_open, onError: (_) {});
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_open)
        .catchError((_) {});
  }

  @override
  void dispose() {
    _clicks?.cancel();
    super.dispose();
  }

  Future<void> _open(Uri? uri) async {
    if (uri == null || uri.host != 'list' || uri.pathSegments.isEmpty) return;
    // A tap can arrive twice (the launch intent and the click stream); one
    // at a time, or both get past the check below while the other awaits.
    if (_opening) return;
    _opening = true;
    try {
      final id = uri.pathSegments.first;
      final router = GoRouter.of(context);
      final lists = await ref.read(_widgetListsProvider.future);
      final list = lists.where((l) => l.id == id).firstOrNull;
      if (list == null || !mounted) return;
      // Back to the lists first, then open this one: tapping the widget
      // always lands on the same one page with Lists behind it, however
      // deep the app already was — including on this very list, which a
      // plain push would stack a second copy of.
      router.go('/lists');
      // go only schedules the navigation; pushing in the same frame would
      // be undone by it.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      router.push('/list/${list.id}', extra: list);
    } finally {
      _opening = false;
    }
  }

  Future<void> _push(WidgetSnapshot snapshot) async {
    final locale = Localizations.localeOf(context);
    if (snapshot == _pushed && locale == _pushedLocale) return;
    _pushed = snapshot;
    _pushedLocale = locale;

    final l10n = context.l10n;
    final list = snapshot.list;
    final lines = [
      for (final line in snapshot.lines) '• $line',
      if (snapshot.more > 0) l10n.widgetMore(snapshot.more),
    ];

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>('list_id', list?.id),
        HomeWidget.saveWidgetData<String>(
          'title',
          list?.name ?? l10n.appTitle,
        ),
        HomeWidget.saveWidgetData<String>(
          'summary',
          list == null ? '' : l10n.widgetSummary(snapshot.left),
        ),
        HomeWidget.saveWidgetData<String>(
          'items',
          list == null
              ? l10n.widgetNoLists
              : lines.isEmpty
              ? l10n.widgetAllDone
              : lines.join('\n'),
        ),
      ]);
      await HomeWidget.updateWidget(qualifiedAndroidName: _androidWidget);
    } on MissingPluginException {
      // See initState.
    } on PlatformException {
      // No widget placed, or the launcher refused; nothing to show anyway.
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(widgetSnapshotProvider);
    if (snapshot != null) {
      // After the frame: saving talks to the platform, which has no place
      // inside a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _push(snapshot);
      });
    }
    return widget.child;
  }
}
