import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bg.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bg'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ShopCook'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Shop for the week, cook what you planned.'**
  String get appTagline;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @navLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navLists;

  /// No description provided for @navPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get navPlan;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @listsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your lists'**
  String get listsLoadError;

  /// No description provided for @listsLoadErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Your lists are stored on this device, so this is usually temporary.'**
  String get listsLoadErrorDetail;

  /// No description provided for @listsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shopping lists yet'**
  String get listsEmptyTitle;

  /// No description provided for @listsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'A list holds the meals you are cooking and everything you need to buy for them.'**
  String get listsEmptyMessage;

  /// No description provided for @listsEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Create a list'**
  String get listsEmptyAction;

  /// No description provided for @listsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New shopping list'**
  String get listsNewTitle;

  /// No description provided for @listsNewHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Weekly groceries'**
  String get listsNewHint;

  /// No description provided for @listsRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get listsRenameTitle;

  /// No description provided for @listsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String listsDeleteTitle(String name);

  /// No description provided for @listsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This also removes its meals, items and recipes. You can undo it straight afterwards.'**
  String get listsDeleteMessage;

  /// No description provided for @listsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String listsDeleted(String name);

  /// No description provided for @listCardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty — open it to add meals and items.'**
  String get listCardEmpty;

  /// No description provided for @listCardAllPicked.
  ///
  /// In en, this message translates to:
  /// **'Everything picked up'**
  String get listCardAllPicked;

  /// No description provided for @listCardLeftToBuy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left to buy} other{{count} left to buy}}'**
  String listCardLeftToBuy(int count);

  /// No description provided for @listDetailShoppingMode.
  ///
  /// In en, this message translates to:
  /// **'Shopping mode'**
  String get listDetailShoppingMode;

  /// No description provided for @listDetailMealsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the meals'**
  String get listDetailMealsError;

  /// No description provided for @listDetailOtherItems.
  ///
  /// In en, this message translates to:
  /// **'Other items'**
  String get listDetailOtherItems;

  /// No description provided for @listDetailItemsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the items'**
  String get listDetailItemsError;

  /// No description provided for @listDetailUnassignedNote.
  ///
  /// In en, this message translates to:
  /// **'Anything you add without picking a meal lands here — the milk and the washing-up liquid.'**
  String get listDetailUnassignedNote;

  /// No description provided for @listDetailComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item — try \"2 kg potatoes\"'**
  String get listDetailComposerHint;

  /// No description provided for @mealNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New meal'**
  String get mealNewTitle;

  /// No description provided for @mealNewHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spaghetti Bolognese'**
  String get mealNewHint;

  /// No description provided for @mealRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename meal'**
  String get mealRenameTitle;

  /// No description provided for @mealDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete meal'**
  String get mealDelete;

  /// No description provided for @mealDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String mealDeleted(String name);

  /// No description provided for @mealActions.
  ///
  /// In en, this message translates to:
  /// **'Meal actions'**
  String get mealActions;

  /// No description provided for @mealCardNoIngredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients yet — open it to add some or find a recipe.'**
  String get mealCardNoIngredients;

  /// No description provided for @itemActions.
  ///
  /// In en, this message translates to:
  /// **'Item actions'**
  String get itemActions;

  /// No description provided for @itemFindRecipes.
  ///
  /// In en, this message translates to:
  /// **'Find recipes'**
  String get itemFindRecipes;

  /// No description provided for @itemFindRecipesFromList.
  ///
  /// In en, this message translates to:
  /// **'What can I cook with this?'**
  String get itemFindRecipesFromList;

  /// No description provided for @itemFindRecipesFromMeal.
  ///
  /// In en, this message translates to:
  /// **'What else can I cook with this?'**
  String get itemFindRecipesFromMeal;

  /// No description provided for @itemMoveToMeal.
  ///
  /// In en, this message translates to:
  /// **'Move to a meal'**
  String get itemMoveToMeal;

  /// No description provided for @itemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String itemRemoved(String name);

  /// No description provided for @itemMoveNeedsMeal.
  ///
  /// In en, this message translates to:
  /// **'Create a meal first, then move items into it.'**
  String get itemMoveNeedsMeal;

  /// No description provided for @itemMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Move \"{name}\" to'**
  String itemMoveTitle(String name);

  /// No description provided for @mealPlanDay.
  ///
  /// In en, this message translates to:
  /// **'Plan a day for this meal'**
  String get mealPlanDay;

  /// No description provided for @mealPlannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned for {date}'**
  String mealPlannedFor(String date);

  /// No description provided for @mealFindRecipe.
  ///
  /// In en, this message translates to:
  /// **'Find a recipe'**
  String get mealFindRecipe;

  /// No description provided for @mealIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get mealIngredients;

  /// No description provided for @mealIngredientsError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the ingredients'**
  String get mealIngredientsError;

  /// No description provided for @mealIngredientsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ingredients yet. Add them by hand, or find a recipe and import its list in one go.'**
  String get mealIngredientsEmpty;

  /// No description provided for @mealComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Add an ingredient'**
  String get mealComposerHint;

  /// No description provided for @mealRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get mealRecipe;

  /// No description provided for @mealRecipeError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the recipe'**
  String get mealRecipeError;

  /// No description provided for @mealRecipeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recipe attached yet. Find one and its ingredients can be imported straight onto this meal.'**
  String get mealRecipeEmpty;

  /// No description provided for @mealMoveDay.
  ///
  /// In en, this message translates to:
  /// **'Move to another day'**
  String get mealMoveDay;

  /// No description provided for @mealGiveDay.
  ///
  /// In en, this message translates to:
  /// **'Give it a day'**
  String get mealGiveDay;

  /// No description provided for @mealClearDay.
  ///
  /// In en, this message translates to:
  /// **'Take off the plan'**
  String get mealClearDay;

  /// No description provided for @mealCookOn.
  ///
  /// In en, this message translates to:
  /// **'Cook {name} on'**
  String mealCookOn(String name);

  /// No description provided for @recipeSourceVideo.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get recipeSourceVideo;

  /// No description provided for @recipeSourceWeb.
  ///
  /// In en, this message translates to:
  /// **'Web recipe'**
  String get recipeSourceWeb;

  /// No description provided for @recipeImport.
  ///
  /// In en, this message translates to:
  /// **'Import ingredients'**
  String get recipeImport;

  /// No description provided for @recipeVideoNoImport.
  ///
  /// In en, this message translates to:
  /// **'Videos have no ingredient list to import.'**
  String get recipeVideoNoImport;

  /// No description provided for @recipeRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove recipe'**
  String get recipeRemoveTooltip;

  /// No description provided for @recipeRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this recipe?'**
  String get recipeRemoveTitle;

  /// No description provided for @recipeRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'Ingredients already imported stay on the list.'**
  String get recipeRemoveMessage;

  /// No description provided for @planError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your plan'**
  String get planError;

  /// No description provided for @planEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned yet'**
  String get planEmptyTitle;

  /// No description provided for @planEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create a meal inside a shopping list, then give it a day here. Its ingredients come along with it.'**
  String get planEmptyMessage;

  /// No description provided for @planEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Go to your lists'**
  String get planEmptyAction;

  /// No description provided for @planUnplanned.
  ///
  /// In en, this message translates to:
  /// **'Not yet planned'**
  String get planUnplanned;

  /// No description provided for @planToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planToday;

  /// No description provided for @planAddForDay.
  ///
  /// In en, this message translates to:
  /// **'Plan a meal for this day'**
  String get planAddForDay;

  /// No description provided for @planNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get planNothing;

  /// No description provided for @planCookOnDay.
  ///
  /// In en, this message translates to:
  /// **'Cook on {date}'**
  String planCookOnDay(String date);

  /// No description provided for @planPickMeal.
  ///
  /// In en, this message translates to:
  /// **'Pick a meal that has no day yet.'**
  String get planPickMeal;

  /// No description provided for @planNoIngredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients yet'**
  String get planNoIngredients;

  /// No description provided for @planBought.
  ///
  /// In en, this message translates to:
  /// **'{checked} of {total} bought'**
  String planBought(int checked, int total);

  /// No description provided for @shopComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Remembered something?'**
  String get shopComposerHint;

  /// No description provided for @shopListError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this list'**
  String get shopListError;

  /// No description provided for @shopListErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'The list is stored on this device, so this is usually temporary. Try again.'**
  String get shopListErrorDetail;

  /// No description provided for @shopEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy yet'**
  String get shopEmptyTitle;

  /// No description provided for @shopEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add ingredients to your meals and they will show up here, grouped by aisle so you can shop straight down the list.'**
  String get shopEmptyMessage;

  /// No description provided for @shopEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Add ingredients'**
  String get shopEmptyAction;

  /// No description provided for @shopInBasket.
  ///
  /// In en, this message translates to:
  /// **'In the basket'**
  String get shopInBasket;

  /// No description provided for @shopNoneYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the basket yet'**
  String get shopNoneYet;

  /// No description provided for @shopAllAccountedFor.
  ///
  /// In en, this message translates to:
  /// **'Every item accounted for'**
  String get shopAllAccountedFor;

  /// No description provided for @shopStillToFind.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One to go — almost there} other{{count} still to find}}'**
  String shopStillToFind(int count);

  /// No description provided for @shopPickedOf.
  ///
  /// In en, this message translates to:
  /// **'of {total} picked up'**
  String shopPickedOf(int total);

  /// No description provided for @shopDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping done'**
  String get shopDoneTitle;

  /// No description provided for @shopDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The one thing on your list is in the basket.} other{All {count} items are in the basket. Time to cook.}}'**
  String shopDoneMessage(int count);

  /// No description provided for @progressPickedUp.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} picked up'**
  String progressPickedUp(int done, int total);

  /// No description provided for @composerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get composerAdd;

  /// No description provided for @composerMergedAmount.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {amount}'**
  String composerMergedAmount(String name, String amount);

  /// No description provided for @composerMergedPlain.
  ///
  /// In en, this message translates to:
  /// **'Already on the list — {name}'**
  String composerMergedPlain(String name);

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEnterEmail;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email'**
  String get authInvalidEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authEnterPassword;

  /// No description provided for @authChoosePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get authChoosePassword;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters'**
  String authPasswordTooShort(int count);

  /// No description provided for @authPasswordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDiffer;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection.'**
  String get authNetworkError;

  /// No description provided for @authCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your inbox to confirm your email, then sign in.'**
  String get authCheckInbox;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to get to your shopping lists.'**
  String get loginSubtitle;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmit;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get loginNoAccount;

  /// No description provided for @loginCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get loginCreateOne;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'So your lists are tied to you, not just this phone.'**
  String get registerSubtitle;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerSubmit;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have one?'**
  String get registerHaveAccount;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match phone'**
  String get themeSystem;

  /// No description provided for @themeSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows your phone'**
  String get themeSystemSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Match phone'**
  String get languageSystem;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsSignedIn;

  /// No description provided for @settingsDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Your lists are stored on this device only. Signing in does not sync them anywhere yet, so another phone will show an empty app.'**
  String get settingsDeviceOnly;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to get back in.'**
  String get settingsSignOutMessage;

  /// No description provided for @settingsSignOutMessageEmail.
  ///
  /// In en, this message translates to:
  /// **'You are signed in as {email}. You will need to sign in again to get back in.'**
  String settingsSignOutMessageEmail(String email);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @categoryProduce.
  ///
  /// In en, this message translates to:
  /// **'Produce'**
  String get categoryProduce;

  /// No description provided for @categoryBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get categoryBakery;

  /// No description provided for @categoryMeatAndFish.
  ///
  /// In en, this message translates to:
  /// **'Meat & fish'**
  String get categoryMeatAndFish;

  /// No description provided for @categoryDairyAndEggs.
  ///
  /// In en, this message translates to:
  /// **'Dairy & eggs'**
  String get categoryDairyAndEggs;

  /// No description provided for @categoryFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get categoryFrozen;

  /// No description provided for @categoryPantry.
  ///
  /// In en, this message translates to:
  /// **'Pantry'**
  String get categoryPantry;

  /// No description provided for @categoryDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get categoryDrinks;

  /// No description provided for @categoryHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get categoryHousehold;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @recipeSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a recipe'**
  String get recipeSearchTitle;

  /// No description provided for @recipeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube & the web'**
  String get recipeSearchHint;

  /// No description provided for @recipeAttachManual.
  ///
  /// In en, this message translates to:
  /// **'Attach a link manually'**
  String get recipeAttachManual;

  /// No description provided for @recipeAttachTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach a link'**
  String get recipeAttachTitle;

  /// No description provided for @recipeAttachTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get recipeAttachTitleField;

  /// No description provided for @recipeAttachUrlField.
  ///
  /// In en, this message translates to:
  /// **'YouTube or recipe URL'**
  String get recipeAttachUrlField;

  /// No description provided for @recipeAttachSubmit.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get recipeAttachSubmit;

  /// No description provided for @recipeNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No live results'**
  String get recipeNoResultsTitle;

  /// No description provided for @recipeNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'This usually means the search API keys have not been set on the backend yet. You can still paste a link yourself.'**
  String get recipeNoResultsMessage;

  /// No description provided for @recipeNoResultsAction.
  ///
  /// In en, this message translates to:
  /// **'Attach a link instead'**
  String get recipeNoResultsAction;

  /// No description provided for @recipeViewOpenExternally.
  ///
  /// In en, this message translates to:
  /// **'Open externally'**
  String get recipeViewOpenExternally;

  /// No description provided for @recipeViewBadLink.
  ///
  /// In en, this message translates to:
  /// **'Could not parse this YouTube link. Use \"Open externally\".'**
  String get recipeViewBadLink;

  /// No description provided for @cookWith.
  ///
  /// In en, this message translates to:
  /// **'Cook with {name}'**
  String cookWith(String name);

  /// No description provided for @cookFromYouTube.
  ///
  /// In en, this message translates to:
  /// **'From YouTube'**
  String get cookFromYouTube;

  /// No description provided for @cookOpenYouTube.
  ///
  /// In en, this message translates to:
  /// **'Open in YouTube'**
  String get cookOpenYouTube;

  /// No description provided for @cookOpenYouTubeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Searches YouTube for \"{query} recipe\" — the full result list, not just the ten above.'**
  String cookOpenYouTubeSubtitle(String query);

  /// No description provided for @cookSearchQuery.
  ///
  /// In en, this message translates to:
  /// **'{name} recipe'**
  String cookSearchQuery(String name);

  /// No description provided for @cookNoResults.
  ///
  /// In en, this message translates to:
  /// **'No in-app results yet. These appear once a YouTube API key is set on the backend — until then, use the buttons above.'**
  String get cookNoResults;

  /// No description provided for @cookSearchAgain.
  ///
  /// In en, this message translates to:
  /// **'Search again'**
  String get cookSearchAgain;

  /// No description provided for @cookAttachToMeal.
  ///
  /// In en, this message translates to:
  /// **'Attach to meal'**
  String get cookAttachToMeal;

  /// No description provided for @cookAttachToNamed.
  ///
  /// In en, this message translates to:
  /// **'Attach to {name}'**
  String cookAttachToNamed(String name);

  /// No description provided for @cookAttached.
  ///
  /// In en, this message translates to:
  /// **'Attached to {name}.'**
  String cookAttached(String name);

  /// No description provided for @cookAttachedFallback.
  ///
  /// In en, this message translates to:
  /// **'the meal'**
  String get cookAttachedFallback;

  /// No description provided for @cookOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that link.'**
  String get cookOpenFailed;

  /// No description provided for @itemSetPrice.
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get itemSetPrice;

  /// No description provided for @itemClearPrice.
  ///
  /// In en, this message translates to:
  /// **'Clear price'**
  String get itemClearPrice;

  /// No description provided for @itemPriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Price of {name}'**
  String itemPriceTitle(String name);

  /// No description provided for @itemPriceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2.40'**
  String get itemPriceHint;

  /// No description provided for @priceSoFar.
  ///
  /// In en, this message translates to:
  /// **'{total} so far'**
  String priceSoFar(String total);

  /// No description provided for @priceInBasket.
  ///
  /// In en, this message translates to:
  /// **'{total} in the basket'**
  String priceInBasket(String total);

  /// No description provided for @priceUnpriced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item has no price} other{{count} items have no price}}'**
  String priceUnpriced(int count);

  /// No description provided for @itemMoveToAisle.
  ///
  /// In en, this message translates to:
  /// **'Move to another aisle'**
  String get itemMoveToAisle;

  /// No description provided for @itemAisleAuto.
  ///
  /// In en, this message translates to:
  /// **'Sort it automatically'**
  String get itemAisleAuto;

  /// No description provided for @itemAisleAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Guess the aisle from the name'**
  String get itemAisleAutoSubtitle;

  /// No description provided for @itemAisleTitle.
  ///
  /// In en, this message translates to:
  /// **'Aisle for {name}'**
  String itemAisleTitle(String name);

  /// No description provided for @settingsAisleOrder.
  ///
  /// In en, this message translates to:
  /// **'Aisle order'**
  String get settingsAisleOrder;

  /// No description provided for @settingsAisleOrderNote.
  ///
  /// In en, this message translates to:
  /// **'Drag to match the shop you actually walk. Shopping mode follows this order.'**
  String get settingsAisleOrderNote;

  /// No description provided for @settingsAisleOrderReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get settingsAisleOrderReset;

  /// No description provided for @shareList.
  ///
  /// In en, this message translates to:
  /// **'Share list'**
  String get shareList;

  /// No description provided for @shareListSubject.
  ///
  /// In en, this message translates to:
  /// **'Shopping list: {name}'**
  String shareListSubject(String name);

  /// No description provided for @shareNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to share yet.'**
  String get shareNothing;

  /// No description provided for @staplesTitle.
  ///
  /// In en, this message translates to:
  /// **'Staples'**
  String get staplesTitle;

  /// No description provided for @itemMarkStaple.
  ///
  /// In en, this message translates to:
  /// **'Mark as a staple'**
  String get itemMarkStaple;

  /// No description provided for @itemUnmarkStaple.
  ///
  /// In en, this message translates to:
  /// **'Not a staple'**
  String get itemUnmarkStaple;

  /// No description provided for @staplesRestock.
  ///
  /// In en, this message translates to:
  /// **'Restock staples'**
  String get staplesRestock;

  /// No description provided for @staplesNone.
  ///
  /// In en, this message translates to:
  /// **'No staples yet. Mark something you buy every week and it will be offered here.'**
  String get staplesNone;

  /// No description provided for @staplesAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 staple} other{Added {count} staples}}'**
  String staplesAdded(int count);

  /// No description provided for @staplesAllPresent.
  ///
  /// In en, this message translates to:
  /// **'Every staple is already on the list.'**
  String get staplesAllPresent;

  /// No description provided for @navRecipes.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get navRecipes;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved recipes yet'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Recipes you put on a meal or save from a search collect here — and stay here when the meal is done.'**
  String get libraryEmptyMessage;

  /// No description provided for @libraryUsedIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not on any meal} =1{On 1 meal} other{On {count} meals}}'**
  String libraryUsedIn(int count);

  /// No description provided for @libraryAddToMeal.
  ///
  /// In en, this message translates to:
  /// **'Add to a meal'**
  String get libraryAddToMeal;

  /// No description provided for @libraryPickMeal.
  ///
  /// In en, this message translates to:
  /// **'Which meal?'**
  String get libraryPickMeal;

  /// No description provided for @libraryNoMeals.
  ///
  /// In en, this message translates to:
  /// **'Create a meal in one of your lists first.'**
  String get libraryNoMeals;

  /// No description provided for @libraryAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to {meal}'**
  String libraryAdded(String meal);

  /// No description provided for @libraryDeleteForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get libraryDeleteForGood;

  /// No description provided for @libraryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recipe for good?'**
  String get libraryDeleteTitle;

  /// No description provided for @libraryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'It is also taken off every meal that uses it. Ingredients already imported stay on your lists.'**
  String get libraryDeleteMessage;

  /// No description provided for @libraryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recipe deleted'**
  String get libraryDeleted;

  /// No description provided for @libraryAddLink.
  ///
  /// In en, this message translates to:
  /// **'Save a link'**
  String get libraryAddLink;

  /// No description provided for @libraryLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get libraryLinkTitle;

  /// No description provided for @libraryLinkUrl.
  ///
  /// In en, this message translates to:
  /// **'Recipe or YouTube link'**
  String get libraryLinkUrl;

  /// No description provided for @libraryLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like a web link.'**
  String get libraryLinkInvalid;

  /// No description provided for @librarySave.
  ///
  /// In en, this message translates to:
  /// **'Save to recipes'**
  String get librarySave;

  /// No description provided for @librarySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your recipes'**
  String get librarySaved;

  /// No description provided for @mealFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'From your recipes'**
  String get mealFromLibrary;

  /// No description provided for @mealFromLibraryNone.
  ///
  /// In en, this message translates to:
  /// **'No saved recipes to add — every one is already on this meal, or there are none yet.'**
  String get mealFromLibraryNone;

  /// No description provided for @recipeDetachTitle.
  ///
  /// In en, this message translates to:
  /// **'Take this recipe off the meal?'**
  String get recipeDetachTitle;

  /// No description provided for @recipeDetachMessage.
  ///
  /// In en, this message translates to:
  /// **'It stays in your recipes, and ingredients already imported stay on the list.'**
  String get recipeDetachMessage;

  /// No description provided for @recipeDetached.
  ///
  /// In en, this message translates to:
  /// **'Taken off this meal'**
  String get recipeDetached;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the recipe…'**
  String get importReading;

  /// No description provided for @importNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No ingredients found.'**
  String get importNoneFound;

  /// No description provided for @importPageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That page could not be read.'**
  String get importPageUnreadable;

  /// No description provided for @importUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the importer. Check your connection.'**
  String get importUnreachable;

  /// No description provided for @importAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 ingredient.} other{Added {count} ingredients.}}'**
  String importAdded(int count);

  /// No description provided for @importTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get importTitleDefault;

  /// No description provided for @importPick.
  ///
  /// In en, this message translates to:
  /// **'Pick what to add to this meal.'**
  String get importPick;

  /// No description provided for @importSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get importSelectAll;

  /// No description provided for @importClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get importClearAll;

  /// No description provided for @importAddCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String importAddCount(int count);

  /// No description provided for @cookModeStart.
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get cookModeStart;

  /// No description provided for @cookModeIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get cookModeIngredients;

  /// No description provided for @cookModeStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String cookModeStepOf(int current, int total);

  /// No description provided for @cookModeGetReady.
  ///
  /// In en, this message translates to:
  /// **'Get everything ready'**
  String get cookModeGetReady;

  /// No description provided for @cookModeServings.
  ///
  /// In en, this message translates to:
  /// **'Serves {servings}'**
  String cookModeServings(String servings);

  /// No description provided for @cookModeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String cookModeMinutes(int minutes);

  /// No description provided for @cookModeNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get cookModeNext;

  /// No description provided for @cookModeBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get cookModeBack;

  /// No description provided for @cookModeStartCooking.
  ///
  /// In en, this message translates to:
  /// **'Start cooking'**
  String get cookModeStartCooking;

  /// No description provided for @cookModeDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get cookModeDone;

  /// No description provided for @cookModeTimerStart.
  ///
  /// In en, this message translates to:
  /// **'{label} timer'**
  String cookModeTimerStart(String label);

  /// No description provided for @cookModeTimerUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up · {label}'**
  String cookModeTimerUp(String label);

  /// No description provided for @cookModeTimerStop.
  ///
  /// In en, this message translates to:
  /// **'Stop timer'**
  String get cookModeTimerStop;

  /// No description provided for @cookModeNoSteps.
  ///
  /// In en, this message translates to:
  /// **'This page doesn\'t list its method in a form the app can read. The ingredients are here; open the page for the steps.'**
  String get cookModeNoSteps;

  /// No description provided for @cookModeUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this recipe'**
  String get cookModeUnavailableTitle;

  /// No description provided for @cookModeUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Cooking mode needs the page\'s recipe data, and this page didn\'t provide it. You can still open the page itself.'**
  String get cookModeUnavailableMessage;

  /// No description provided for @cookModeOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open the page'**
  String get cookModeOpenPage;

  /// No description provided for @cookModeLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop cooking?'**
  String get cookModeLeaveTitle;

  /// No description provided for @cookModeLeaveMessage.
  ///
  /// In en, this message translates to:
  /// **'Your running timers will stop.'**
  String get cookModeLeaveMessage;

  /// No description provided for @cookModeLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get cookModeLeaveConfirm;

  /// No description provided for @cookModeOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get cookModeOfflineTitle;

  /// No description provided for @cookModeOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'This recipe hasn\'t been opened on this phone yet, so it needs the internet once. After that it works offline.'**
  String get cookModeOfflineMessage;

  /// No description provided for @shareAddItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 item to…} other{Add {count} items to…}}'**
  String shareAddItemsTitle(int count);

  /// No description provided for @shareItemsAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 item to {list}} other{Added {count} items to {list}}}'**
  String shareItemsAdded(int count, String list);

  /// No description provided for @shareOpenList.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get shareOpenList;

  /// No description provided for @shareNoLists.
  ///
  /// In en, this message translates to:
  /// **'Create a list first, then share to ShopCook again.'**
  String get shareNoLists;

  /// No description provided for @shareNothingUsable.
  ///
  /// In en, this message translates to:
  /// **'There was nothing in that share ShopCook could use.'**
  String get shareNothingUsable;

  /// No description provided for @scanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode'**
  String get scanTooltip;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a product'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the barcode on the pack.'**
  String get scanHint;

  /// No description provided for @scanTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get scanTorch;

  /// No description provided for @scanNoPermission.
  ///
  /// In en, this message translates to:
  /// **'ShopCook needs the camera to scan. Allow it in the phone’s settings for ShopCook.'**
  String get scanNoPermission;

  /// No description provided for @scanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started.'**
  String get scanUnavailable;

  /// No description provided for @scanUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown product. Type its name and it will be remembered for next time.'**
  String get scanUnknown;

  /// No description provided for @voiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add by voice'**
  String get voiceTooltip;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Say what you need'**
  String get voiceTitle;

  /// No description provided for @voiceHint.
  ///
  /// In en, this message translates to:
  /// **'For example: “milk, two kilos of potatoes and eggs”. Tap the microphone when you’re done.'**
  String get voiceHint;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition isn’t available. Check that ShopCook may use the microphone and that the phone has a voice input service.'**
  String get voiceUnavailable;

  /// No description provided for @voiceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add these?'**
  String get voiceConfirmTitle;

  /// No description provided for @voiceAddCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 item} other{Add {count} items}}'**
  String voiceAddCount(int count);

  /// No description provided for @voiceAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 item} other{Added {count} items}}'**
  String voiceAdded(int count);

  /// No description provided for @widgetSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All bought} =1{1 left to buy} other{{count} left to buy}}'**
  String widgetSummary(int count);

  /// No description provided for @widgetMore.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String widgetMore(int count);

  /// No description provided for @widgetNoLists.
  ///
  /// In en, this message translates to:
  /// **'No lists yet. Tap to create one.'**
  String get widgetNoLists;

  /// No description provided for @widgetAllDone.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to buy. Tap to open the list.'**
  String get widgetAllDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bg', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bg':
      return AppLocalizationsBg();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
