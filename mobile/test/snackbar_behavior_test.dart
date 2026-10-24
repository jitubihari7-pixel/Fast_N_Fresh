import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwp_pos/core/theme/app_theme.dart';
import 'package:pwp_pos/core/widgets/latest_snackbar_messenger.dart';

Widget app() => MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => LatestSnackBarMessenger(child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              for (final label in ['first', 'second'])
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$label saved'))),
                  child: Text(label),
                ),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('a new snackbar replaces the current one instead of queueing',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    expect(find.text('first saved'), findsOneWidget);

    await tester.tap(find.text('second'));
    await tester.pumpAndSettle();
    expect(find.text('first saved'), findsNothing);
    expect(find.text('second saved'), findsOneWidget);

    // Nothing was queued behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('swiping a snackbar sideways dismisses it', (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('first'));
    await tester.pumpAndSettle();
    expect(find.text('first saved'), findsOneWidget);

    await tester.fling(find.byType(SnackBar), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
