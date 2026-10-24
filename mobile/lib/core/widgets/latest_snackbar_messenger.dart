import 'package:flutter/material.dart';

/// App-wide ScaffoldMessenger that shows only the latest SnackBar.
///
/// Flutter queues SnackBars: after several quick actions each message
/// waited its full duration in turn, and swiping one away just revealed the
/// next. Here a new SnackBar replaces the current one immediately.
class LatestSnackBarMessenger extends ScaffoldMessenger {
  const LatestSnackBarMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => LatestSnackBarMessengerState();
}

class LatestSnackBarMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    clearSnackBars();
    return super.showSnackBar(
      snackBar,
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }
}
