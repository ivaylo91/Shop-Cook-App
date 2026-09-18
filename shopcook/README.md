# ShopCook

A mobile shopping list app: build a list, group products into meals, and attach a recipe (YouTube video or web page) found via live search.

## Stack

- **Flutter** (Android + iOS from one codebase) with Riverpod for state management and go_router for navigation.
- **Drift** (SQLite) for local, offline-first storage of lists/meals/products/recipes — v1 has no accounts or cross-device sync.
- **Supabase Edge Function** (`supabase/functions/search-recipes`) proxies recipe search to the YouTube Data API and Google Custom Search, so those API keys stay server-side and never ship in the app.

## Design system

Everything visual comes from two files plus a widget kit, and no screen should
reach past them for a colour or a spacing value.

- **`lib/core/design.dart`** holds the tokens: `Insets` (an 8-point grid),
  `Radii`, `AppText` (four sizes, two weights, deliberately no colour), and
  `Motion` (three durations and the curves that go with them).
- **`AppPalette`** in the same file is the colour set, as a `ThemeExtension`
  with `light` and `dark` variants. Read it with `context.palette` — never as
  a constant, so a widget does not have to know which mode it is in. It also
  owns `aisle(category)` for the nine aisle hues and `shadow(tint)`, which
  drops the tint in dark mode where a coloured shadow reads as a glow.
- **`lib/core/theme.dart`** maps the palette onto Material. The scheme starts
  from a seed so every slot is filled, then every slot the UI actually shows
  is pinned to the palette, and `AppText` is mapped onto the `TextTheme` slots
  Material widgets read. Component themes cover app bars, cards, dialogs,
  inputs, list tiles, checkboxes, buttons, sheets, menus and snack bars — so a
  plain `ListTile` or `AlertDialog` is already on the design system.
- **`lib/core/ui/`** is the shared widget kit, imported as one barrel
  (`core/ui/ui.dart`): `AppCard`, `AppCardList`, `ProductRow`, `CheckDot`,
  `SectionLabel`, `CountPill`, `AppProgressBar`, `Skeleton`, `SkeletonRows`,
  `EmptyState`, `ErrorState`, `InlineNote`, plus the `showAppSheet`,
  `confirmAction` and `promptForText` helpers.

Two rules worth keeping: build a screen from the kit before adding a widget to
it, and put any new colour in `AppPalette` with both variants rather than
inline.

**One trap worth knowing:** `FaIcon` (font_awesome_flutter 11+) renders a bare
`RichText` with no box of its own, unlike Material's `Icon`, which centres its
glyph internally. Dropping a `FaIcon` into a **fixed-size** parent with no
`alignment` gives it tight constraints and it lays out top-left. Either give
the parent `alignment: Alignment.center` or wrap the icon in a `Center`. This
is deliberate in the package — non-square Font Awesome glyphs clip when forced
into a square box — so the fix belongs at the call site. `flutter test test/theme_test.dart` checks the palette reaches the
theme and that every aisle has a hue in both modes.

### Dark mode

Light, dark and match-the-phone, persisted with `shared_preferences` and read
before the first frame in `main()` so the app does not open in the wrong theme
and snap. The chooser lives in **Settings → Appearance**.

## Adding items

One field at the bottom of every list, not a dialog. Adding an item is the most
frequent action in the app, so it is the one thing that must not cost a modal
and three taps.

The text runs through the same `parseIngredient` used for recipe imports, so a
single line fills all three fields:

| You type | name | quantity | unit |
|---|---|---|---|
| `2 kg potatoes` | Potatoes | 2 | kg |
| `500g beef mince` | Beef mince | 500 | g |
| `milk` | Milk | | |

The parse is shown above the field before you commit it, because guessing
wrong silently would be worse than not guessing. Names you have added before
appear as one-tap chips, ranked by how often you have used them — a weekly shop
is mostly the same things, and those counts are derived from the rows already
on your lists rather than from a separate history table.

The composer is also on the shopping-mode screen, so remembering something
mid-aisle does not mean backing out of the view you are using.

### Duplicates are topped up, not stacked

Adding something already on the list unchecked adds to it instead of creating a
second row — two recipes both wanting onions used to produce two lines, and
shopping mode showed both.

