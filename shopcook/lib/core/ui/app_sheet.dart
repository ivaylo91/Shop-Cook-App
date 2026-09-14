import 'package:flutter/material.dart';

import '../design.dart';

/// A modal bottom sheet on the app's terms: the palette's ground, a rounded
/// top, a drag handle, and a title that does not have to be hand-built at
/// every call site.
///
/// Sheets rather than dialogs for anything the user picks from — a sheet is
/// reachable with a thumb, and a centred dialog is not.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            AppSheetHeader(title: title, subtitle: subtitle),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

/// The title block at the top of a sheet.
class AppSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppSheetHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.sm,
        Insets.xl,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(title, style: AppText.title.copyWith(color: palette.ink)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Insets.xs),
            Text(
              subtitle!,
              style: AppText.caption.copyWith(color: palette.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Yes/no confirmation, with the destructive option coloured as one.
///
/// Returns false when dismissed, so a caller can treat the result as a plain
/// bool rather than juggling a nullable.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Single-field text prompt — new list, new meal, rename.
///
/// Returns the trimmed value, or null if the user cancelled or left it empty,
/// so callers never have to re-check for blank input.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String? hint,
  String? initialValue,
  String confirmLabel = 'Save',
}) async {
  final controller = TextEditingController(text: initialValue);

  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
