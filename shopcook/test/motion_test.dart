import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopcook/core/design.dart';
import 'package:shopcook/core/theme.dart';
import 'package:shopcook/core/ui/ui.dart';
import 'package:shopcook/l10n/app_localizations.dart';

/// Built once: a fresh theme on every pump would make MaterialApp animate
/// between them, and that is not the animation under test.
final _theme = buildAppTheme(Brightness.light);

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: _theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      // A list, as in the app: the card takes the height of its rows.
      child: Scaffold(body: ListView(children: [child])),
    ),
  ),
);

Widget _row(String name) =>
    SizedBox(key: ValueKey(name), height: 48, child: Text(name));

double _opacityOf(WidgetTester tester, String name) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(name), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  group('AppCardList', () {
    testWidgets('rows there at first load do not fade in', (tester) async {
      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk'), _row('Bread')])),
      );

      expect(_opacityOf(tester, 'Milk'), 1);
      expect(_opacityOf(tester, 'Bread'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a row that arrives fades in, and the rest stay put', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AppCardList(children: [_row('Milk')])));
      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk'), _row('Tea')])),
      );

      expect(_opacityOf(tester, 'Tea'), 0);
      expect(_opacityOf(tester, 'Milk'), 1);

      await tester.pump(Motion.fast ~/ 2);
      expect(_opacityOf(tester, 'Tea'), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, 'Tea'), 1);
    });

    testWidgets('an unrelated rebuild does not restart a row’s fade', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AppCardList(children: [_row('Milk')])));
      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk'), _row('Tea')])),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk'), _row('Tea')])),
      );
      expect(_opacityOf(tester, 'Tea'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the card grows to fit an arriving row, over time', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AppCardList(children: [_row('Milk')])));
      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk'), _row('Tea')])),
      );
      await tester.pump();
      await tester.pump(Motion.base ~/ 4);

      final height = tester.getSize(find.byType(AnimatedSize)).height;
      expect(height, inExclusiveRange(48, 97));

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(AnimatedSize)).height, 97);
    });

    testWidgets('with motion reduced the card does not animate its size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppCardList(children: [_row('Milk')]), reduceMotion: true),
      );
      await tester.pumpWidget(
        _host(
          AppCardList(children: [_row('Milk'), _row('Tea')]),
          reduceMotion: true,
        ),
      );
      await tester.pump();

      // Two rows and their divider, at once: no resize in progress.
      expect(find.byType(AnimatedSize), findsNothing);
      expect(tester.getSize(find.byType(AppCardList)).height, 97);
      // The arriving row still fades; that is not movement.
      expect(_opacityOf(tester, 'Tea'), lessThan(1));
    });
  });

  group('AppCard press', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('a tappable card gives while pressed and springs back', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppCard(onTap: () => taps++, child: const Text('Weekly'))),
      );
      expect(scaleOf(tester), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Weekly')),
      );
      // The ink waits a moment before calling a touch a press, so that the
      // start of a scroll does not count.
      await tester.pump(const Duration(milliseconds: 200));
      expect(scaleOf(tester), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1);
      expect(taps, 1);
    });

    testWidgets('a card that cannot be tapped does not scale', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: Text('Totals'))));
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('with motion reduced a pressed card stays put', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCard(onTap: () {}, child: const Text('Weekly')),
          reduceMotion: true,
        ),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });
  });

  group('PressScale', () {
    double scaleOf(WidgetTester tester) =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    testWidgets('a button gives while pressed, and still fires', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PressScale(
            child: FilledButton(
              onPressed: () => taps++,
              child: const Text('Save'),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Save')),
      );
      await tester.pump();
      expect(scaleOf(tester), lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1);
      expect(taps, 1);
    });

    testWidgets('a disabled button does not give', (tester) async {
      await tester.pumpWidget(
        _host(
          const PressScale(
            child: FilledButton(onPressed: null, child: Text('Save')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Save')),
      );
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
    });

    testWidgets('a finger that starts scrolling lets the button go', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PressScale(
            child: FilledButton(onPressed: () {}, child: const Text('Save')),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Save')),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(scaleOf(tester), 1);
      await gesture.up();
    });
  });

  group('showAppDialog', () {
    testWidgets('arrives scaled from just under full size, then settles, and '
        'returns what it was closed with', (tester) async {
      String? result;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAppDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'yes'),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final scale = tester.widget<ScaleTransition>(
        find
            .ancestor(
              of: find.text('Sure?'),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      expect(scale.scale.value, inInclusiveRange(0.95, 1.0));
      expect(scale.scale.value, lessThan(1));

      await tester.pumpAndSettle();
      expect(scale.scale.value, 1);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(result, 'yes');
      expect(find.text('Sure?'), findsNothing);
    });
  });

  test('pages change in the base duration, not the platform’s 450ms', () {
    expect(const AppPageTransitions().transitionDuration, Motion.base);
    expect(Motion.base, lessThan(const Duration(milliseconds: 300)));
  });

  group('AppProgressBar', () {
    double value(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;

    testWidgets('is drawn at its value, not filled from empty', (tester) async {
      await tester.pumpWidget(_host(const AppProgressBar(done: 3, total: 4)));

      expect(value(tester), 0.75);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('advances from where it was when an item is ticked', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppProgressBar(done: 1, total: 4)));
      await tester.pumpWidget(_host(const AppProgressBar(done: 2, total: 4)));

      await tester.pump(Motion.base ~/ 2);
      expect(value(tester), inExclusiveRange(0.25, 0.5));

      await tester.pumpAndSettle();
      expect(value(tester), 0.5);
    });
  });

  test('entrances use the strong ease-out, and nothing eases in', () {
    // cubic-bezier(0.23, 1, 0.32, 1)
    expect(Motion.enter, Curves.easeOutQuint);
    // Well past halfway a fifth of the way in: fast when it is watched.
    expect(Motion.enter.transform(0.2), greaterThan(0.6));
  });
}
