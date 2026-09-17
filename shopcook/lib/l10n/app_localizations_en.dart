// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ShopCook';

  @override
  String get appTagline => 'Shop for the week, cook what you planned.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRename => 'Rename';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get navLists => 'Lists';

  @override
  String get navPlan => 'Plan';

  @override
  String get navSettings => 'Settings';

  @override
  String get listsLoadError => 'Could not load your lists';

  @override
  String get listsLoadErrorDetail =>
      'Your lists are stored on this device, so this is usually temporary.';

  @override
  String get listsEmptyTitle => 'No shopping lists yet';

  @override
  String get listsEmptyMessage =>
      'A list holds the meals you are cooking and everything you need to buy for them.';

  @override
  String get listsEmptyAction => 'Create a list';

  @override
  String get listsNewTitle => 'New shopping list';

  @override
  String get listsNewHint => 'e.g. Weekly groceries';

  @override
  String get listsRenameTitle => 'Rename list';

  @override
  String listsDeleteTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get listsDeleteMessage =>
      'This also removes its meals, items and recipes. You can undo it straight afterwards.';

  @override
  String listsDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get listCardEmpty => 'Empty — open it to add meals and items.';

  @override
  String get listCardAllPicked => 'Everything picked up';

  @override
  String listCardLeftToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left to buy',
      one: '1 left to buy',
    );
    return '$_temp0';
  }

  @override
  String get listDetailShoppingMode => 'Shopping mode';

  @override
  String get listDetailMealsError => 'Could not load the meals';

  @override
  String get listDetailOtherItems => 'Other items';

  @override
  String get listDetailItemsError => 'Could not load the items';

  @override
  String get listDetailUnassignedNote =>
      'Anything you add without picking a meal lands here — the milk and the washing-up liquid.';

  @override
  String get listDetailComposerHint => 'Add an item — try \"2 kg potatoes\"';

  @override
  String get mealNewTitle => 'New meal';

  @override
  String get mealNewHint => 'e.g. Spaghetti Bolognese';

  @override
  String get mealRenameTitle => 'Rename meal';

  @override
  String get mealDelete => 'Delete meal';

  @override
  String mealDeleted(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get mealActions => 'Meal actions';

  @override
  String get mealCardNoIngredients =>
      'No ingredients yet — open it to add some or find a recipe.';

  @override
  String get itemActions => 'Item actions';

  @override
  String get itemFindRecipes => 'Find recipes';

  @override
  String get itemFindRecipesFromList => 'What can I cook with this?';

  @override
  String get itemFindRecipesFromMeal => 'What else can I cook with this?';

  @override
  String get itemMoveToMeal => 'Move to a meal';

  @override
  String itemRemoved(String name) {
    return 'Removed $name';
  }

  @override
  String get itemMoveNeedsMeal =>
      'Create a meal first, then move items into it.';

  @override
  String itemMoveTitle(String name) {
    return 'Move \"$name\" to';
  }

  @override
  String get mealPlanDay => 'Plan a day for this meal';

  @override
  String mealPlannedFor(String date) {
    return 'Planned for $date';
  }

  @override
  String get mealFindRecipe => 'Find a recipe';

  @override
  String get mealIngredients => 'Ingredients';

  @override
  String get mealIngredientsError => 'Could not load the ingredients';

  @override
  String get mealIngredientsEmpty =>
      'No ingredients yet. Add them by hand, or find a recipe and import its list in one go.';

  @override
  String get mealComposerHint => 'Add an ingredient';

  @override
  String get mealRecipe => 'Recipe';

  @override
  String get mealRecipeError => 'Could not load the recipe';

  @override
  String get mealRecipeEmpty =>
      'No recipe attached yet. Find one and its ingredients can be imported straight onto this meal.';

  @override
  String get mealMoveDay => 'Move to another day';

  @override
  String get mealGiveDay => 'Give it a day';

  @override
  String get mealClearDay => 'Take off the plan';

  @override
  String mealCookOn(String name) {
    return 'Cook $name on';
  }

  @override
  String get recipeSourceVideo => 'YouTube';

  @override
  String get recipeSourceWeb => 'Web recipe';

  @override
  String get recipeImport => 'Import ingredients';

  @override
  String get recipeVideoNoImport => 'Videos have no ingredient list to import.';

  @override
  String get recipeRemoveTooltip => 'Remove recipe';

  @override
  String get recipeRemoveTitle => 'Remove this recipe?';

  @override
  String get recipeRemoveMessage =>
      'Ingredients already imported stay on the list.';

  @override
  String get planError => 'Could not load your plan';

  @override
  String get planEmptyTitle => 'Nothing planned yet';

  @override
  String get planEmptyMessage =>
      'Create a meal inside a shopping list, then give it a day here. Its ingredients come along with it.';

  @override
  String get planEmptyAction => 'Go to your lists';

  @override
  String get planUnplanned => 'Not yet planned';

  @override
  String get planToday => 'Today';

  @override
  String get planAddForDay => 'Plan a meal for this day';

  @override
  String get planNothing => 'Nothing planned';

  @override
  String planCookOnDay(String date) {
    return 'Cook on $date';
  }

  @override
  String get planPickMeal => 'Pick a meal that has no day yet.';

  @override
  String get planNoIngredients => 'No ingredients yet';

  @override
  String planBought(int checked, int total) {
    return '$checked of $total bought';
  }

  @override
  String get shopComposerHint => 'Remembered something?';

  @override
  String get shopListError => 'Could not load this list';

  @override
  String get shopListErrorDetail =>
      'The list is stored on this device, so this is usually temporary. Try again.';

  @override
  String get shopEmptyTitle => 'Nothing to buy yet';

  @override
  String get shopEmptyMessage =>
      'Add ingredients to your meals and they will show up here, grouped by aisle so you can shop straight down the list.';

  @override
  String get shopEmptyAction => 'Add ingredients';

  @override
  String get shopInBasket => 'In the basket';

  @override
  String get shopNoneYet => 'Nothing in the basket yet';

  @override
  String get shopAllAccountedFor => 'Every item accounted for';

  @override
  String shopStillToFind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count still to find',
      one: 'One to go — almost there',
    );
    return '$_temp0';
  }

  @override
  String shopPickedOf(int total) {
    return 'of $total picked up';
  }

  @override
  String get shopDoneTitle => 'Shopping done';

  @override
  String shopDoneMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count items are in the basket. Time to cook.',
      one: 'The one thing on your list is in the basket.',
    );
    return '$_temp0';
  }

  @override
  String progressPickedUp(int done, int total) {
    return '$done of $total picked up';
  }

  @override
  String get composerAdd => 'Add';

  @override
  String composerMergedAmount(String name, String amount) {
    return '$name is now $amount';
  }

  @override
  String composerMergedPlain(String name) {
    return 'Already on the list — $name';
  }

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authEnterEmail => 'Enter your email';

  @override
  String get authInvalidEmail => 'That does not look like an email';

  @override
  String get authEnterPassword => 'Enter your password';

  @override
  String get authChoosePassword => 'Choose a password';

  @override
  String authPasswordTooShort(int count) {
    return 'Use at least $count characters';
  }

  @override
  String get authPasswordsDiffer => 'Passwords do not match';

  @override
  String get authNetworkError =>
      'Could not reach the server. Check your connection.';

  @override
  String get authCheckInbox =>
      'Account created. Check your inbox to confirm your email, then sign in.';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to get to your shopping lists.';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginNoAccount => 'No account yet?';

  @override
  String get loginCreateOne => 'Create one';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle =>
      'So your lists are tied to you, not just this phone.';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerHaveAccount => 'Already have one?';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'Match phone';

  @override
  String get themeSystemSubtitle => 'Follows your phone';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Match phone';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSignedIn => 'Signed in';

  @override
  String get settingsDeviceOnly =>
      'Your lists are stored on this device only. Signing in does not sync them anywhere yet, so another phone will show an empty app.';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSignOutMessage =>
      'You will need to sign in again to get back in.';

  @override
  String settingsSignOutMessageEmail(String email) {
    return 'You are signed in as $email. You will need to sign in again to get back in.';
  }

  @override
  String get settingsAbout => 'About';

  @override
  String get categoryProduce => 'Produce';

  @override
  String get categoryBakery => 'Bakery';

  @override
  String get categoryMeatAndFish => 'Meat & fish';

  @override
  String get categoryDairyAndEggs => 'Dairy & eggs';

  @override
  String get categoryFrozen => 'Frozen';

  @override
  String get categoryPantry => 'Pantry';

  @override
  String get categoryDrinks => 'Drinks';

  @override
  String get categoryHousehold => 'Household';

  @override
  String get categoryOther => 'Other';

  @override
  String get recipeSearchTitle => 'Find a recipe';

  @override
  String get recipeSearchHint => 'Search YouTube & the web';

  @override
  String get recipeAttachManual => 'Attach a link manually';

  @override
  String get recipeAttachTitle => 'Attach a link';

  @override
  String get recipeAttachTitleField => 'Title';

  @override
  String get recipeAttachUrlField => 'YouTube or recipe URL';

  @override
  String get recipeAttachSubmit => 'Attach';

  @override
  String get recipeNoResultsTitle => 'No live results';

  @override
  String get recipeNoResultsMessage =>
      'This usually means the search API keys have not been set on the backend yet. You can still paste a link yourself.';

  @override
  String get recipeNoResultsAction => 'Attach a link instead';

  @override
  String get recipeViewOpenExternally => 'Open externally';

  @override
  String get recipeViewBadLink =>
      'Could not parse this YouTube link. Use \"Open externally\".';

  @override
  String cookWith(String name) {
    return 'Cook with $name';
  }

  @override
  String get cookFromYouTube => 'From YouTube';

  @override
  String get cookOpenYouTube => 'Open in YouTube';

  @override
  String cookOpenYouTubeSubtitle(String query) {
    return 'Searches YouTube for \"$query recipe\" — the full result list, not just the ten above.';
  }

  @override
  String cookSearchQuery(String name) {
    return '$name recipe';
  }

  @override
  String get cookNoResults =>
      'No in-app results yet. These appear once a YouTube API key is set on the backend — until then, use the buttons above.';

  @override
  String get cookSearchAgain => 'Search again';

  @override
  String get cookAttachToMeal => 'Attach to meal';

  @override
  String cookAttachToNamed(String name) {
    return 'Attach to $name';
  }

  @override
  String cookAttached(String name) {
    return 'Attached to $name.';
  }

  @override
  String get cookAttachedFallback => 'the meal';

  @override
  String get cookOpenFailed => 'Could not open that link.';

  @override
  String get itemSetPrice => 'Set price';

  @override
  String get itemClearPrice => 'Clear price';

  @override
  String itemPriceTitle(String name) {
    return 'Price of $name';
  }

  @override
  String get itemPriceHint => 'e.g. 2.40';

  @override
  String priceSoFar(String total) {
    return '$total so far';
  }

  @override
  String priceInBasket(String total) {
    return '$total in the basket';
  }

  @override
  String priceUnpriced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items have no price',
      one: '1 item has no price',
    );
    return '$_temp0';
  }

  @override
  String get itemMoveToAisle => 'Move to another aisle';

  @override
  String get itemAisleAuto => 'Sort it automatically';

  @override
  String get itemAisleAutoSubtitle => 'Guess the aisle from the name';

  @override
  String itemAisleTitle(String name) {
    return 'Aisle for $name';
  }

  @override
  String get settingsAisleOrder => 'Aisle order';

  @override
  String get settingsAisleOrderNote =>
      'Drag to match the shop you actually walk. Shopping mode follows this order.';

  @override
  String get settingsAisleOrderReset => 'Reset to default';

  @override
  String get shareList => 'Share list';

  @override
  String shareListSubject(String name) {
    return 'Shopping list: $name';
  }

  @override
  String get shareNothing => 'Nothing to share yet.';

  @override
  String get staplesTitle => 'Staples';

  @override
  String get itemMarkStaple => 'Mark as a staple';

  @override
  String get itemUnmarkStaple => 'Not a staple';

  @override
  String get staplesRestock => 'Restock staples';

  @override
  String get staplesNone =>
      'No staples yet. Mark something you buy every week and it will be offered here.';

  @override
  String staplesAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count staples',
      one: 'Added 1 staple',
    );
    return '$_temp0';
  }

  @override
  String get staplesAllPresent => 'Every staple is already on the list.';

  @override
  String get navRecipes => 'Recipes';

  @override
  String get libraryEmptyTitle => 'No saved recipes yet';

  @override
  String get libraryEmptyMessage =>
      'Recipes you put on a meal or save from a search collect here — and stay here when the meal is done.';

  @override
  String libraryUsedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'On $count meals',
      one: 'On 1 meal',
      zero: 'Not on any meal',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToMeal => 'Add to a meal';

  @override
  String get libraryPickMeal => 'Which meal?';

  @override
  String get libraryNoMeals => 'Create a meal in one of your lists first.';

  @override
  String libraryAdded(String meal) {
    return 'Added to $meal';
  }

  @override
  String get libraryDeleteForGood => 'Delete for good';

  @override
  String get libraryDeleteTitle => 'Delete this recipe for good?';

  @override
  String get libraryDeleteMessage =>
      'It is also taken off every meal that uses it. Ingredients already imported stay on your lists.';

  @override
  String get libraryDeleted => 'Recipe deleted';

  @override
  String get libraryAddLink => 'Save a link';

  @override
  String get libraryLinkTitle => 'Title (optional)';

  @override
  String get libraryLinkUrl => 'Recipe or YouTube link';

  @override
  String get libraryLinkInvalid => 'That does not look like a web link.';

  @override
  String get librarySave => 'Save to recipes';

  @override
  String get librarySaved => 'Saved to your recipes';

  @override
  String get mealFromLibrary => 'From your recipes';

  @override
  String get mealFromLibraryNone =>
      'No saved recipes to add — every one is already on this meal, or there are none yet.';

  @override
  String get recipeDetachTitle => 'Take this recipe off the meal?';

  @override
  String get recipeDetachMessage =>
      'It stays in your recipes, and ingredients already imported stay on the list.';

  @override
  String get recipeDetached => 'Taken off this meal';

  @override
  String get importReading => 'Reading the recipe…';

  @override
  String get importNoneFound => 'No ingredients found.';

  @override
  String get importPageUnreadable => 'That page could not be read.';

  @override
  String get importUnreachable =>
      'Could not reach the importer. Check your connection.';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count ingredients.',
      one: 'Added 1 ingredient.',
    );
    return '$_temp0';
  }

  @override
  String get importTitleDefault => 'Ingredients';

  @override
  String get importPick => 'Pick what to add to this meal.';

  @override
  String get importSelectAll => 'Select all';

  @override
  String get importClearAll => 'Clear all';

  @override
  String importAddCount(int count) {
    return 'Add $count';
  }

  @override
  String get cookModeStart => 'Cook';

  @override
  String get cookModeIngredients => 'Ingredients';

  @override
  String cookModeStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get cookModeGetReady => 'Get everything ready';

  @override
  String cookModeServings(String servings) {
    return 'Serves $servings';
  }

  @override
  String cookModeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get cookModeNext => 'Next';

  @override
  String get cookModeBack => 'Back';

  @override
  String get cookModeStartCooking => 'Start cooking';

  @override
  String get cookModeDone => 'Done';

  @override
  String cookModeTimerStart(String label) {
    return '$label timer';
  }

  @override
  String cookModeTimerUp(String label) {
    return 'Time\'s up · $label';
  }

  @override
  String get cookModeTimerStop => 'Stop timer';

  @override
  String get cookModeNoSteps =>
      'This page doesn\'t list its method in a form the app can read. The ingredients are here; open the page for the steps.';

  @override
  String get cookModeUnavailableTitle => 'Couldn\'t read this recipe';

  @override
  String get cookModeUnavailableMessage =>
      'Cooking mode needs the page\'s recipe data, and this page didn\'t provide it. You can still open the page itself.';

  @override
  String get cookModeOpenPage => 'Open the page';

  @override
  String get cookModeLeaveTitle => 'Stop cooking?';

  @override
  String get cookModeLeaveMessage => 'Your running timers will stop.';

  @override
  String get cookModeLeaveConfirm => 'Stop';

  @override
  String get cookModeOfflineTitle => 'No connection';

  @override
  String get cookModeOfflineMessage =>
      'This recipe hasn\'t been opened on this phone yet, so it needs the internet once. After that it works offline.';

  @override
  String get cookModeRetry => 'Try again';
}