It only does the arithmetic when that is unambiguous: same name, same unit,
both amounts plain numbers. A range (`2-3`), a pack multiplier (`2 × 400g`), a
fraction, or mismatched units (`2 tbsp` onto `500 g`) all stay as two honest
rows rather than becoming one wrong number. Ticked items are never topped up
either, since you have already bought those.

### Undo

Deleting a list, a meal or an item offers an undo in the snackbar. A list
delete cascades through its meals, products and recipes, so the rows are read
before the delete and re-inserted in foreign-key order if you undo — which is
why this needs no soft-delete column. Long-press a list to rename it; long-press
a meal for rename and delete.

## Languages

English and Bulgarian. The app follows the phone by default — a `bg-BG` phone
opens in Bulgarian with nothing to configure — and **Settings → Език** can
override that when the phone's language is not the one you want to cook in.

Strings live in `lib/l10n/app_en.arb` (the template) and `app_bg.arb`, and
`AppLocalizations` is generated from them (`l10n.yaml`, `generate: true`). Read
them as `context.l10n.someKey` via the extension in `lib/core/localization.dart`.
Adding a string means adding it to the English template first; a key missing
from the Bulgarian file falls back to English rather than rendering blank.

Counts go through ICU plurals rather than an `if`, because the two languages
do not split the same way:

```
"listCardLeftToBuy": "{count, plural, =1{1 left to buy} other{{count} left to buy}}"
```

Two things are deliberately **not** translated. User content — list names,
meals, item names — is whatever you typed. And Supabase's auth errors, which
come back in English regardless of the phone's language; the repository reports
an `AuthOutcome` and the two messages this app authors are localised at the
call site, while the server's own wording is passed through as-is. Same shape
for recipe imports via `ImportFailure`.

### Working in Bulgarian, not just reading it

Translating the UI is the easy half. Two things had to understand Bulgarian
input or the app would be useless in it:

- **Aisle sorting.** `categorize()` matched English words only, so "мляко"
  landed in Други. It now carries ~180 Bulgarian keywords alongside the
  English ones, in one map rather than per locale — a shopping list is not
  monolingual, and the same person writes "мляко" one week and "halloumi" the
  next. Bulgarian entries are **stems** ("домат" covers домат / домати /
  доматен) because the language inflects and matching is by `contains`.
- **Amount parsing.** `parseIngredient` only knew English units and its
  word-boundary pattern was ASCII, so "2 кг картофи" did not split. It now
  reads г / кг / мл / л / бр. / щипка / скилидка / глава and the rest, folds
  dotted spoon abbreviations ("с.л.", "ч. л.") to one token, and knows
  Bulgarian preparation words so "1 глава лук, нарязан на кубчета" yields
  1 глава / Лук.

`test/bulgarian_test.dart` covers both, plus a check that every aisle heading
actually comes back Cyrillic in `bg`.

One thing to watch when adding strings: **Bulgarian runs longer than English.**
The first build truncated the composer hint mid-word in a single-line field.
Anything that cannot wrap needs checking in both languages.

## Getting around

Four tabs in a persistent bottom bar, each with its own navigator via
`StatefulShellRoute.indexedStack`, so switching tabs does not throw away where
you were:

- **Lists** — the shopping lists, and everything under them.
- **Plan** — the week ahead.
- **Recipes** — every recipe you have kept (see "Recipe library").
- **Settings** — appearance, account.

Detail screens (a list, a meal, shopping mode, a recipe) sit *outside* the
shell and cover it. A list detail already has the item composer pinned to its
bottom edge, and a nav bar underneath would fight it for the thumb.

## Planning the week

`Plan` shows the next seven days and which meal is cooked on each. Meals
already existed as a first-class thing with their own ingredients and recipe,
so this is largely a second view of data that was already there — what it adds
is a reason to open the app on a day you are not in a supermarket.

- A meal with no day sits under **Not yet planned**. Give it one from the `+`
  on any day, or from the calendar button in the meal's own app bar.
- Each planned meal shows how far through its shopping you are.
- The week is across *all* lists, because a week is.

Days are stored at midnight local time so two meals on the same date compare
equal, and the range is built with calendar arithmetic rather than by adding a
`Duration`, so a clock change during the week cannot shift the last day out of
the window.

## Whose data is whose

Everything stored locally is scoped to the signed-in user. `shopping_lists`
and `recipes` carry a `user_id` — recipes because, since the library, they no
longer hang off a list. Meals and products are
reachable only through a list, and every query for them is already scoped by
a list id, so scoping lists scopes the whole tree. The one exception is the
composer's suggestion query, which reads across every list at once — it joins
through to the owning list, or it would offer one user's shopping habits to
another.

