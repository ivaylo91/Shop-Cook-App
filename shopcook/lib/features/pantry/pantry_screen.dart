import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design.dart';
import '../../core/local_notifications.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/ui.dart';
import '../../data/local/database.dart';

/// Things the user has at home. Recipe imports and the week's shop leave
/// these off, so the olive oil in the cupboard is not bought again because
/// a recipe mentioned it.
///
/// Anything can carry a use-by date. Dated things come first, soonest at
/// the top, with a reminder the morning before (use_by_reminders.dart) and
/// recipe ideas one tap away: the yoghurt gets used, not thrown out.
class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    final userId = ref.read(currentUserIdProvider);
    if (name.isEmpty || userId == null) return;
    await ref.read(databaseProvider).addToPantry(userId, name);
    _controller.clear();
    _focus.requestFocus();
  }

  Future<void> _actions(PantryItem item) async {
    // Otherwise the add field takes focus back, and the keyboard with it,
    // once the sheet and the date picker close.
    _focus.unfocus();
    final l10n = context.l10n;
    final action = await showAppSheet<String>(
      context: context,
      title: item.name,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.calendarDay, size: 16),
            title: Text(item.useBy == null ? l10n.useBySet : l10n.useByChange),
            onTap: () => Navigator.pop(context, 'date'),
          ),
          if (item.useBy != null)
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.calendarXmark, size: 16),
              title: Text(l10n.useByClear),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          ListTile(
            leading: const FaIcon(FontAwesomeIcons.utensils, size: 16),
            title: Text(l10n.cookWith(item.name)),
            onTap: () => Navigator.pop(context, 'ideas'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    switch (action) {
      case 'date':
        await _pickDate(item);
      case 'clear':
        await db.setPantryUseBy(item.userId, item.key, null);
      case 'ideas':
        context.push(
          '/ingredient-recipes',
          extra: (name: item.name, mealId: null, mealName: null),
        );
    }
  }

  Future<void> _pickDate(PantryItem item) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = await showDatePicker(
      context: context,
      initialDate: item.useBy ?? today.add(const Duration(days: 3)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: context.l10n.useByPickerTitle,
    );
    if (day == null) return;
    await ref.read(databaseProvider).setPantryUseBy(item.userId, item.key, day);
    // The reminder is what the date is for; asked when the first is set.
    await LocalNotifications.askPermission();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final items = [...?ref.watch(pantryProvider).valueOrNull]
      ..sort(_soonestFirst);

    return Backdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l10n.pantryTitle)),
        body: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md),
              shadowOpacity: 0.07,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        hintText: l10n.pantryAddHint,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _add,
                    tooltip: l10n.actionAdd,
                    icon: FaIcon(
                      FontAwesomeIcons.circlePlus,
                      size: 20,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            if (items.isEmpty)
              InlineNote(message: l10n.pantryEmptyMessage)
            else ...[
              if (items.every((item) => item.useBy == null)) ...[
                InlineNote(message: l10n.pantryDatesHint),
                const SizedBox(height: Insets.md),
              ],
              AppCardList(
                tint: palette.accent,
                children: [
                  for (final item in items)
                    ListTile(
                      leading: FaIcon(
                        item.useBy == null
                            ? FontAwesomeIcons.house
                            : FontAwesomeIcons.hourglassHalf,
                        size: 14,
                        color: palette.accent,
                      ),
                      title: Text(item.name),
                      subtitle: item.useBy == null
                          ? null
                          : _UseByLabel(day: item.useBy!, locale: locale),
                      onTap: () => _actions(item),
                      trailing: IconButton(
                        tooltip: l10n.actionRemove,
                        icon: FaIcon(
                          FontAwesomeIcons.xmark,
                          size: 15,
                          color: palette.inkMuted,
                        ),
                        onPressed: () => ref
                            .read(databaseProvider)
                            .removeFromPantry(item.userId, item.key),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dated things first, soonest at the top; the rest by name.
int _soonestFirst(PantryItem a, PantryItem b) {
  final (x, y) = (a.useBy, b.useBy);
  if (x != null && y != null) return x.compareTo(y);
  if (x != null) return -1;
  if (y != null) return 1;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// "Use by tomorrow", in red from the day before.
class _UseByLabel extends StatelessWidget {
  final DateTime day;
  final String locale;

  const _UseByLabel({required this.day, required this.locale});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = DateUtils.dateOnly(day).difference(today).inDays;
    final text = switch (days) {
      < 0 => l10n.useByPast,
      0 => l10n.useByToday,
      1 => l10n.useByTomorrow,
      _ => l10n.useByOn(DateFormat('EEE d MMM', locale).format(day)),
    };
    final soon = days <= 1;
    return Text(
      text,
      style: AppText.caption.copyWith(
        color: soon ? Theme.of(context).colorScheme.error : palette.inkMuted,
        fontWeight: soon ? FontWeight.w600 : null,
      ),
    );
  }
}

/// What the signed-in user has at home.
final pantryProvider = StreamProvider<List<PantryItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(databaseProvider).watchPantry(userId);
});
