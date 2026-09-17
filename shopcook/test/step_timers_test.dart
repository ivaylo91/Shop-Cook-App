import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/features/cooking/step_timers.dart';

List<Duration> durations(String step) =>
    findStepTimers(step).map((t) => t.duration).toList();

void main() {
  group('findStepTimers', () {
    test('reads English minutes, hours and seconds', () {
      expect(durations('Simmer for 20 minutes.'), [
        const Duration(minutes: 20),
      ]);
      expect(durations('Bake 1 hour, then rest 10 mins'), [
        const Duration(hours: 1),
        const Duration(minutes: 10),
      ]);
      expect(durations('Blend for 30 seconds'), [const Duration(seconds: 30)]);
      expect(durations('Roast for 1.5 hrs'), [const Duration(minutes: 90)]);
    });

    test('reads Bulgarian units', () {
      expect(durations('Гответе около 40 минути под капак.'), [
        const Duration(minutes: 40),
      ]);
      expect(durations('Печете 1 час на 180 градуса.'), [
        const Duration(hours: 1),
      ]);
      expect(durations('Разбъркайте 30 секунди'), [
        const Duration(seconds: 30),
      ]);
      expect(durations('Варете 5 мин.'), [const Duration(minutes: 5)]);
    });

    test('times the lower end of a range and keeps the words', () {
      final timers = findStepTimers('къкри на тих огън 10-15 минути.');
      expect(timers.single.duration, const Duration(minutes: 10));
      expect(timers.single.label, '10-15 минути');

      expect(durations('cook for 1 to 2 minutes'), [
        const Duration(minutes: 1),
      ]);
    });

    test('ignores things that are not durations', () {
      // A teaspoon, a temperature, a count and a word starting with "мин".
      expect(durations('Добавете 1 ч. л. сол'), isEmpty);
      expect(durations('Heat the oven to 180 degrees'), isEmpty);
      expect(durations('подреждаме 2-3 ягоди'), isEmpty);
      expect(durations('оставете 2 минимум'), isEmpty);
    });

    test('drops repeats and anything longer than a day', () {
      expect(durations('Stir 5 minutes, then another 5 minutes'), [
        const Duration(minutes: 5),
      ]);
      expect(durations('Marinate for 48 hours'), isEmpty);
    });
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(
      formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 30)),
      '1:02:30',
    );
    expect(formatCountdown(const Duration(seconds: -3)), '0:00');
  });
}
