/// A duration mentioned in a recipe step, offered as a one-tap timer.
class StepTimer {
  /// The words as the step wrote them ("10-15 минути"), so the chip speaks
  /// the recipe's language rather than the app's.
  final String label;
  final Duration duration;

  const StepTimer(this.label, this.duration);

  @override
  bool operator ==(Object other) =>
      other is StepTimer && other.duration == duration && other.label == label;

  @override
  int get hashCode => Object.hash(label, duration);
}

// Units in English and Bulgarian. Bare "h", "m" and "ч." are left out on
// purpose: "1 ч. л." is a teaspoon, not an hour. The lookahead stops "мин"
// matching the start of a longer word.
final _durations = RegExp(
  r'(\d+(?:[.,]\d+)?)'
  r'(?:\s*(?:-|–|—|to|до)\s*(\d+(?:[.,]\d+)?))?'
  r'\s*'
  r'(hours?|hrs?|minutes?|mins?|seconds?|secs?'
  r'|часа|часове|час|минути|минута|мин|секунди|секунда|сек)'
  r'(?![\p{L}])',
  caseSensitive: false,
  unicode: true,
);

/// Anything longer is "leave overnight" territory, not a kitchen timer.
const _longest = Duration(hours: 24);

/// Every distinct duration in [step], in the order they appear.
///
/// A range ("10-15 minutes") times the lower bound: the point of the timer
/// is to go and look, and looking early costs nothing.
List<StepTimer> findStepTimers(String step) {
  final found = <StepTimer>[];
  for (final match in _durations.allMatches(step)) {
    final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (amount == null || amount <= 0) continue;

    final unit = match.group(3)!.toLowerCase();
    final seconds = switch (unit) {
      _ when unit.startsWith('h') || unit.startsWith('ч') => amount * 3600,
      _ when unit.startsWith('s') || unit.startsWith('се') => amount,
      _ => amount * 60,
    };

    final duration = Duration(seconds: seconds.round());
    if (duration > _longest) continue;

    final timer = StepTimer(match.group(0)!.trim(), duration);
    if (!found.any((t) => t.duration == duration)) found.add(timer);
  }
  return found;
}

/// "4:05" or "1:02:30" — a countdown readout.
String formatCountdown(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final hours = clamped.inHours;
  final minutes = clamped.inMinutes.remainder(60);
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}
