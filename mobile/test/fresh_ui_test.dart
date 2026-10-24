import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwp_pos/core/widgets/fresh_ui.dart';

/// Lays [child] out at [width] with an enlarged system font, the two things
/// that most often cause RenderFlex overflows on small cafe phones. Any
/// overflow is reported by the framework as a test failure.
Future<void> pumpAt(WidgetTester tester, double width, Widget child,
    {double textScale = 1.3}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FreshGradientButton', () {
    for (final width in [130.0, 158.0, 200.0, 360.0]) {
      testWidgets('fits at ${width.toInt()}dp', (tester) async {
        await pumpAt(
          tester,
          width,
          FreshGradientButton(
            label: 'Start Order',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () {},
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Start Order'), findsOneWidget);
      });
    }

    testWidgets('hides chevron when compact', (tester) async {
      await pumpAt(
        tester,
        150,
        FreshGradientButton(
            label: 'View Order', icon: Icons.visibility, onPressed: () {}),
        textScale: 1,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await pumpAt(
        tester,
        320,
        FreshGradientButton(
            label: 'View Order', icon: Icons.visibility, onPressed: () {}),
        textScale: 1,
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });

  group('FreshHeader', () {
    for (final width in [320.0, 360.0]) {
      testWidgets('title, subtitle and two actions fit at ${width.toInt()}dp',
          (tester) async {
        await pumpAt(
          tester,
          width,
          FreshHeader(
            title: 'Orders',
            subtitle: 'Manage customer orders & table status',
            icon: Icons.local_cafe_outlined,
            actions: [
              FreshHeaderAction(
                  icon: Icons.search, tooltip: 'Search', onPressed: () {}),
              FreshHeaderAction(
                  icon: Icons.qr_code, tooltip: 'QR', onPressed: () {}),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('long back-arrow title fits at 320dp', (tester) async {
      await pumpAt(
        tester,
        320,
        const FreshHeader(
          title: 'QR Management',
          subtitle: 'Manage table QR codes',
          showBack: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('FreshCircleIconButton renders', (tester) async {
    await pumpAt(
      tester,
      100,
      FreshCircleIconButton(
          icon: Icons.edit, tooltip: 'Edit', onPressed: () {}),
    );
    expect(tester.takeException(), isNull);
  });
}
