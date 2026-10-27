import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pwp_pos/providers/cart_provider.dart';
import 'package:pwp_pos/providers/catalog_provider.dart';
import 'package:pwp_pos/screens/pos/counter_slots_screen.dart';
import 'package:pwp_pos/screens/pos/direct_order_screen.dart';

/// Android back on the Takeaway counters and a counter's menu goes back one
/// page at a time and never closes the app.
void main() {
  testWidgets('system back walks back through counters, never exits', (tester) async {
    final exits = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call);
      return null;
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ],
        child: MaterialApp(
          // Like the main shell: the root page itself never pops.
          home: PopScope(
            canPop: false,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CounterSlotsScreen(orderType: 'takeaway')),
                    ),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home'));
    await settle(tester);
    for (final slot in ['T1', 'T2', 'T3', 'T4']) {
      expect(find.text(slot), findsOneWidget);
    }

    await tester.tap(find.text('T2'));
    await settle(tester);
    expect(find.byType(DirectOrderScreen), findsOneWidget);
    expect(find.text('Takeaway · T2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(DirectOrderScreen), findsNothing);
    expect(find.byType(CounterSlotsScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(CounterSlotsScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(exits, isEmpty);
  });

  testWidgets('counters show as Available with no running orders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CounterSlotsScreen(orderType: 'delivery')));
    await settle(tester);
    for (final slot in ['D1', 'D2', 'D3', 'D4']) {
      expect(find.text(slot), findsOneWidget);
    }
    expect(find.text('Available'), findsNWidgets(4));
    expect(find.text('Start Order'), findsNWidgets(4));
  });

  testWidgets('counter cards fit a small phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.3)),
        child: CounterSlotsScreen(orderType: 'takeaway'),
      ),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}

/// Network calls never finish in widget tests and the loading bar keeps
/// animating, so pump through page transitions instead of pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
