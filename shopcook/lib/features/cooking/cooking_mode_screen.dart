import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/design.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';
import '../../data/remote/recipe_import_api.dart';
import 'step_timers.dart';

/// A recipe's ingredients and method: the saved copy when there is one,
/// otherwise read from the page (and saved for next time).
final recipeDetailsProvider = FutureProvider.autoDispose
    .family<RecipeImport, Recipe>(
      (ref, recipe) => ref.read(recipeRepositoryProvider).details(recipe),
    );

/// One step per screen, in type you can read from across the counter, with
/// the screen kept awake and any time in a step one tap from a timer.
class CookingModeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const CookingModeScreen({super.key, required this.recipe});

  @override
  ConsumerState<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _RunningTimer {
  final int id;
  final String label;
  final DateTime endsAt;
  bool rung = false;

  _RunningTimer(this.id, this.label, this.endsAt);

  Duration get remaining => endsAt.difference(DateTime.now());
  bool get isUp => !endsAt.isAfter(DateTime.now());
}

class _CookingModeScreenState extends ConsumerState<CookingModeScreen> {
  final _pages = PageController();
  final _checked = <int>{};
  final _timers = <_RunningTimer>[];
  Timer? _ticker;
  int _page = 0;
  int _nextTimerId = 0;

  @override
  void initState() {
    super.initState();
    // Hands are covered in flour; the phone must not lock mid-step.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pages.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startTimer(StepTimer timer) {
    HapticFeedback.selectionClick();
    setState(() {
      _timers.add(
        _RunningTimer(
          _nextTimerId++,
          timer.label,
          DateTime.now().add(timer.duration),
        ),
      );
    });
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    for (final timer in _timers) {
      if (timer.isUp && !timer.rung) {
        timer.rung = true;
        _ring();
      }
    }
    if (_timers.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
    setState(() {});
  }

  /// No notification plugin, so the alarm is the phone buzzing and the
  /// system alert sound — the screen is awake and in front of the cook.
  Future<void> _ring() async {
    for (var i = 0; i < 4; i++) {
      if (!mounted) return;
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
  }

  void _stopTimer(_RunningTimer timer) {
    setState(() => _timers.remove(timer));
  }

  void _goTo(int page) {
    _pages.animateToPage(page, duration: Motion.base, curve: Motion.enter);
  }

  Future<bool> _confirmLeave() async {
    if (_timers.every((t) => t.isUp)) return true;
    final l10n = context.l10n;
    return confirmAction(
      context,
      title: l10n.cookModeLeaveTitle,
      message: l10n.cookModeLeaveMessage,
      confirmLabel: l10n.cookModeLeaveConfirm,
      destructive: true,
    );
  }

  void _openPage() => context.push('/recipe', extra: widget.recipe);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final details = ref.watch(recipeDetailsProvider(widget.recipe));
    final loaded = details.valueOrNull;

    return PopScope(
      canPop: _timers.every((t) => t.isUp),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            loaded?.title.isNotEmpty == true
                ? loaded!.title
                : widget.recipe.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (loaded != null && loaded.hasIngredients)
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.listCheck, size: 17),
                tooltip: l10n.cookModeIngredients,
                onPressed: () => _showIngredients(loaded),
              ),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.globe, size: 17),
              tooltip: l10n.cookModeOpenPage,
              onPressed: _openPage,
            ),
          ],
        ),
        body: details.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Insets.lg),
            child: SkeletonRows(count: 4),
          ),
          error: (_, __) => _unavailable(),
          data: (recipe) => recipe.hasIngredients
              ? _cook(recipe)
              : recipe.failure == ImportFailure.unreachable
              ? _offline()
              : _unavailable(),
        ),
      ),
    );
  }

  /// Never read, and no connection to read it now. Distinct from
  /// [_unavailable]: this one is worth retrying.
  Widget _offline() {
    final l10n = context.l10n;
    return EmptyState(
      icon: FontAwesomeIcons.wifi,
      title: l10n.cookModeOfflineTitle,
      message: l10n.cookModeOfflineMessage,
      actionLabel: l10n.cookModeRetry,
      actionIcon: FontAwesomeIcons.arrowsRotate,
      onAction: () => ref.invalidate(recipeDetailsProvider(widget.recipe)),
    );
  }

  Widget _unavailable() {
    final l10n = context.l10n;
    return EmptyState(
      icon: FontAwesomeIcons.kitchenSet,
      title: l10n.cookModeUnavailableTitle,
      message: l10n.cookModeUnavailableMessage,
      actionLabel: l10n.cookModeOpenPage,
      actionIcon: FontAwesomeIcons.globe,
      onAction: _openPage,
    );
  }

  Widget _cook(RecipeImport recipe) {
    final l10n = context.l10n;
    final palette = context.palette;
    final steps = recipe.steps;
    // Page 0 gathers the ingredients; each step follows on its own page.
    final pageCount = steps.length + 1;
    final onLast = _page == pageCount - 1;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _page == 0
                      ? l10n.cookModeIngredients
                      : l10n.cookModeStepOf(_page, steps.length),
                  style: AppText.caption.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: Insets.sm),
                AppProgressBar(done: _page, total: steps.length, height: 6),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => index == 0
                  ? _IngredientsPage(
                      recipe: recipe,
                      checked: _checked,
                      onToggle: (i) => setState(
                        () => _checked.contains(i)
                            ? _checked.remove(i)
                            : _checked.add(i),
                      ),
                      onOpenPage: _openPage,
                    )
                  : _StepPage(
                      text: steps[index - 1],
                      onStartTimer: _startTimer,
                    ),
            ),
          ),
          if (_timers.isNotEmpty)
            _TimerTray(timers: _timers, onStop: _stopTimer),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.lg,
            ),
            child: Row(
              children: [
                if (_page > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _goTo(_page - 1),
                      icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 14),
                      label: Text(l10n.cookModeBack),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: onLast
                        ? () async {
                            final navigator = Navigator.of(context);
                            if (await _confirmLeave()) navigator.pop();
                          }
                        : () => _goTo(_page + 1),
                    icon: FaIcon(
                      onLast
                          ? FontAwesomeIcons.check
                          : FontAwesomeIcons.arrowRight,
                      size: 14,
                    ),
                    label: Text(
                      onLast
                          ? l10n.cookModeDone
                          : _page == 0
                          ? l10n.cookModeStartCooking
                          : l10n.cookModeNext,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showIngredients(RecipeImport recipe) {
    return showAppSheet<void>(
      context: context,
      title: context.l10n.cookModeIngredients,
      builder: (context) => StatefulBuilder(
        // The sheet and page 0 share one set of ticks.
        builder: (context, setSheetState) => SingleChildScrollView(
          child: _IngredientChecklist(
            ingredients: recipe.ingredients,
            checked: _checked,
            onToggle: (i) {
              setState(
                () => _checked.contains(i)
                    ? _checked.remove(i)
                    : _checked.add(i),
              );
              setSheetState(() {});
            },
          ),
        ),
      ),
    );
  }
}

class _IngredientsPage extends StatelessWidget {
  final RecipeImport recipe;
  final Set<int> checked;
  final ValueChanged<int> onToggle;
  final VoidCallback onOpenPage;

  const _IngredientsPage({
    required this.recipe,
    required this.checked,
    required this.onToggle,
    required this.onOpenPage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final facts = [
      if (recipe.servings.isNotEmpty) l10n.cookModeServings(recipe.servings),
      if (recipe.minutes > 0) l10n.cookModeMinutes(recipe.minutes),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      children: [
        Text(
          l10n.cookModeGetReady,
          style: AppText.display.copyWith(color: palette.ink),
        ),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: Insets.xs),
          Text(
            facts.join(' · '),
            style: AppText.body.copyWith(color: palette.inkMuted),
          ),
        ],
        const SizedBox(height: Insets.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: Insets.xs),
          tint: palette.ink,
          shadowOpacity: 0.05,
          child: _IngredientChecklist(
            ingredients: recipe.ingredients,
            checked: checked,
            onToggle: onToggle,
          ),
        ),
        if (recipe.steps.isEmpty) ...[
          const SizedBox(height: Insets.lg),
          InlineNote(message: l10n.cookModeNoSteps),
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenPage,
              icon: const FaIcon(FontAwesomeIcons.globe, size: 14),
              label: Text(l10n.cookModeOpenPage),
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}

class _IngredientChecklist extends StatelessWidget {
  final List<String> ingredients;
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  const _IngredientChecklist({
    required this.ingredients,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ingredients.length; i++)
          CheckboxListTile(
            value: checked.contains(i),
            onChanged: (_) => onToggle(i),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              ingredients[i],
              style: AppText.body.copyWith(
                fontSize: 17,
                color: checked.contains(i) ? palette.inkFaint : palette.ink,
                decoration: checked.contains(i)
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _StepPage extends StatelessWidget {
  final String text;
  final ValueChanged<StepTimer> onStartTimer;

  const _StepPage({required this.text, required this.onStartTimer});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final timers = findStepTimers(text);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big enough to read at arm's length from the chopping board.
          Text(
            text,
            style: TextStyle(
              fontSize: 25,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: palette.ink,
            ),
          ),
          if (timers.isNotEmpty) ...[
            const SizedBox(height: Insets.xl),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final timer in timers)
                  ActionChip(
                    avatar: FaIcon(
                      FontAwesomeIcons.stopwatch,
                      size: 14,
                      color: palette.accent,
                    ),
                    label: Text(context.l10n.cookModeTimerStart(timer.label)),
                    onPressed: () => onStartTimer(timer),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerTray extends StatelessWidget {
  final List<_RunningTimer> timers;
  final ValueChanged<_RunningTimer> onStop;

  const _TimerTray({required this.timers, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final error = Theme.of(context).colorScheme.error;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.sm,
        children: [
          for (final timer in timers)
            Tooltip(
              message: l10n.cookModeTimerStop,
              child: InputChip(
                avatar: FaIcon(
                  timer.isUp ? FontAwesomeIcons.bell : FontAwesomeIcons.stopwatch,
                  size: 14,
                  color: timer.isUp ? error : palette.accent,
                ),
                backgroundColor: timer.isUp
                    ? error.withValues(alpha: 0.12)
                    : palette.accent.withValues(alpha: 0.10),
                side: BorderSide.none,
                label: Text(
                  timer.isUp
                      ? l10n.cookModeTimerUp(timer.label)
                      : '${formatCountdown(timer.remaining)} · ${timer.label}',
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                    color: timer.isUp ? error : palette.ink,
                  ),
                ),
                onDeleted: () => onStop(timer),
                deleteIcon: const FaIcon(FontAwesomeIcons.xmark, size: 13),
                onPressed: () => onStop(timer),
              ),
            ),
        ],
      ),
    );
  }
}
