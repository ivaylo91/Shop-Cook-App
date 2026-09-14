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
inline. `flutter test test/theme_test.dart` checks the palette reaches the
theme and that every aisle has a hue in both modes.

### Dark mode

Light, dark and match-the-phone, persisted with `shared_preferences` and read
before the first frame in `main()` so the app does not open in the wrong theme
and snap. The chooser is in the app bar on the lists screen until there is a
settings screen to hold it.

## Running it

```bash
flutter pub get
flutter run
```

If you change the Drift schema in `lib/data/local/database.dart`, regenerate the generated code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Android build notes (this dev environment)

Gradle 8.12 (used by this Flutter version's Android build) doesn't support very new JDKs. If `flutter build apk` fails with a bare version-number error like `26.0.2.1`, point Flutter at an older JDK:

```bash
flutter config --jdk-dir="/path/to/jdk-17"
```

### iOS

iOS platform files are generated (`ios/`), but building/running the iOS target requires Xcode on macOS — not possible from this Linux machine. Open the project in Xcode on a Mac to build for iOS.

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

## Recipe ideas from a shopping item

Long-press any item (or tap its actions button) for **Find recipes**, which
opens "Cook with &lt;item&gt;". That screen offers:

- **YouTube results in-app**, via the `search-recipes` Edge Function. Needs
  `YOUTUBE_API_KEY` (see below); until it is set the section says so.
  When the item belongs to a meal, a result can be attached to that meal.
- **One-tap search in the YouTube and TikTok apps**, pre-filled with
  "&lt;item&gt; recipe". Needs no keys and works today. Android routes the
  link to the installed app, falling back to the browser.

**Why TikTok is a deep link rather than in-app results:** TikTok has no
public search API. The Display API only reaches the signed-in user's own
videos, and the Research API requires approval and is limited to academic
use. Pulling TikTok results into the app would mean a paid third-party
scraping service, so the app opens TikTok's own search instead.

## Importing ingredients from a recipe

Attach a recipe link to a meal, then tap the import icon on the recipe card.
The `import-recipe` Edge Function fetches the page and reads the
`schema.org/Recipe` JSON-LD that most recipe sites publish for Google; the app
splits each line into a name, quantity and unit and lets you pick what to add.

**This needs no API keys** — it works as soon as you have a recipe URL.

Two limits worth knowing:

- Some large sites (AllRecipes, Serious Eats, Simply Recipes) block
  server-side fetches and return 403. BBC Good Food, Budget Bytes, Jamie
  Oliver and RecipeTin Eats all work.
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

- **Cloud sync.** Lists live only on the device. Two consequences worth
  knowing while this is true:
  - Signing in on a second phone shows an empty app.
  - Local data is not scoped per user, so if two people sign in on the same
    device they see the same lists.
- **Offline lockout.** Because signing in is required, a session that
  expires while offline leaves the app unreachable until there is a
  connection. Persisted sessions make this rare, not impossible.
- **A settings screen.** Theme mode is the only preference there is, and it
  lives in the lists-screen app bar.
- **Renaming a list or meal**, and undo on delete. Deleting a list asks for
  confirmation but cannot be undone.
- **A faster way to add an item.** It is still a three-field dialog; the plan
  is one inline field parsed by `parseIngredient`, which already splits
  "2 kg potatoes" for recipe imports.
- Publishing/store builds (the release APK is signed with the debug key).
