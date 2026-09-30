import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../../core/settings.dart';

const _shopsKey = 'review.shopsDone';
const _askedKey = 'review.askedAt';

/// How many finished shops before asking. By then the app has been useful
/// more than once; asking sooner asks someone who cannot know yet.
const reviewAfterShops = 3;

/// How long to leave someone alone after asking.
const reviewQuietPeriod = Duration(days: 120);

/// Whether this is a moment to ask for a Play Store rating.
///
/// [shopsDone] counts finished shops including the one just completed.
bool shouldAskForReview({
  required int shopsDone,
  required DateTime? lastAsked,
  required DateTime now,
}) {
  if (shopsDone < reviewAfterShops) return false;
  return lastAsked == null || now.difference(lastAsked) >= reviewQuietPeriod;
}

/// Call when a shop has been finished and cleared away. Counts it, and asks
/// for a rating when the time is right.
///
/// The request goes to Google Play's own review sheet, which decides for
/// itself whether to appear and never says whether it did — so this cannot
/// nag, and must not assume it was seen. It is asked at the end of a shop
/// because that is a finished task: nothing is interrupted.
Future<void> shopFinished(WidgetRef ref) async {
  final preferences = ref.read(sharedPreferencesProvider);
  final shops = (preferences.getInt(_shopsKey) ?? 0) + 1;
  await preferences.setInt(_shopsKey, shops);

  final askedAt = preferences.getInt(_askedKey);
  final now = DateTime.now();
  if (!shouldAskForReview(
    shopsDone: shops,
    lastAsked: askedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(askedAt),
    now: now,
  )) {
    return;
  }

  try {
    final review = InAppReview.instance;
    if (!await review.isAvailable()) return;
    await preferences.setInt(_askedKey, now.millisecondsSinceEpoch);
    // Let the "cleared" message be read before anything comes up over it.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await review.requestReview();
  } catch (_) {
    // No Play Store on this device, or the plugin is missing (tests).
  }
}
