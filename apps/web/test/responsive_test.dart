import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zubix_web/widgets/dashboard_scaffold.dart';
import 'package:zubix_web/widgets/responsive.dart';

const _destinations = [
  DashboardDestination(Icons.dashboard_outlined, 'Dashboard'),
  DashboardDestination(Icons.event_outlined, 'Sessions'),
];

void _useViewport(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpScaffold(WidgetTester tester) {
  return tester.pumpWidget(
    MaterialApp(
      home: DashboardScaffold(
        destinations: _destinations,
        selectedIndex: 0,
        onSelect: (_) {},
        email: 'brand@example.com',
        onSignOut: () {},
        body: const Text('body'),
      ),
    ),
  );
}

void main() {
  testWidgets('phone width uses a bottom navigation bar', (tester) async {
    _useViewport(tester, const Size(375, 812));
    await _pumpScaffold(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop width uses a side navigation rail', (tester) async {
    _useViewport(tester, const Size(1280, 800));
    await _pumpScaffold(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TwoUp stacks its fields on narrow widths', (tester) async {
    _useViewport(tester, const Size(360, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TwoUp(first: Text('left'), second: Text('right')),
        ),
      ),
    );

    final left = tester.getTopLeft(find.text('left'));
    final right = tester.getTopLeft(find.text('right'));
    expect(right.dy, greaterThan(left.dy));
    expect(right.dx, left.dx);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TwoUp places its fields side by side on wide widths', (
    tester,
  ) async {
    _useViewport(tester, const Size(1024, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TwoUp(first: Text('left'), second: Text('right')),
        ),
      ),
    );

    final left = tester.getTopLeft(find.text('left'));
    final right = tester.getTopLeft(find.text('right'));
    expect(right.dx, greaterThan(left.dx));
    expect(right.dy, left.dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog content width shrinks to fit a phone screen', (
    tester,
  ) async {
    _useViewport(tester, const Size(360, 800));
    late double width;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            width = dialogContentWidth(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(width, lessThanOrEqualTo(360 - 140));
    expect(width, greaterThanOrEqualTo(200));
  });
}
