// Speech arrives as one run-on sentence: "milk, 2 kg potatoes and eggs".
// Commas are sometimes there and sometimes not, so the joining words
// matter as much as the punctuation.
final _separators = RegExp(
  r'\s*[,;\n]\s*|\s+(?:and|also|plus|then|и|плюс|после|още)\s+',
  caseSensitive: false,
  unicode: true,
);

// What people say before the list itself.
final _lead = RegExp(
  r'^(?:please\s+)?(?:add|buy|get|i need|we need|добави|купи|вземи|трябва ми|трябват ми|трябва)\s+',
  caseSensitive: false,
  unicode: true,
);

/// Splits dictated text into one item per entry.
List<String> splitSpokenList(String spoken) {
  final text = spoken.trim().replaceFirst(_lead, '');
  return [
    for (final part in text.split(_separators))
      if (_tidy(part).isNotEmpty) _tidy(part),
  ];
}

String _tidy(String part) => part
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceFirst(RegExp(r'[.!?]+$'), '')
    .trim();
