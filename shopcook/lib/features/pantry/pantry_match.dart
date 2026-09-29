import '../../data/local/database.dart' show foldName;

/// Whether [ingredient] is covered by something the user has at home.
///
/// Every word of a pantry entry has to be in the ingredient, so "olive oil"
/// at home covers "extra virgin olive oil" and "oil" covers both, while
/// "salt" does not cover "unsalted butter". Words match with a short ending
/// either way, which absorbs plurals and Bulgarian's article and plural
/// endings: "tomato" ~ "tomatoes", "яйца" ~ "яйцата", "брашно" ~ "брашното".
bool isAtHome(String ingredient, Iterable<String> pantryKeys) {
  final words = _words(ingredient);
  if (words.isEmpty) return false;
  for (final key in pantryKeys) {
    final wanted = _words(key);
    if (wanted.isEmpty) continue;
    if (wanted.every((w) => words.any((word) => _sameWord(word, w)))) {
      return true;
    }
  }
  return false;
}

List<String> _words(String text) => foldName(text)
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((word) => word.isNotEmpty)
    .toList();

/// Equal, or one is the other plus an ending of up to three letters — and
/// the shorter is long enough that this is not just a shared prefix
/// ("oil" and "oily" should not match; "egg" and "eggs" should).
bool _sameWord(String a, String b) {
  if (a == b) return true;
  final (short, long) = a.length <= b.length ? (a, b) : (b, a);
  if (short.length < 3 || long.length - short.length > 3) return false;
  if (!long.startsWith(short)) return false;
  final ending = long.substring(short.length);
  return short.length >= 4 || _pluralEndings.contains(ending);
}

/// For three-letter words only a plural ending counts, so "egg" matches
/// "eggs" but "oil" does not match "oily".
const _pluralEndings = {'s', 'es'};
