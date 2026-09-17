import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/share_intake/shared_content.dart';

void main() {
  group('links', () {
    test('a browser share: URL as text, title as subject', () {
      final shared = parseShared(
        'https://www.bonapeti.bg/recepti/chili-kon-karne/',
        subject: 'Чили кон карне - Bonapeti.bg',
      );
      expect(shared, isA<SharedLink>());
      shared as SharedLink;
      expect(shared.url, 'https://www.bonapeti.bg/recepti/chili-kon-karne/');
      expect(shared.title, 'Чили кон карне - Bonapeti.bg');
    });

    test('a YouTube share: title and URL in the text', () {
      final shared =
          parseShared('Easy Pancakes Recipe https://youtu.be/abc123') as SharedLink;
      expect(shared.url, 'https://youtu.be/abc123');
      expect(shared.title, 'Easy Pancakes Recipe');
    });

    test('a link at the end of a sentence loses the full stop', () {
      final shared =
          parseShared('Try this: https://example.com/soup.') as SharedLink;
      expect(shared.url, 'https://example.com/soup');
      expect(shared.title, 'Try this');
    });

    test('a long message around a link gives no title', () {
      final shared = parseShared(
        '${'word ' * 40}https://example.com/soup',
      ) as SharedLink;
      expect(shared.title, isEmpty);
    });
  });

  group('items', () {
    test('a notes-app checklist becomes clean lines', () {
      final shared = parseShared('''
За пазара:
- [ ] 2 кг картофи
- [x] мляко
• хляб

1. eggs
☐ butter
''') as SharedItems;
      expect(shared.lines, ['2 кг картофи', 'мляко', 'хляб', 'eggs', 'butter']);
    });

    test('Windows line endings', () {
      final shared = parseShared('milk\r\nbread') as SharedItems;
      expect(shared.lines, ['milk', 'bread']);
    });

    test('a very long paste is capped', () {
      final shared = parseShared(List.filled(300, 'x').join('\n')) as SharedItems;
      expect(shared.lines, hasLength(100));
    });
  });

  test('nothing usable', () {
    expect(parseShared(''), isNull);
    expect(parseShared('   \n  '), isNull);
    expect(parseShared('- \n* \nHeading:'), isNull);
  });
}