`user_id` is nullable, because rows written before the column existed have no
owner. The migration deliberately does **not** guess who they belong to — it
cannot know, and guessing would hand one person's lists to another. Instead
they are claimed by the first user to sign in after the upgrade
(`claimUnownedLists`, which claims unowned recipes too), which runs before the list stream is read so an
upgraded device shows its existing lists rather than looking wiped.

## Cloud schema (sync groundwork)

The server half of sync exists. `supabase/migrations/` holds the applied SQL,
version-controlled so the cloud schema is reproducible rather than something
that only lives in a dashboard:

| Migration | What it does |
|---|---|
| `20260915103345_create_shopcook_sync_tables` | Mirrors the four Drift tables, with RLS |
| `20260915103405_enable_realtime_on_shopcook_tables` | Adds them to the `supabase_realtime` publication |

Applied against project `wqidsbhicyfufncxyqww`. Re-apply elsewhere with
`supabase db push`, or `supabase link` then run them in order.

Design notes worth keeping:

- **Ids come from the device.** `uuid` primary keys with no server default, so
  a row created offline keeps its identity when it finally reaches the server.
- **`updated_at` is server-maintained** by a `before update` trigger. It is
  the delta cursor for pulls, and the client's clock is not trusted with it.
- **`deleted_at` is a tombstone.** A hard delete leaves no trace, so another
  device would never learn a row went away and would cheerfully push it back.
- **`user_id` is denormalised onto all four tables** rather than resolved
  through the parent list. RLS runs per row, and an `EXISTS` subquery up the
  tree on every read of every product is a cost paid forever to avoid one
  column.
- **Policies are `to authenticated`** with `(select auth.uid())`, which keeps
  the anon key out entirely and lets the planner evaluate the uid once per
  statement instead of once per row.

**The client sync service is not written yet.** These tables are in place and
empty; nothing reads or writes them, and the app is still device-only. What is
still needed: `updated_at`/`deleted_at` on the local Drift schema, soft
deletes with tombstone filtering on every query, a push/pull reconciliation
with last-write-wins, and a Realtime subscription.

## Database migrations

`schemaVersion` is **7**. The ladder is in `lib/data/local/database.dart`:

| Version | Change |
|---|---|
| 1 | Initial: lists, meals, products, recipes |
| 2 | `meals.planned_for` — the day a meal is cooked |
| 3 | `shopping_lists.user_id` — which signed-in user owns a list |
| 4 | `products.price`, `category_override`, `is_staple`; `recipe_searches` cache table |
| 5 | Recipe library: `meal_recipes` join table, `recipes.user_id`, `recipes.meal_id` dropped |
| 6 | `recipes.details` — the saved copy of a recipe page, for cooking offline |
| 7 | `barcode_products` — names for scanned barcodes |

Most steps are plain `addColumn`s. **v5 is not**: SQLite cannot drop a column
that carries a foreign key, so the step copies every existing attachment into
`meal_recipes`, gives each recipe the owner of its list, then rebuilds
`recipes` without `meal_id`. The rebuild SQL is written out by hand rather
than generated, so it keeps describing the v5 table even after the Dart table
definition moves on.

Every step must be additive and applied in order, because an install can be on
any earlier version: a phone that skipped a release upgrades straight from 1 to
current by running each step in turn.

`test/migration_test.dart` builds a database at the **v1 schema by hand** with
raw SQL, seeds it with a list, meal, product and recipe, then opens it through
`AppDatabase` and checks the upgrade ran, every row survived, the new column
reads null on existing rows, and the foreign-key cascade still works
afterwards. A second test upgrades from v1 and compares the result against a
freshly created database with drift's `validateDatabaseSchema`, which catches
a migration that runs but leaves a column subtly different. Writing the old schema out by hand is deliberate — it keeps
describing what is actually installed on a phone rather than whatever the
current code generates.

When adding a column: add it to the table, add an `if (from < n)` step, bump
`schemaVersion`, regenerate with
`dart run build_runner build`, and add a case to the migration test.

## Running it

```bash
flutter pub get
flutter run
```

If you change the Drift schema in `lib/data/local/database.dart`, regenerate the generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Building an APK

