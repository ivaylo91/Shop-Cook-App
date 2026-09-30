import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/features/pantry/pantry_match.dart';
import 'package:shopcook/features/plan/week_shop.dart';
import 'package:shopcook/features/review/review_prompt.dart';
import 'package:shopcook/features/share_intake/shared_content.dart';
import 'package:shopcook/features/sharing/invite_link.dart';
import 'package:shopcook/features/spending/spending.dart';

Meal _meal(String id, String list, {DateTime? cooked}) => Meal(
  id: id,
  listId: list,
  name: 'Meal $id',
  cookedAt: cooked,
  createdAt: DateTime(2026, 9, 1),
);

Product _product(
  String name, {
  String list = 'week',
  String? meal,
  bool checked = false,
  double? price,
  DateTime? created,
  DateTime? cleared,
  String quantity = '',
}) => Product(
  id: '$list-$meal-$name-$created-$cleared',
  listId: list,
  mealId: meal,
  name: name,
  quantity: quantity,
  unit: '',
  isChecked: checked,
  price: price,
  isStaple: false,
  clearedAt: cleared,
  createdAt: created ?? DateTime(2026, 9, 10),
);

void main() {
  group('invite links', () {
    test('carry the code as c and read back', () {
      final link = inviteLink('ABCD2345');
      expect(link, endsWith('join.html?c=ABCD2345'));
      expect(inviteCodeIn('Join my list: $link — see you'), 'ABCD2345');
    });

    test('are found inside a forwarded invite, case aside', () {
      const text =
          'Join my ShopCook list “Weekly”: '
          'https://ivaylo91.github.io/Shop-Cook-App/join.html?c=abcd2345\n\n'
          'Or open ShopCook…';
      expect(inviteCodeIn(text), 'ABCD2345');
      expect(parseShared(text), isA<SharedJoin>());
    });

    test('an ordinary recipe link is still a recipe link', () {
      expect(
        parseShared('https://example.com/join-the-soup-club'),
        isA<SharedLink>(),
      );
      expect(inviteCodeIn('https://example.com/join.html?c=1'), isNull);
    });

    test('typed codes are tidied', () {
      expect(cleanInviteCode(' abcd-2345 '), 'ABCD2345');
      expect(cleanInviteCode('ABCD 2345'), 'ABCD2345');
      expect(cleanInviteCode('  '), isNull);
    });
  });

  group('at home', () {
    test('every word of the pantry entry has to be there', () {
      expect(isAtHome('extra virgin olive oil', ['olive oil']), isTrue);
      expect(isAtHome('olive oil', ['oil']), isTrue);
      expect(isAtHome('sunflower oil', ['olive oil']), isFalse);
    });

    test('plurals and Bulgarian endings match', () {
      expect(isAtHome('tomatoes', ['tomato']), isTrue);
      expect(isAtHome('eggs', ['egg']), isTrue);
      expect(isAtHome('яйцата', ['яйца']), isTrue);
      expect(isAtHome('Брашното', ['брашно']), isTrue);
    });

    test('a shared start is not enough', () {
      expect(isAtHome('unsalted butter', ['salt']), isFalse);
      expect(isAtHome('oily fish', ['oil']), isFalse);
      expect(isAtHome('milkshake', ['milk']), isFalse);
    });
  });

  group('shopping for the week', () {
    const pantry = ['olive oil'];

    test('meals on another list bring their unticked ingredients', () {
      final items = gatherWeek(
        meals: [_meal('a', 'ideas')],
        ingredients: {
          'a': [
            _product('Rice', list: 'ideas', meal: 'a'),
            _product('Onion', list: 'ideas', meal: 'a', checked: true),
            _product('Olive oil', list: 'ideas', meal: 'a'),
          ],
        },
        recipeLines: const {},
        targetListId: 'week',
        pantry: pantry,
      );

      expect(items.map((i) => i.name), ['Rice', 'Olive oil']);
      expect(items.last.atHome, isTrue);
      expect(items.every((i) => !i.fromRecipe), isTrue);
    });

    test('meals already on the list add nothing of their own', () {
      final items = gatherWeek(
        meals: [_meal('a', 'week')],
        ingredients: {
          'a': [_product('Rice', meal: 'a')],
        },
        recipeLines: const {},
        targetListId: 'week',
        pantry: pantry,
      );
      expect(items, isEmpty);
    });

    test('a meal with no ingredients falls back to its recipe', () {
      final items = gatherWeek(
        meals: [_meal('a', 'week')],
        ingredients: const {'a': []},
        recipeLines: const {
          'a': ['400 g chicken thighs', '2 tbsp olive oil'],
        },
        targetListId: 'week',
        pantry: pantry,
      );

      expect(items.map((i) => i.name), ['Chicken thighs', 'Olive oil']);
      expect(items.first.quantity, '400');
      expect(items.every((i) => i.fromRecipe), isTrue);
      expect(items.last.atHome, isTrue);
    });

    test('cooked meals are left out', () {
      final items = gatherWeek(
        meals: [_meal('a', 'ideas', cooked: DateTime(2026, 9, 20))],
        ingredients: {
          'a': [_product('Rice', list: 'ideas', meal: 'a')],
        },
        recipeLines: const {},
        targetListId: 'week',
        pantry: const [],
      );
      expect(items, isEmpty);
    });
  });

  group('asking for a rating', () {
    final now = DateTime(2026, 9, 30);

    test('not before the third finished shop', () {
      expect(
        shouldAskForReview(shopsDone: 2, lastAsked: null, now: now),
        isFalse,
      );
      expect(
        shouldAskForReview(shopsDone: 3, lastAsked: null, now: now),
        isTrue,
      );
    });

    test('not again until the quiet period has passed', () {
      expect(
        shouldAskForReview(
          shopsDone: 9,
          lastAsked: now.subtract(const Duration(days: 30)),
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldAskForReview(
          shopsDone: 9,
          lastAsked: now.subtract(reviewQuietPeriod),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('spending', () {
    final now = DateTime(2026, 9, 29);

    test('adds up bought, priced items by the month they were cleared', () {
      final summary = summarizeSpending(
        [
          _product('Milk', checked: true, price: 2.5),
          _product('Milk', checked: true, price: 2.5),
          _product('Bread', checked: true, price: 1.2),
          // Not bought yet: not spent.
          _product('Cheese', price: 9),
          // Bought in August, cleared in August.
          _product(
            'Coffee',
            checked: true,
            price: 8,
            created: DateTime(2026, 8, 20),
            cleared: DateTime(2026, 8, 22),
          ),
          // Added in August, bought and cleared in September.
          _product(
            'Tea',
            checked: true,
            price: 3,
            created: DateTime(2026, 8, 30),
            cleared: DateTime(2026, 9, 2),
          ),
          _product('Eggs', checked: true),
        ],
        listNames: const {'week': 'Weekly'},
        now: now,
      );

      expect(summary.thisMonth, closeTo(9.2, 1e-9));
      expect(summary.lastMonth, 8);
      expect(summary.months.map((m) => m.month.month), [4, 5, 6, 7, 8, 9]);
      expect(summary.unpriced, 1);
      expect(summary.topItems.first.name, 'Milk');
      expect(summary.topItems.first.times, 2);
      expect(summary.byList.single.list, 'Weekly');
    });

    test('with nothing bought there is nothing to show', () {
      final summary = summarizeSpending(
        [_product('Milk', price: 2)],
        listNames: const {},
        now: now,
      );
      expect(summary.isEmpty, isTrue);
    });
  });
}
