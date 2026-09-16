import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/recipes/ingredient_parser.dart';
import 'package:shopcook/features/shopping/category_label.dart';
import 'package:shopcook/features/shopping/product_category.dart';
import 'package:shopcook/l10n/app_localizations.dart';

/// Translating the UI is not the same as the app working in a language. These
/// cover the two places where Bulgarian input has to be understood rather
/// than merely displayed: the aisle sorter and the amount parser.
void main() {
  group('categorize, Bulgarian', () {
    test('files common staples by aisle', () {
      expect(categorize('Мляко'), ProductCategory.dairyAndEggs);
      expect(categorize('хляб'), ProductCategory.bakery);
      expect(categorize('Кайма'), ProductCategory.meatAndFish);
      expect(categorize('картофи'), ProductCategory.produce);
      expect(categorize('ориз'), ProductCategory.pantry);
      expect(categorize('Бира'), ProductCategory.drinks);
      expect(categorize('тоалетна хартия'), ProductCategory.household);
      expect(categorize('сладолед'), ProductCategory.frozen);
    });

    test('handles inflected endings, which is why stems are stored', () {
      // The keyword is "домат"; these are all forms of it.
      for (final name in ['домат', 'домати', 'доматен сос']) {
        expect(
          categorize(name),
          isNot(ProductCategory.other),
          reason: '"$name" should still reach an aisle',
        );
      }
      expect(categorize('ябълка'), ProductCategory.produce);
      expect(categorize('ябълки'), ProductCategory.produce);
    });

    test('is case insensitive across Cyrillic', () {
      expect(categorize('СИРЕНЕ'), ProductCategory.dairyAndEggs);
      expect(categorize('сирене'), ProductCategory.dairyAndEggs);
    });

    test('still sorts English names, because a list is not monolingual', () {
      expect(categorize('Halloumi'), isNotNull);
      expect(categorize('milk'), ProductCategory.dairyAndEggs);
      expect(categorize('мляко'), ProductCategory.dairyAndEggs);
    });

    test('falls back to other for something it does not know', () {
      expect(categorize('нещо непознато'), ProductCategory.other);
    });
  });

  group('parseIngredient, Bulgarian', () {
    test('splits an amount, a unit and a name', () {
      final parsed = parseIngredient('2 кг картофи');
      expect(parsed.quantity, '2');
      expect(parsed.unit, 'кг');
      expect(parsed.name, 'Картофи');
    });

    test('normalises unit spellings', () {
      expect(parseIngredient('500 грама брашно').unit, 'г');
      expect(parseIngredient('200 гр захар').unit, 'г');
      expect(parseIngredient('1 литър мляко').unit, 'л');
      expect(parseIngredient('250 мл сметана').unit, 'мл');
    });

    test('reads dotted spoon abbreviations', () {
      expect(parseIngredient('2 с.л. зехтин').unit, 'с.л.');
      expect(parseIngredient('1 ч.л. сол').unit, 'ч.л.');
      // Spaced and undotted forms reach the same place.
      expect(parseIngredient('3 с. л. оцет').unit, 'с.л.');
    });

    test('keeps a bare count without inventing a unit', () {
      final parsed = parseIngredient('3 яйца');
      expect(parsed.quantity, '3');
      expect(parsed.unit, '', reason: '"яйца" is the name, not a unit');
      expect(parsed.name, 'Яйца');
    });

    test('drops preparation notes', () {
      final onion = parseIngredient('1 глава лук, нарязан на кубчета');
      expect(onion.quantity, '1');
      expect(onion.unit, 'глава');
      expect(onion.name, 'Лук', reason: 'the note after the comma is not shopping info');

      expect(parseIngredient('2 моркова настъргани').name, 'Моркова');
    });

    test('keeps a product whose name starts with a preparation word', () {
      // "нарязани домати" is a thing you buy, so the cut must not happen at
      // the first word.
      expect(parseIngredient('400 г нарязани домати').name, 'Нарязани домати');
    });

    test('capitalises Cyrillic names', () {
      expect(parseIngredient('чесън').name, 'Чесън');
    });

    test('keeps a line it cannot split rather than losing it', () {
      final parsed = parseIngredient('щипка от нещо особено');
      expect(parsed.name, isNotEmpty);
    });
  });

  group('aisle headings', () {
    testWidgets('every category has a Bulgarian heading', (tester) async {
      late AppLocalizations bg;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              bg = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      for (final category in ProductCategory.values) {
        final heading = category.label(bg);
        expect(heading, isNotEmpty);
        expect(
          heading,
          matches(RegExp(r'[Ѐ-ӿ]')),
          reason: '${category.name} should be translated, got "$heading"',
        );
      }
    });
  });
}
