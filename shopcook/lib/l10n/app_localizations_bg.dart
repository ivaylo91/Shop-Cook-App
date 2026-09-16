// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'ShopCook';

  @override
  String get appTagline => 'Пазарувай за седмицата, готви каквото си планирал.';

  @override
  String get actionCancel => 'Отказ';

  @override
  String get actionSave => 'Запази';

  @override
  String get actionCreate => 'Създай';

  @override
  String get actionDelete => 'Изтрий';

  @override
  String get actionRemove => 'Премахни';

  @override
  String get actionAdd => 'Добави';

  @override
  String get actionRename => 'Преименувай';

  @override
  String get actionUndo => 'Върни';

  @override
  String get actionConfirm => 'Потвърди';

  @override
  String get actionTryAgain => 'Опитай отново';

  @override
  String get errorGeneric => 'Нещо се обърка';

  @override
  String get navLists => 'Списъци';

  @override
  String get navPlan => 'План';

  @override
  String get navSettings => 'Настройки';

  @override
  String get listsLoadError => 'Списъците не се заредиха';

  @override
  String get listsLoadErrorDetail =>
      'Списъците се пазят на това устройство, така че това обикновено е временно.';

  @override
  String get listsEmptyTitle => 'Още няма списъци';

  @override
  String get listsEmptyMessage =>
      'Списъкът събира ястията, които ще готвиш, и всичко, което трябва да купиш за тях.';

  @override
  String get listsEmptyAction => 'Създай списък';

  @override
  String get listsNewTitle => 'Нов списък';

  @override
  String get listsNewHint => 'напр. Седмично пазаруване';

  @override
  String get listsRenameTitle => 'Преименувай списъка';

  @override
  String listsDeleteTitle(String name) {
    return 'Да изтрия ли „$name“?';
  }

  @override
  String get listsDeleteMessage =>
      'Това ще премахне и ястията, продуктите и рецептите в него. Можеш да върнеш действието веднага след това.';

  @override
  String listsDeleted(String name) {
    return '„$name“ е изтрит';
  }

  @override
  String get listCardEmpty =>
      'Празен — отвори го, за да добавиш ястия и продукти.';

  @override
  String get listCardAllPicked => 'Всичко е взето';

  @override
  String listCardLeftToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Остават $count за купуване',
      one: 'Остава 1 за купуване',
    );
    return '$_temp0';
  }

  @override
  String get listDetailShoppingMode => 'Режим пазаруване';

  @override
  String get listDetailMealsError => 'Ястията не се заредиха';

  @override
  String get listDetailOtherItems => 'Други продукти';

  @override
  String get listDetailItemsError => 'Продуктите не се заредиха';

  @override
  String get listDetailUnassignedNote =>
      'Всичко, което добавиш без да избереш ястие, идва тук — млякото и препаратът за чинии.';

  @override
  String get listDetailComposerHint => 'Добави — напр. „2 кг картофи“';

  @override
  String get mealNewTitle => 'Ново ястие';

  @override
  String get mealNewHint => 'напр. Спагети болонезе';

  @override
  String get mealRenameTitle => 'Преименувай ястието';

  @override
  String get mealDelete => 'Изтрий ястието';

  @override
  String mealDeleted(String name) {
    return '„$name“ е изтрито';
  }

  @override
  String get mealActions => 'Действия с ястието';

  @override
  String get mealCardNoIngredients =>
      'Още няма съставки — отвори го, за да добавиш или да намериш рецепта.';

  @override
  String get itemActions => 'Действия с продукта';

  @override
  String get itemFindRecipes => 'Намери рецепти';

  @override
  String get itemFindRecipesFromList => 'Какво да сготвя с това?';

  @override
  String get itemFindRecipesFromMeal => 'Какво друго да сготвя с това?';

  @override
  String get itemMoveToMeal => 'Премести в ястие';

  @override
  String itemRemoved(String name) {
    return '$name е премахнат';
  }

  @override
  String get itemMoveNeedsMeal =>
      'Първо създай ястие, после премести продукти в него.';

  @override
  String itemMoveTitle(String name) {
    return 'Премести „$name“ в';
  }

  @override
  String get mealPlanDay => 'Планирай ден за това ястие';

  @override
  String mealPlannedFor(String date) {
    return 'Планирано за $date';
  }

  @override
  String get mealFindRecipe => 'Намери рецепта';

  @override
  String get mealIngredients => 'Съставки';

  @override
  String get mealIngredientsError => 'Съставките не се заредиха';

  @override
  String get mealIngredientsEmpty =>
      'Още няма съставки. Добави ги на ръка или намери рецепта и внеси списъка ѝ наведнъж.';

  @override
  String get mealComposerHint => 'Добави съставка';

  @override
  String get mealRecipe => 'Рецепта';

  @override
  String get mealRecipeError => 'Рецептата не се зареди';

  @override
  String get mealRecipeEmpty =>
      'Още няма прикачена рецепта. Намери една и съставките ѝ ще се внесат направо в ястието.';

  @override
  String get mealMoveDay => 'Премести на друг ден';

  @override
  String get mealGiveDay => 'Определи ден';

  @override
  String get mealClearDay => 'Извади от плана';

  @override
  String mealCookOn(String name) {
    return 'Готвене на $name на';
  }

  @override
  String get recipeSourceVideo => 'YouTube';

  @override
  String get recipeSourceWeb => 'Рецепта от сайт';

  @override
  String get recipeImport => 'Внеси съставките';

  @override
  String get recipeVideoNoImport =>
      'Видеата нямат списък със съставки за внасяне.';

  @override
  String get recipeRemoveTooltip => 'Премахни рецептата';

  @override
  String get recipeRemoveTitle => 'Да премахна ли рецептата?';

  @override
  String get recipeRemoveMessage =>
      'Вече внесените съставки остават в списъка.';

  @override
  String get planError => 'Планът не се зареди';

  @override
  String get planEmptyTitle => 'Още няма нищо планирано';

  @override
  String get planEmptyMessage =>
      'Създай ястие в някой списък, после му определи ден тук. Съставките му идват с него.';

  @override
  String get planEmptyAction => 'Към списъците';

  @override
  String get planUnplanned => 'Още непланирани';

  @override
  String get planToday => 'Днес';

  @override
  String get planAddForDay => 'Планирай ястие за този ден';

  @override
  String get planNothing => 'Няма планирано';

  @override
  String planCookOnDay(String date) {
    return 'Готвене на $date';
  }

  @override
  String get planPickMeal => 'Избери ястие, което още няма ден.';

  @override
  String get planNoIngredients => 'Още няма съставки';

  @override
  String planBought(int checked, int total) {
    return '$checked от $total купени';
  }

  @override
  String get shopComposerHint => 'Сети ли се за нещо?';

  @override
  String get shopListError => 'Списъкът не се зареди';

  @override
  String get shopListErrorDetail =>
      'Списъкът се пази на това устройство, така че това обикновено е временно. Опитай отново.';

  @override
  String get shopEmptyTitle => 'Още няма нищо за купуване';

  @override
  String get shopEmptyMessage =>
      'Добави съставки към ястията си и ще се появят тук, подредени по щандове, за да пазаруваш направо отгоре надолу.';

  @override
  String get shopEmptyAction => 'Добави съставки';

  @override
  String get shopInBasket => 'В кошницата';

  @override
  String get shopNoneYet => 'Още нищо в кошницата';

  @override
  String get shopAllAccountedFor => 'Всичко е налице';

  @override
  String shopStillToFind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Още $count за намиране',
      one: 'Остава още едно — почти готово',
    );
    return '$_temp0';
  }

  @override
  String shopPickedOf(int total) {
    return 'от $total взети';
  }

  @override
  String get shopDoneTitle => 'Пазаруването е готово';

  @override
  String shopDoneMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Всички $count продукта са в кошницата. Време е за готвене.',
      one: 'Единственото нещо от списъка е в кошницата.',
    );
    return '$_temp0';
  }

  @override
  String progressPickedUp(int done, int total) {
    return '$done от $total взети';
  }

  @override
  String get composerAdd => 'Добави';

  @override
  String composerMergedAmount(String name, String amount) {
    return '$name вече е $amount';
  }

  @override
  String composerMergedPlain(String name) {
    return 'Вече е в списъка — $name';
  }

  @override
  String get authEmail => 'Имейл';

  @override
  String get authPassword => 'Парола';

  @override
  String get authConfirmPassword => 'Потвърди паролата';

  @override
  String get authShowPassword => 'Покажи паролата';

  @override
  String get authHidePassword => 'Скрий паролата';

  @override
  String get authEnterEmail => 'Въведи имейла си';

  @override
  String get authInvalidEmail => 'Това не изглежда като имейл';

  @override
  String get authEnterPassword => 'Въведи паролата си';

  @override
  String get authChoosePassword => 'Избери парола';

  @override
  String authPasswordTooShort(int count) {
    return 'Използвай поне $count знака';
  }

  @override
  String get authPasswordsDiffer => 'Паролите не съвпадат';

  @override
  String get authNetworkError => 'Сървърът е недостъпен. Провери връзката си.';

  @override
  String get authCheckInbox =>
      'Профилът е създаден. Провери пощата си, за да потвърдиш имейла, после влез.';

  @override
  String get loginTitle => 'Добре дошъл отново';

  @override
  String get loginSubtitle => 'Влез, за да стигнеш до списъците си.';

  @override
  String get loginSubmit => 'Вход';

  @override
  String get loginNoAccount => 'Още нямаш профил?';

  @override
  String get loginCreateOne => 'Създай';

  @override
  String get registerTitle => 'Създай профил';

  @override
  String get registerSubtitle =>
      'За да са списъците свързани с теб, а не само с този телефон.';

  @override
  String get registerSubmit => 'Създай профил';

  @override
  String get registerHaveAccount => 'Вече имаш профил?';

  @override
  String get settingsAppearance => 'Изглед';

  @override
  String get themeSystem => 'Като телефона';

  @override
  String get themeSystemSubtitle => 'Следва телефона';

  @override
  String get themeLight => 'Светла';

  @override
  String get themeDark => 'Тъмна';

  @override
  String get settingsLanguage => 'Език';

  @override
  String get languageSystem => 'Като телефона';

  @override
  String get settingsAccount => 'Профил';

  @override
  String get settingsSignedIn => 'Влязъл';

  @override
  String get settingsDeviceOnly =>
      'Списъците се пазят само на това устройство. Влизането още не ги синхронизира никъде, така че на друг телефон приложението ще е празно.';

  @override
  String get settingsSignOut => 'Изход';

  @override
  String get settingsSignOutTitle => 'Да излезеш ли?';

  @override
  String get settingsSignOutMessage => 'Ще трябва да влезеш отново.';

  @override
  String settingsSignOutMessageEmail(String email) {
    return 'Влязъл си като $email. Ще трябва да влезеш отново.';
  }

  @override
  String get settingsAbout => 'Относно';

  @override
  String get categoryProduce => 'Плодове и зеленчуци';

  @override
  String get categoryBakery => 'Хляб и печива';

  @override
  String get categoryMeatAndFish => 'Месо и риба';

  @override
  String get categoryDairyAndEggs => 'Млечни и яйца';

  @override
  String get categoryFrozen => 'Замразени';

  @override
  String get categoryPantry => 'Бакалия';

  @override
  String get categoryDrinks => 'Напитки';

  @override
  String get categoryHousehold => 'Домакински';

  @override
  String get categoryOther => 'Други';

  @override
  String get recipeSearchTitle => 'Намери рецепта';

  @override
  String get recipeSearchHint => 'Търси в YouTube и мрежата';

  @override
  String get recipeAttachManual => 'Прикачи линк на ръка';

  @override
  String get recipeAttachTitle => 'Прикачи линк';

  @override
  String get recipeAttachTitleField => 'Заглавие';

  @override
  String get recipeAttachUrlField => 'YouTube или адрес на рецепта';

  @override
  String get recipeAttachSubmit => 'Прикачи';

  @override
  String get recipeNoResultsTitle => 'Няма резултати';

  @override
  String get recipeNoResultsMessage =>
      'Обикновено това значи, че ключовете за търсене още не са зададени на сървъра. Все пак можеш да поставиш линк сам.';

  @override
  String get recipeNoResultsAction => 'Вместо това прикачи линк';

  @override
  String get recipeViewOpenExternally => 'Отвори външно';

  @override
  String get recipeViewBadLink =>
      'Този YouTube линк не може да се разчете. Използвай „Отвори външно“.';

  @override
  String cookWith(String name) {
    return 'Готви с $name';
  }

  @override
  String get cookFromYouTube => 'От YouTube';

  @override
  String get cookSearchApps => 'Търси в приложенията';

  @override
  String cookSearchAppsSubtitle(String query) {
    return 'Отваря търсене за „$query рецепта“.';
  }

  @override
  String cookSearchQuery(String name) {
    return '$name рецепта';
  }

  @override
  String get cookNoResults =>
      'Още няма резултати в приложението. Появяват се, щом на сървъра се зададе YouTube API ключ — дотогава използвай бутоните горе.';

  @override
  String get cookAttachToMeal => 'Прикачи към ястието';

  @override
  String cookAttachToNamed(String name) {
    return 'Прикачи към $name';
  }

  @override
  String cookAttached(String name) {
    return 'Прикачено към $name.';
  }

  @override
  String get cookAttachedFallback => 'ястието';

  @override
  String get cookOpenFailed => 'Линкът не се отвори.';

  @override
  String get importReading => 'Четене на рецептата…';

  @override
  String get importNoneFound => 'Не са намерени съставки.';

  @override
  String get importPageUnreadable => 'Страницата не може да бъде прочетена.';

  @override
  String get importUnreachable =>
      'Услугата за внасяне е недостъпна. Провери връзката си.';

  @override
  String importAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Добавени са $count съставки.',
      one: 'Добавена е 1 съставка.',
    );
    return '$_temp0';
  }

  @override
  String get importTitleDefault => 'Съставки';

  @override
  String get importPick => 'Избери какво да добавиш към ястието.';

  @override
  String get importSelectAll => 'Избери всички';

  @override
  String get importClearAll => 'Изчисти всички';

  @override
  String importAddCount(int count) {
    return 'Добави $count';
  }
}
