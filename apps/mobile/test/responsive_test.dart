import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zubix_mobile/widgets/centered_content.dart';

void _useViewport(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<double> _childWidth(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: CenteredContent(child: SizedBox.expand(key: ValueKey('content'))),
      ),
    ),
  );
  return tester.getSize(find.byKey(const ValueKey('content'))).width;
}

void main() {
  testWidgets('phone width fills the screen', (tester) async {
    _useViewport(tester, const Size(390, 844));
    expect(await _childWidth(tester), 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet width is capped at 640', (tester) async {
    _useViewport(tester, const Size(1024, 1366));
    expect(await _childWidth(tester), 640);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web width is capped at 640', (tester) async {
    _useViewport(tester, const Size(1440, 900));
    expect(await _childWidth(tester), 640);
    expect(tester.takeException(), isNull);
  });
}
