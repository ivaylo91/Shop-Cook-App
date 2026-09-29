/// Invite links to a shared list.
///
/// A link points at a page on the app's own site (docs/join.html), not
/// straight at the app: messaging apps only make https addresses tappable,
/// and the page can offer the Play Store to someone who has not installed
/// ShopCook yet. Its button opens `shopcook://join/CODE`, which MainActivity
/// passes to the app.
///
/// The code travels in the query as `c`, not `code`: Supabase watches
/// incoming links for an auth `code` parameter, and must not mistake an
/// invite for a sign-in.
const inviteBase = 'https://ivaylo91.github.io/Shop-Cook-App/join.html';

String inviteLink(String code) => '$inviteBase?c=$code';

final _codeInLink = RegExp(
  r'join\.html\?(?:[^\s#]*&)?c=([A-Za-z2-9]{8})\b',
  caseSensitive: false,
);

/// The invite code in [text] — an invite message someone shared into the
/// app — or null when there is none.
String? inviteCodeIn(String text) =>
    _codeInLink.firstMatch(text)?.group(1)?.toUpperCase();

/// Tidies a code as typed or linked: case and separators do not matter,
/// "abcd-2345" and "ABCD 2345" are the same code.
String? cleanInviteCode(String raw) {
  final code = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return code.isEmpty ? null : code;
}
