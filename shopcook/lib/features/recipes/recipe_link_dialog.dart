import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../core/localization.dart';

/// A pasted recipe link, already checked to be a web address.
class RecipeLink {
  final String url;
  final String title;

  const RecipeLink({required this.url, required this.title});
}

/// Turns whatever was pasted into a usable web link, or null.
///
/// Accepts a bare "bonapeti.bg/…" by assuming https, because that is how
/// links get copied out of a browser's address bar on a phone. Rejects
/// anything that is not http(s) with a dotted host, so a stray word does not
/// become a "recipe" that opens nothing.
String? normaliseRecipeUrl(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'https://$text';

  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!uri.host.contains('.')) return null;
  return uri.toString();
}

/// Asks for a link and an optional title. Stays open with an error while the
/// link is invalid, rather than closing and silently doing nothing.
Future<RecipeLink?> promptForRecipeLink(
  BuildContext context, {
  String title = '',
  String initialUrl = '',
}) {
  return showDialog<RecipeLink>(
    context: context,
    builder: (context) =>
        _RecipeLinkDialog(initialTitle: title, initialUrl: initialUrl),
  );
}

class _RecipeLinkDialog extends StatefulWidget {
  final String initialTitle;
  final String initialUrl;

  const _RecipeLinkDialog({
    required this.initialTitle,
    required this.initialUrl,
  });

  @override
  State<_RecipeLinkDialog> createState() => _RecipeLinkDialogState();
}

class _RecipeLinkDialogState extends State<_RecipeLinkDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _url = TextEditingController(text: widget.initialUrl);
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final url = normaliseRecipeUrl(_url.text);
    if (url == null) {
      setState(() => _error = context.l10n.libraryLinkInvalid);
      return;
    }
    Navigator.pop(context, RecipeLink(url: url, title: _title.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.libraryAddLink),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _url,
            autofocus: widget.initialUrl.isEmpty,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.libraryLinkUrl,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.libraryLinkTitle),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.actionSave)),
      ],
    );
  }
}
