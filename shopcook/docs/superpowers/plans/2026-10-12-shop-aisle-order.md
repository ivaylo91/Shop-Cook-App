# Aisle Order per Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user keep a separate aisle order for each shop they use (Kaufland, Lidl, Billa…) and pick the shop when they start shopping, so the list follows the route through that shop.

**Architecture:** A `ShopsController` (Riverpod `Notifier`) holds named shops, each with its own `List<ProductCategory>`, persisted as JSON in `SharedPreferences` next to the existing `aisleOrder` key. The existing global order stays as the "Default order" used when no shop is chosen. A derived `currentAisleOrderProvider` is the single order that shopping mode and list sharing read. Shops are per phone and are not synced.

**Tech Stack:** Flutter 3.47, Dart 3.13, flutter_riverpod 2.6, shared_preferences, go_router 14, gen-l10n (`lib/l10n/app_en.arb`, `app_bg.arb`).

**Spec:** None written. This plan records the design decisions (section "Decisions") and is the spec of record. Agreed with the user on 2026-10-12: "Aisle order per shop: pick the shop when shopping; each shop remembers its own aisle order."

## Decisions

- A shop is `{id, name, order}`. `id` is a v4 uuid (`package:uuid`, already a dependency). `name` is user text, trimmed, 1–40 characters.
- A new shop starts as a copy of the **current** order (the default, or the active shop's), so nobody drags nine aisles from scratch.
- No built-in layouts for real chains: the app does not know them. The "New shop" dialog only offers name chips `Kaufland`, `Lidl`, `Billa`, `Fantastico`, `T Market`.
- Which shop is active is **one global choice**, remembered across launches (`activeShop` key). It is not per list. Choosing "Default order" clears it.
- Deleting the active shop makes the default order active again.
- The existing `aisleOrder` key and `AisleOrderController` keep working unchanged as the default order. Nothing is migrated.
- Shop data stays on the phone. A shared list's partner keeps their own shops. The privacy policy needs no change.

## Global Constraints

- Order resolution rule (existing, `lib/core/settings.dart`): stored as enum **names**; unknown names dropped; missing categories appended in `ProductCategory.values` order. Every stored shop order goes through the same rule.
- Storage keys: `shops.v1` (JSON list of `{"id","name","order":[names]}`), `activeShop` (shop id string, absent = default order). Existing key `aisleOrder` untouched.
- Every user-facing string in both `app_en.arb` and `app_bg.arb`; regenerate with `flutter gen-l10n`.
- Format only files you changed (`dart format <files>`), never `lib` or `test` wholesale.
- Use the `onReorderItem` index semantics already documented in `AisleOrderController.reorder`: no off-by-one correction.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Corrupt or hand-edited `shops.v1`** (not JSON, wrong types, missing fields): the app opens with no shops and the default order, never a crash. → Task 1 test `corrupt storage reads as no shops`.
2. **Active shop deleted** (here, or its id no longer in the list after a reinstall restore): shopping mode falls back to the default order and the picker shows "Default order" selected. → Task 1 test `deleting the active shop falls back to the default order`.
3. **A future release adds a `ProductCategory`**: every saved shop still lists every aisle, with the new one at the end. → Task 1 test `a shop saved before a new aisle existed gets it at the end`.
4. **Blank or whitespace name, or a name longer than 40**: blank is refused (the dialog's Save stays disabled), long names are cut to 40. → Task 1 test `names are trimmed, blank refused, long cut`.
5. **Sharing a list as text while a shop is active**: the shared text follows the active shop's order, the same order the sender sees in shopping mode. → Task 3 test `sharing follows the current order`.

---

## File Structure

- Create `lib/features/shopping/shops.dart`: `Shop`, `ShopsState`, `ShopsController`, `shopsProvider`, `currentAisleOrderProvider`. Pure state and storage, no widgets.
- Create `lib/features/shopping/aisle_order_editor.dart`: `AisleOrderEditor` widget, the reorderable list taken out of `_AisleOrderCard`.
- Create `lib/features/shopping/shop_picker.dart`: `showShopPicker()` bottom sheet and `showNewShopDialog()`.
- Create `lib/features/settings/shop_order_screen.dart`: one shop's order, rename, delete.
- Modify `lib/core/settings.dart`: expose the resolver as `resolveAisleOrder`.
- Modify `lib/features/settings/settings_screen.dart`: "Aisle order" section becomes "Shops".
- Modify `lib/features/shopping/shopping_mode_screen.dart`: shop chip in the app bar; read `currentAisleOrderProvider`.
- Modify `lib/features/sharing/share_actions.dart:75`: read `currentAisleOrderProvider`.
- Modify `lib/app.dart`: route `/shop/:shopId`.
- Test: `test/shops_test.dart` (new), `test/settings_test.dart` (resolver).

---

### Task 1: Shops state and storage

**Files:**
- Modify: `lib/core/settings.dart:107-121` (`_resolve` → public top-level `resolveAisleOrder`)
- Create: `lib/features/shopping/shops.dart`
- Test: `test/shops_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `aisleOrderProvider` (`lib/core/settings.dart`), `ProductCategory` (`lib/features/shopping/product_category.dart`).
- Produces:
  - `List<ProductCategory> resolveAisleOrder(List<String>? names)` in `settings.dart`, which `AisleOrderController` now calls.
  - `class Shop { final String id; final String name; final List<ProductCategory> order; }` with `Map<String, Object?> toJson()` and `factory Shop.fromJson(Map<String, Object?>)` (the factory resolves `order` through `resolveAisleOrder`).
  - `class ShopsState { final List<Shop> shops; final String? activeId; Shop? get active; }`. `active` is null when `activeId` is null or not in `shops`.
  - `class ShopsController extends Notifier<ShopsState>` with:
    `Future<Shop> add(String name)` (copies the current order; throws `ArgumentError` on blank name),
    `Future<void> rename(String id, String name)`,
    `Future<void> remove(String id)`,
    `Future<void> reorder(String id, int oldIndex, int newIndex)`,
    `Future<void> choose(String? id)` (null = default order).
  - `final shopsProvider = NotifierProvider<ShopsController, ShopsState>(...)`.
  - `final currentAisleOrderProvider = Provider<List<ProductCategory>>(...)`: active shop's order, else `ref.watch(aisleOrderProvider)`.

- [ ] **Step 1: Write the failing tests** in `test/shops_test.dart`, using the `containerWith` helper pattern from `test/settings_test.dart` (copy it into the file):

```dart
test('no shops at first: the default order is current', ...);
  // shopsProvider.shops isEmpty, activeId null,
  // currentAisleOrderProvider == ProductCategory.values

test('a new shop copies the current order and becomes choosable', ...);
  // aisleOrderProvider.set([frozen, produce, ...rest]); add('Lidl');
  // shop.order.first == ProductCategory.frozen; choose(shop.id);
  // currentAisleOrderProvider.first == ProductCategory.frozen

test('each shop keeps its own order', ...);
  // add('Lidl'), add('Billa'); reorder(lidl.id, 0, 3);
  // choose(billa.id) -> order == ProductCategory.values;
  // choose(lidl.id) -> order[3] == ProductCategory.produce

test('shops and the choice survive a restart', ...);
  // after add + reorder + choose, read prefs 'shops.v1' and 'activeShop',
  // build a new container with them: same names, same order, same active

test('deleting the active shop falls back to the default order', ...);
  // choose(lidl.id); remove(lidl.id); state.active == null;
  // currentAisleOrderProvider == aisleOrderProvider

test('corrupt storage reads as no shops', ...);
  // containerWith({'shops.v1': 'not json', 'activeShop': 'gone'})
  // shops isEmpty, active == null; also '[{"name":3}]' -> isEmpty

test('a shop saved before a new aisle existed gets it at the end', ...);
  // stored order lists 8 names (omit 'other'): order.last == ProductCategory.other,
  // order.length == ProductCategory.values.length

test('names are trimmed, blank refused, long cut', ...);
  // add('  Lidl ').name == 'Lidl'; expect(() => add('   '), throwsArgumentError);
  // add('x' * 60).name.length == 40
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/shops_test.dart`
Expected: compile error, `shops.dart` not found.

- [ ] **Step 3: Move the resolver.** In `lib/core/settings.dart`, turn `AisleOrderController._resolve` into top-level `List<ProductCategory> resolveAisleOrder(List<String>? names)` with the same body and doc comment, and call it from `build()` and `set()`.

- [ ] **Step 4: Implement `lib/features/shopping/shops.dart`** to the Interfaces above. Read `shops.v1` with `jsonDecode` inside `try/catch`: on any exception, or any entry that is not a map with a `String id`, `String name` and `List order`, drop it, and for a top-level failure start empty. Write the whole list back on every change. `remove` of the active shop also removes the `activeShop` key. Names: `trim()`, then cut to 40.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/shops_test.dart test/settings_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/core/settings.dart lib/features/shopping/shops.dart test/shops_test.dart
git commit -m "Shops: named aisle orders, stored on the phone"
```

---

### Task 2: Edit a shop's order

**Files:**
- Create: `lib/features/shopping/aisle_order_editor.dart`
- Create: `lib/features/settings/shop_order_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart:436-500` (`_AisleOrderCard` uses `AisleOrderEditor`)
- Modify: `lib/app.dart` (route)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_bg.arb`
- Test: `test/shops_test.dart` (widget test added)

**Interfaces:**
- Consumes: `shopsProvider` and its `rename` / `remove` / `reorder` (Task 1).
- Produces:
  - `class AisleOrderEditor extends StatelessWidget { AisleOrderEditor({required List<ProductCategory> order, required void Function(int oldIndex, int newIndex) onReorder}); }`: the `ReorderableListView` body of today's `_AisleOrderCard`, unchanged in look.
  - `class ShopOrderScreen extends ConsumerWidget { const ShopOrderScreen({required String shopId}); }`: app bar with the shop name and two actions, rename (pencil) and delete (trash, with `confirmAction`, destructive). Body is `AisleOrderEditor` on that shop. It pops itself when the shop no longer exists.
  - Route `GoRoute(path: '/shop/:shopId', builder: ShopOrderScreen(shopId: ...))`.
  - Strings: `shopRename` "Rename", `shopDelete` "Delete shop", `shopDeleteTitle` "Delete {name}?", `shopDeleteMessage` "Its aisle order is lost. Your lists are not touched.", `shopNameHint` "Shop name". Bulgarian: "Преименувай", "Изтрий магазина", "Да изтрия ли {name}?", "Подредбата му ще се изгуби. Списъците ти остават.", "Име на магазина".

- [ ] **Step 1: Write the failing widget test** in `test/shops_test.dart`:

```dart
testWidgets('reordering on the shop screen changes only that shop', ...);
  // pump ShopOrderScreen(shopId: lidl.id) in a ProviderScope + MaterialApp with
  // localizations; drag the first ReorderableDragStartListener below the
  // third row; expect shopsProvider lidl.order.first != ProductCategory.produce,
  // and aisleOrderProvider unchanged (== ProductCategory.values)
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/shops_test.dart --plain-name "reordering on the shop screen"`
Expected: compile error, `ShopOrderScreen` not found.

- [ ] **Step 3: Extract `AisleOrderEditor`** from `_AisleOrderCard`, then make `_AisleOrderCard` use it with `aisleOrderProvider`. The settings screen must look and behave exactly as before.

- [ ] **Step 4: Implement `ShopOrderScreen`**, its route and its strings, then run `flutter gen-l10n`. Rename reuses the dialog from Task 3 (`showNewShopDialog`) if Task 3 is already done; otherwise build a plain `AlertDialog` with a `TextField`, which Task 3 then replaces.

- [ ] **Step 5: Run all tests and the analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all pass; "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/features/shopping/aisle_order_editor.dart lib/features/settings/shop_order_screen.dart lib/features/settings/settings_screen.dart lib/app.dart lib/l10n test/shops_test.dart
git commit -m "Shops: edit one shop's aisle order"
```

---

### Task 3: Pick the shop while shopping

**Files:**
- Create: `lib/features/shopping/shop_picker.dart`
- Modify: `lib/features/shopping/shopping_mode_screen.dart:35-37` (app bar), `:126` (order)
- Modify: `lib/features/sharing/share_actions.dart:75`
- Modify: `lib/features/shopping_lists/share_list.dart` (extract `shareListText`)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_bg.arb`
- Test: `test/shops_test.dart`

**Interfaces:**
- Consumes: `shopsProvider`, `currentAisleOrderProvider` (Task 1); route `/shop/:shopId` (Task 2).
- Produces:
  - `Future<void> showShopPicker(BuildContext context, WidgetRef ref)`: a `showAppSheet` with one row per shop, plus "Default order" (with a check mark on the current one), "New shop…" and "Edit this shop's order" (only when a shop is active; it pushes `/shop/<id>`).
  - `Future<String?> showNewShopDialog(BuildContext context, {String initial = ''})`: returns a trimmed name, or null on cancel. Save is disabled while the field is blank. Under the field are `ActionChip`s for `Kaufland`, `Lidl`, `Billa`, `Fantastico`, `T Market`, which fill the field.
  - Shopping mode app bar `actions`: an `ActionChip` showing the active shop's name, or `shopDefault`, that opens `showShopPicker`.
  - Strings: `shopDefault` "Default order", `shopNew` "New shop…", `shopEditOrder` "Edit this shop's order", `shopPickerTitle` "Which shop?". Bulgarian: "Обичайна подредба", "Нов магазин…", "Подреди този магазин", "В кой магазин си?".

- [ ] **Step 1: Write the failing tests**

```dart
test('sharing follows the current order', ...);
  // containerWith: add('Lidl'), reorder so frozen is first, choose(lidl.id);
  // shareListText(l10n, list: ..., products: [produceItem, frozenItem],
  //   aisleOrder: container.read(currentAisleOrderProvider))
  // -> indexOf(frozen name) < indexOf(produce name)
  // (l10n: lookupAppLocalizations(const Locale('en')))

testWidgets('choosing a shop in the picker reorders shopping mode', ...);
  // ShoppingModeScreen with one frozen and one produce product (in-memory
  // AppDatabase.forTesting); tap the shop chip, tap 'Lidl';
  // the frozen aisle header is above the produce header
```

`shareList()` in `lib/features/shopping_lists/share_list.dart` builds the text and opens the share sheet in one function. Step 3 splits out the text so it can be tested without a share sheet: `String shareListText(AppLocalizations l10n, {required ShoppingList list, required List<Product> products, required List<ProductCategory> aisleOrder})`, which `shareList()` then calls. Output must stay byte-identical.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/shops_test.dart`
Expected: fail, shopping mode still orders by `aisleOrderProvider`.

- [ ] **Step 3: Implement** `shop_picker.dart`. In shopping mode, replace `ref.watch(aisleOrderProvider)` with `ref.watch(currentAisleOrderProvider)` and add the chip. Extract `shareListText` from `shareList()`. In `share_actions.dart:75`, read `currentAisleOrderProvider`. Add the strings and run `flutter gen-l10n`.

- [ ] **Step 4: Run all tests and the analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all pass; "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/features/shopping lib/features/sharing/share_actions.dart lib/l10n test/shops_test.dart
git commit -m "Shops: choose the shop while shopping"
```

---

### Task 4: Shops in Settings, README, device check

**Files:**
- Modify: `lib/features/settings/settings_screen.dart:120-137` (section)
- Modify: `README.md` (section "Prices, aisles and staples")
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_bg.arb`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - Settings section `settingsShops` "Shops", with note `settingsShopsNote` "Each shop keeps its own aisle order. Pick the shop when you start shopping."
  - Its first card is "Default order" (today's `_AisleOrderCard`, unchanged).
  - Then one `ListTile` per shop, with `/shop/<id>` on tap, and a "New shop…" button (`showNewShopDialog`, then `add`, then push its screen).
  - Bulgarian: "Магазини", "Всеки магазин пази своя подредба на щандовете. Избери магазина, когато пазаруваш."

- [ ] **Step 1: Implement the section, strings and README paragraph.** The README says shops are per phone and not shared.

- [ ] **Step 2: Run all tests and the analyzer**

Run: `flutter test` then `flutter analyze`
Expected: all pass; "No issues found!"

- [ ] **Step 3: Check on the throwaway emulator (Pixel_9_Pro_XL)**, with a throwaway account, deleted afterwards:
  1. Create shop "Lidl" in Settings and drag Frozen to the top.
  2. Open a list with a frozen and a produce item, enter shopping mode, pick Lidl: Frozen comes first.
  3. Pick "Default order": Produce comes first.
  4. Delete Lidl while it is active: shopping mode shows "Default order".
  5. Switch the app to Bulgarian: the chip and picker are in Bulgarian.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_screen.dart lib/l10n README.md
git commit -m "Shops: manage them in Settings"
```
