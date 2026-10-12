import 'package:flutter/widgets.dart';

import '../../features/shopping/product_category.dart';

/// The soft 3D food pictures the app is decorated with, bundled as WebP in
/// `assets/illustrations/` so they show offline.
///
/// One set, one style: everything was generated from the same prompt
/// recipe (clay-like, glossy, warm studio light, transparent ground), so a
/// screen mixing the hero basket with aisle pictures still reads as one
/// app. The aisle ones are 320 px and the large ones 640 px, square, with a
/// little room around the subject.
enum Art {
  basket,
  cooking,
  fridge,
  bag,
  produce,
  bakery,
  meat,
  dairy,
  frozen,
  pantry,
  drinks,
  household;

  String get _file => switch (this) {
    Art.bag => 'other',
    _ => name,
  };

  String get asset => 'assets/illustrations/$_file.webp';

  /// The picture for an aisle.
  static Art of(ProductCategory category) => switch (category) {
    ProductCategory.produce => Art.produce,
    ProductCategory.bakery => Art.bakery,
    ProductCategory.meatAndFish => Art.meat,
    ProductCategory.dairyAndEggs => Art.dairy,
    ProductCategory.frozen => Art.frozen,
    ProductCategory.pantry => Art.pantry,
    ProductCategory.drinks => Art.drinks,
    ProductCategory.household => Art.household,
    ProductCategory.other => Art.bag,
  };
}

/// One of the [Art] pictures at a square [size].
///
/// Decoded at the size it is shown, not the size it is stored, so a row of
/// small aisle pictures does not hold nine full bitmaps in memory.
class Illustration extends StatelessWidget {
  final Art art;
  final double size;

  const Illustration(this.art, {super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Image.asset(
      art.asset,
      width: size,
      height: size,
      cacheWidth: pixels,
      filterQuality: FilterQuality.medium,
      // Decorative: the text beside it already says what it shows.
      excludeFromSemantics: true,
      // A missing asset (a test without the bundle) leaves a gap, not an
      // error box.
      errorBuilder: (_, __, ___) => SizedBox.square(dimension: size),
    );
  }
}