```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

Two things to know about the result:

- **It is signed with the debug key.** `android/app/build.gradle.kts` still
  points the release build type at `signingConfigs.debug`, so the APK
  installs on a device for testing but cannot be uploaded to Play. A real
  keystore is still outstanding.
- **It is a fat APK (~60 MB)** carrying every ABI. `flutter build apk
  --split-per-abi` produces per-architecture APKs roughly a third the size,
  and `flutter build appbundle` is what Play actually wants.

### Android toolchain floors

Flutter validates these three versions before it will build, one at a time,
and they are easy to trip when the Flutter SDK moves ahead of the project.
Current minimums for Flutter 3.47 and what this project pins:

| | Minimum | Pinned here | Where |
|---|---|---|---|
| Gradle | 8.14.0 | 8.14.3 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 8.11.1 | 8.11.1 | `android/settings.gradle.kts` |
| Kotlin (KGP) | 2.2.20 | 2.2.20 | `android/settings.gradle.kts` |

The build also needs `compileSdk` 36, NDK `28.2.13676358` and a **JDK 17** —
Android Studio's bundled JDK is far newer and Gradle rejects it. Point Flutter
at a JDK 17 once and it is remembered:

```bash
flutter config --jdk-dir="/path/to/jdk-17"
```

Missing SDK pieces install with the `android` CLI in `cmdline-tools`. Note
that `sdkmanager` is deprecated and mangles the old `platforms;android-36`
syntax by splitting on the semicolon; the replacement uses slash paths:

```bash
android sdk install platforms/android-36
android sdk install ndk/28.2.13676358
android sdk list --all "*android-36*"   # to find an exact package id
```

**Staying on AGP 8.x is deliberate.** AGP 9+ reads only the new DSL interface,
which the Flutter Gradle plugin does not yet apply cleanly against — hence the
`android.newDsl=false` and `android.builtInKotlin=false` flags that Flutter's
own migrator wrote into `android/gradle.properties`. Flutter warns that Gradle
8.x support will be dropped in favour of 9.1.0+; that upgrade is a real
migration, not a version bump.

## iOS

iOS platform files are generated (`ios/`), but building the iOS target needs
Xcode on macOS. Open the project in Xcode on a Mac to build for iOS. Note that
`flutter_launcher_icons` is configured with `ios: false`, so the iOS target has
no app icon yet.

## Accounts

Signing in is required: the app opens on the login screen and nothing is
reachable until you have a session. Auth is Supabase email/password; the
session is persisted locally, so a returning user is not pushed back to
login just for being offline.

**Data is still local to the device.** Signing in establishes identity but
does not sync anything yet — see "Not built yet" below.

### Testing sign-up

This project has **email confirmation enabled**, so `signUp` creates the user
but withholds a session until the link is clicked; the app shows a "check
your inbox" notice for that case. The project also uses Supabase's built-in
SMTP, which is rate-limited and not intended for production — expect
`email rate limit exceeded` after a handful of sign-ups.

For frictionless local testing, turn off **Authentication → Sign In / Up →
Confirm email** in the Supabase dashboard. For real use, configure custom
SMTP.

## Recipe library

Recipes used to belong to exactly one meal and were deleted with it. They now
live in their own library (the **Recipes** tab) and are linked to meals
through `meal_recipes`, so one recipe can go on as many meals as it is cooked
for.

- **Removing a recipe from a meal** only unlinks it; it stays in the library.
  Deleting a meal or a list does the same. Only **Delete for good** in the
  library removes the recipe itself.
- **Saving** happens whenever a recipe is attached to a meal, from the bookmark
  on a search result for an item with no meal, or from the link button on the
  Recipes tab. Saving the same URL twice reuses the existing recipe.
- A meal's recipe section has **From your recipes** to pick one already saved.
- **Pictures.** A web recipe takes the dish photo the importer finds (the
  recipe data's own image, else the page's `og:image`, preferring https since
  Android will not load plain http images). A pasted YouTube link takes the
  video's still from `i.ytimg.com`, which needs no request; the 16:9
  `mqdefault` still is used because the 4:3 `hqdefault` one is letterboxed.
  Recipes saved before either existed are filled in when the Recipes tab
  opens.
- Each library card says how many meals use it, and its menu puts it on any
  meal — labelled with the list's name, since meal names repeat week to week.

## Cooking mode

**Cook** on a web recipe (on its meal card, in the library menu, or in the
recipe viewer's app bar) opens the recipe one step per screen:

- The first page is the ingredients as a checklist; the list button in the
  app bar brings the same ticks back up at any step.
- Steps are set in large type, and the screen is kept awake while cooking
  mode is open (`wakelock_plus`).
- **Servings.** − and + on the ingredients page scale every amount. When the
  recipe says how many it serves, the control counts servings (6 → 3 halves
  everything); otherwise it steps through ×½ … ×4. The amount at the start of
  each line is scaled: whole numbers, ranges ("4–5"), "1/2", "1 1/2", "½" and
  decimals. Lines written with a decimal stay decimal ("1,5 кг" → "4,5 кг");
  the rest come out as kitchen fractions ("1 ч. л." → "½ ч. л."). Lines with
  no leading amount ("сол на вкус") are left alone, as are amounts inside the
  steps' text.
- Any time mentioned in a step ("20 minutes", "10-15 минути", "1 час")
  becomes a one-tap timer. A range times its lower end. Running timers sit
  above the buttons; when one ends the phone vibrates and plays the system
  alert. Leaving with a timer running asks first.
- **Timers only run while cooking mode is open.** There is no notification
  plugin, so a timer cannot ring once you leave the screen.

Recipe data comes from the `import-recipe` function and is **saved on the
recipe** (`recipes.details`). A recipe is read as soon as it is saved, while
there is signal, so it works in a kitchen with none; a link saved without a
title takes the page's title at the same time. Recipes saved before this, or while offline, are read in the
background the next time the Recipes tab is open. A recipe never read before
shows a "no connection" screen with a retry instead of the generic "can't
read this page" one. Videos have no step data, so cooking mode is not
offered for them.

## Scanning and speaking items

With the composer empty, two more buttons sit beside it:

- **Barcode.** Opens the camera (retail codes only: EAN-13/8, UPC-A/E).
  The name comes from the phone's own memory first, then from
  [Open Food Facts](https://world.openfoodfacts.org), a free open database
  that needs no key, preferring the name in the app's language. It lands in
  the field, not on the list, so a wrong match can be corrected and an
  amount added first. A code nobody knows is remembered under whatever name
  you type for it (`barcode_products`), so the next scan is instant and
  works offline. Scanning uses `mobile_scanner` (ML Kit), which adds about
  7 MB to the APK.
- **Microphone.** Uses the phone's speech recognizer (`speech_to_text`) in
  the app's language when the phone has it. "Мляко, 2 кг картофи и яйца"
  is split on commas and joining words (и, плюс, and…), and a leading
  "купи" or "add" is dropped. One item goes into the field; several are
  shown as a checklist to confirm before they are added.

Camera and microphone permissions are asked for the first time each
button is used.

## Home screen widget

Long-press the home screen → Widgets → ShopCook. The widget shows the list
with the most left to buy: its name, how many items are left, and the first
six of them. Tapping it opens that list.

The widget is plain Android views (`ShoppingListWidget.kt`,
`res/layout/shopping_list_widget.xml`) drawn by `home_widget`. It has no
Flutter behind it, so `HomeWidgetSync` in the tab shell decides everything
it shows, in the app's language, and pushes it whenever a list changes.
It therefore updates while the app is running; changes made elsewhere reach
it the next time the app opens. iOS would need a WidgetKit extension and is
not done.

## Sharing into ShopCook

On Android, ShopCook appears in the system share sheet for text:

- **A link** (from a browser, YouTube, anything) opens the Recipes tab with
  the save-link dialog filled in, using the page title when the sharing app
  sent one.
- **Plain text** (a checklist from a notes app) asks which list to add it to,
  then adds one item per line. Bullets, numbering and `[ ]` checkboxes are
  stripped, headings ending in `:` are skipped, and each line goes through the
  same parser and duplicate merging as the composer.

This is a few lines of Kotlin in `MainActivity` and a `shopcook/share` method
channel, not a plugin: `receive_sharing_intent` 1.9 needs AGP 9 and Kotlin
2.4, and this project stays on AGP 8 (see the toolchain notes). Dart pulls a
pending share with `takeShared`, so a share that launches the app is not lost
while Flutter starts. iOS would need a share extension and is not done.

## Prices, aisles and staples

Tap an item for its sheet:

- **Price** — per line, not per unit. Shopping mode shows what is in the
  basket and the list's running total, in the phone's currency format.
- **Aisle** — the aisle is guessed from the name; if the guess is wrong, pick
  another. The correction is remembered for that name and used next time.
- **Staple** — marks something you always keep in. **Restock staples** on a
  list adds every staple that is not already on it.

Settings → **Aisle order** drags aisles into the order your shop is laid out,
and shopping mode walks them in that order. **Share** on a list sends it as
plain text, grouped by aisle, to any app.

## Recipe ideas from a shopping item

Long-press any item (or tap its actions button) for **Find recipes**, which
opens "Cook with &lt;item&gt;". That screen offers:

- **YouTube results in-app**, via the `search-recipes` Edge Function. Needs
  `YOUTUBE_API_KEY` (see below); until it is set the section says so.
  When the item belongs to a meal, a result can be attached to that meal;
  otherwise it can be saved to the library.
  Results are cached on the device for seven days (`recipe_searches`),
  because a YouTube search costs 100 of the 10,000 daily quota units. Empty
  results are never cached, and the refresh button in the app bar skips the cache. The
  search runs in the app's language, so Bulgarian gets Bulgarian videos.
- **One-tap search in the YouTube app**, pre-filled with the localised
  "&lt;item&gt; recipe" phrase. Needs no keys. Android routes the link to the
  installed app, falling back to the browser. Worth keeping even with in-app
  results working: the API returns ten videos and spends quota doing it, while
  the app gives the full list, playback and comments for nothing.

TikTok was offered here too and has been removed. It has no public search API
— the Display API only reaches the signed-in user's own videos and the
Research API needs approval — so it could only ever be a deep link out, never
results in the app.

## Importing ingredients from a recipe

Attach a recipe link to a meal, then tap the import icon on the recipe card.
The `import-recipe` Edge Function fetches the page and reads the
`schema.org/Recipe` data that most recipe sites publish for Google, JSON-LD
first and microdata as a fallback. It returns the ingredients, the method as
steps, the servings, the total time and a picture of the dish. The app splits each ingredient line
into a name, quantity and unit and lets you pick what to add.

The method arrives in many shapes (a string, a list, `HowToStep`s,
`HowToSection`s, or one `<div>` with `<br>`s). Anything that arrives as one
long block of prose is split into sentences, so cooking mode does not show a
whole method on one screen.

**This needs no API keys** — it works as soon as you have a recipe URL.

Two limits worth knowing:

- Some large sites (AllRecipes, Serious Eats, Simply Recipes) block
  server-side fetches and return 403. BBC Good Food, Budget Bytes, Jamie
  Oliver and RecipeTin Eats all work.
- Bulgarian sites: **bonapeti.bg** works (JSON-LD, with steps, servings and
  time). **receptite.com** works through the microdata fallback; it gives no
  servings or time, and its method is often a single paragraph.
- YouTube has no structured ingredient data, so videos cannot be imported —
  only web recipes.

The function refuses non-public addresses (localhost, private ranges,
link-local) so it cannot be used to reach private infrastructure.

## Enabling live recipe search

The `search-recipes` Edge Function is deployed, but returns empty results until its API keys are configured. Add these as secrets on the Supabase project (Project Settings → Edge Functions → Secrets, or `supabase secrets set KEY=value` via the Supabase CLI):

- `YOUTUBE_API_KEY` — a Google Cloud API key with the **YouTube Data API v3** enabled.
- `GOOGLE_CSE_KEY` and `GOOGLE_CSE_CX` — a Google Custom Search JSON API key and a Programmable Search Engine ID (create one at https://programmablesearchengine.google.com, set it to search the whole web).

Until then, the recipe search screen still works end-to-end via **"Attach a link manually"**, which lets you paste a YouTube or recipe URL directly.

## Supabase project

- Project ref: `wqidsbhicyfufncxyqww`
- URL and publishable key are in `lib/core/supabase_config.dart` (the publishable key is safe to ship client-side).

## Not built yet

- **Cloud sync.** Lists live only on the device, so signing in on a second
  phone shows an empty app. Local data *is* now scoped per user, so two
  people on one device no longer see each other's lists — but neither of them
  gets their data on another device.
- **Offline lockout.** Because signing in is required, a session that
  expires while offline leaves the app unreachable until there is a
  connection. Persisted sessions make this rare, not impossible.
- Publishing/store builds (the release APK is signed with the debug key).
