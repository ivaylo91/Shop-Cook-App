import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopcook/data/local/database.dart';
import 'package:shopcook/features/barcode/product_lookup.dart';
import 'package:shopcook/features/home_widget/widget_snapshot.dart';
import 'package:shopcook/features/voice/spoken_list.dart';

void main() {
  group('splitSpokenList', () {
    test('commas and "and"', () {
      expect(splitSpokenList('milk, 2 kg potatoes and eggs'), [
        'milk',
        '2 kg potatoes',
        'eggs',
      ]);
    });

    test('Bulgarian joining words and a leading verb', () {
      expect(splitSpokenList('Купи мляко и хляб плюс 2 кг картофи'), [
        'мляко',
        'хляб',
        '2 кг картофи',
      ]);
    });

    test('a single item stays whole', () {
      expect(splitSpokenList('кисело мляко.'), ['кисело мляко']);
    });

    test('words that merely contain "и" are not split', () {
      expect(splitSpokenList('сирене'), ['сирене']);
      expect(splitSpokenList('ядки'), ['ядки']);
    });

    test('nothing said', () {
      expect(splitSpokenList('  '), isEmpty);
      expect(splitSpokenList('добави'), ['добави']);
    });
  });

  group('pickProductName', () {
    test('prefers the app language', () {
      expect(
        pickProductName({
          'product_name': 'Coca-Cola',
          'product_name_bg': 'Кока-Кола',
        }, 'bg'),
        'Кока-Кола',
      );
    });

    test('falls back to the plain name, then the generic one', () {
      expect(pickProductName({'product_name': 'Nutella'}, 'bg'), 'Nutella');
      expect(
        pickProductName({'product_name': ' ', 'generic_name': 'Хляб'}, 'bg'),
        'Хляб',
      );
      expect(pickProductName({}, 'bg'), isNull);
    });
  });

  group('ProductLookup', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('asks the network once, then remembers', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['User-Agent'], contains('ShopCook'));
        return http.Response.bytes(
          utf8.encode(
            '{"status":1,"product":{"product_name":"Coca-Cola",'
            '"product_name_bg":"Кока-Кола"}}',
          ),
          200,
        );
      });
      final lookup = ProductLookup(db, client);

      expect(await lookup.nameFor('5449000000996', language: 'bg'), 'Кока-Кола');
      expect(await lookup.nameFor('5449000000996', language: 'bg'), 'Кока-Кола');
      expect(calls, 1);
    });

    test('an unknown code returns null, and a typed name is kept', () async {
      final client = MockClient(
        (_) async => http.Response('{"status":0}', 200),
      );
      final lookup = ProductLookup(db, client);

      expect(await lookup.nameFor('3800048210034', language: 'bg'), isNull);
      await lookup.remember('3800048210034', ' Айрян ');
      expect(await lookup.nameFor('3800048210034', language: 'bg'), 'Айрян');
    });

    test('no connection is not an error', () async {
      final client = MockClient((_) async => throw Exception('offline'));
      final lookup = ProductLookup(db, client);
      expect(await lookup.nameFor('1', language: 'en'), isNull);
    });
  });

  group('pickWidgetSnapshot', () {
    final now = DateTime(2026, 9, 17);
    ShoppingList list(String id) =>
        ShoppingList(id: id, name: 'List $id', createdAt: now, userId: 'u');
    var n = 0;
    Product item(String listId, String name, {bool checked = false}) =>
        Product(
          id: 'p${n++}',
          listId: listId,
          name: name,
          quantity: name == 'Potatoes' ? '2' : '',
          unit: name == 'Potatoes' ? 'kg' : '',
          isChecked: checked,
          isStaple: false,
          createdAt: now.add(Duration(minutes: n)),
        );

    test('no lists', () {
      final snapshot = pickWidgetSnapshot(const [], const []);
      expect(snapshot.list, isNull);
    });

    test('shows the list with the most left to buy', () {
      final snapshot = pickWidgetSnapshot(
        [list('a'), list('b')],
        [
          item('a', 'Milk'),
          item('b', 'Potatoes'),
          item('b', 'Eggs'),
          item('b', 'Bread', checked: true),
        ],
      );
      expect(snapshot.list!.id, 'b');
      expect(snapshot.left, 2);
      expect(snapshot.lines, ['Potatoes · 2 kg', 'Eggs']);
      expect(snapshot.more, 0);
    });

    test('everything bought: the newest list, done', () {
      final snapshot = pickWidgetSnapshot(
        [list('a'), list('b')],
        [item('b', 'Milk', checked: true)],
      );
      expect(snapshot.list!.id, 'a');
      expect(snapshot.left, 0);
      expect(snapshot.lines, isEmpty);
    });

    test('long lists are cut, with a count of the rest', () {
      final snapshot = pickWidgetSnapshot(
        [list('a')],
        [for (var i = 0; i < 9; i++) item('a', 'Item $i')],
        maxLines: 6,
      );
      expect(snapshot.lines, hasLength(6));
      expect(snapshot.more, 3);
    });
  });
}
