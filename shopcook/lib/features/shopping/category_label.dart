import '../../l10n/app_localizations.dart';
import 'product_category.dart';

/// The aisle heading, in the reader's language.
///
/// Kept out of the enum so `ProductCategory` stays free of UI concerns and
/// can be used from tests and the parser without a locale in hand.
extension LocalizedProductCategory on ProductCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ProductCategory.produce => l10n.categoryProduce,
    ProductCategory.bakery => l10n.categoryBakery,
    ProductCategory.meatAndFish => l10n.categoryMeatAndFish,
    ProductCategory.dairyAndEggs => l10n.categoryDairyAndEggs,
    ProductCategory.frozen => l10n.categoryFrozen,
    ProductCategory.pantry => l10n.categoryPantry,
    ProductCategory.drinks => l10n.categoryDrinks,
    ProductCategory.household => l10n.categoryHousehold,
    ProductCategory.other => l10n.categoryOther,
  };
}
