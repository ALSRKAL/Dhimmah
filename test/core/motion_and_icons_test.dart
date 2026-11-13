import 'dart:io';

import 'package:dhimmah/core/theme/app_spacing.dart';
import 'package:dhimmah/core/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two rules DESIGN.md states about icons and motion that a reviewer cannot
/// be relied on to spot in a diff: no screen names a Material icon directly,
/// and every piece of motion stops when the system asks for less of it.
void main() {
  group('icons', () {
    test('every icon is named in app_icons.dart, and nowhere else', () {
      final RegExp direct = RegExp(r'\bIcons\.[a-z_0-9]+');
      final List<String> offenders = <String>[
        for (final FileSystemEntity entity
            in Directory('lib').listSync(recursive: true))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !entity.path.endsWith('app_icons.dart') &&
              !entity.path.contains('/generated/') &&
              direct.hasMatch(entity.readAsStringSync()))
            entity.path,
      ];
      expect(
        offenders,
        isEmpty,
        reason: 'name the icon in lib/core/theme/app_icons.dart and use '
            'AppIcons.<name>: that file is the one place the family is chosen',
      );
    });
  });

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  double opacityOf(WidgetTester tester) =>
      tester.widget<Opacity>(find.byType(Opacity)).opacity;

  group('a row arriving', () {
    testWidgets('starts unseen and ends fully there', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const ArrivingRow(index: 0, child: Text('row'))),
      );
      expect(opacityOf(tester), 0);

      await tester.pumpAndSettle();
      expect(opacityOf(tester), 1);
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('a later row waits for the ones above it',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: <Widget>[
              ArrivingRow(index: 0, child: Text('first')),
              ArrivingRow(index: 5, child: Text('sixth')),
            ],
          ),
        ),
      );
      // Part way into the first row's arrival the sixth has not started.
      await tester.pump(ArrivingRow.stagger * 3);
      final List<double> seen = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((Opacity o) => o.opacity)
          .toList();
      expect(seen.first, greaterThan(0));
      expect(seen.last, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('tells the list when it has arrived', (WidgetTester tester) async {
      int arrived = 0;
      await tester.pumpWidget(
        host(
          ArrivingRow(
            index: 2,
            onArrived: () => arrived++,
            child: const Text('row'),
          ),
        ),
      );
      expect(arrived, 0);
      await tester.pumpAndSettle();
      expect(arrived, 1, reason: 'once, which is how a list knows to stop');
    });

    testWidgets('rows far down the list do not move at all',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const ArrivingRow(index: ArrivingRow.maxRows, child: Text('row')),
        ),
      );
      // Nobody waits for row forty.
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('row'), findsOneWidget);
    });

    testWidgets('a list that has already arrived does not arrive again',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const ArrivingRow(index: 0, animate: false, child: Text('row'))),
      );
      expect(find.byType(Opacity), findsNothing);
    });

    testWidgets('with "remove animations" on, it is simply there',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          const ArrivingRow(index: 0, child: Text('row')),
          reduceMotion: true,
        ),
      );
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('row'), findsOneWidget);
    });
  });

  group('the settled tick', () {
    testWidgets('draws itself once and stops', (WidgetTester tester) async {
      await tester.pumpWidget(host(const DrawnTick(color: Colors.green)));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'nothing in the app loops',
      );
    });

    testWidgets('with "remove animations" on, nothing runs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        host(const DrawnTick(color: Colors.green), reduceMotion: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('durations', () {
    testWidgets('are zero when the system asks for less motion',
        (WidgetTester tester) async {
      late Duration normal;
      late Duration reduced;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) {
              normal = AppMotion.of(context, AppMotion.slow);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) {
              reduced = AppMotion.of(context, AppMotion.slow);
              return const SizedBox.shrink();
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(normal, AppMotion.slow);
      expect(reduced, Duration.zero);
    });
  });
}
