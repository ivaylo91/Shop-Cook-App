/// What another app shared with ShopCook, once it has been read.
sealed class SharedContent {
  const SharedContent();
}

/// A link: goes to the recipe library.
class SharedLink extends SharedContent {
  final String url;

  /// The page title when the sharing app sent one; may be empty.
  final String title;

  const SharedLink(this.url, this.title);
}

/// Plain text with no link, one item per line: goes onto a list.
class SharedItems extends SharedContent {
  final List<String> lines;

  const SharedItems(this.lines);
}

final _url = RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false);

// "- ", "* ", "• ", "1. ", "[ ] ", "☐ " and friends, which notes apps put in
// front of list items. Applied repeatedly: "- [ ] milk" has two.
final _marker = RegExp(r'^(?:[-*•·▪◦–]|\[[ xX]?\]|[☐☑✓✔]|\d+[.)])\s*');

/// A shared list longer than this is almost certainly not a shopping list.
const _maxLines = 100;

/// A title longer than this is the body of a message, not a title.
const _maxTitle = 140;

/// Reads a share. Returns null when there is nothing usable in it.
///
/// Anything containing a link is treated as a link: browsers send the URL
/// with the title as the subject, YouTube sends "title + URL" as text, and
/// either way the link is the point.
SharedContent? parseShared(String text, {String? subject}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final match = _url.firstMatch(trimmed);
  if (match != null) {
    final raw = match.group(0)!;
    // A link at the end of a sentence carries its full stop with it.
    final url = raw.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
    final fromSubject = subject?.trim() ?? '';
    final title = _tidyTitle(
      fromSubject.isNotEmpty ? fromSubject : trimmed.replaceFirst(raw, ''),
    );
    return SharedLink(url, title.length > _maxTitle ? '' : title);
  }

  final lines = <String>[];
  for (final line in trimmed.split(RegExp(r'\r?\n'))) {
    var item = line.trim();
    while (true) {
      final stripped = item.replaceFirst(_marker, '');
      if (stripped == item) break;
      item = stripped;
    }
    item = item.trim();
    // Blank lines, and headings such as "Shopping:" or "За пазара:".
    if (item.isEmpty || item.endsWith(':')) continue;
    lines.add(item);
    if (lines.length == _maxLines) break;
  }
  return lines.isEmpty ? null : SharedItems(lines);
}

String _tidyTitle(String text) => text
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    // Leftover separators once the link has been cut out: "Title - ".
    .replaceFirst(RegExp(r'[\s:|–—-]+$'), '')
    .replaceFirst(RegExp(r'^[\s:|–—-]+'), '')
    .trim();
