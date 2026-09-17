import 'package:flutter/material.dart';

extension ReplaceSnackBar on ScaffoldMessengerState {
  /// Shows [snackBar] in place of whatever is showing now.
  ///
  /// Flutter queues snack bars, so deleting three items quickly used to
  /// show "Potatoes removed" long after Potatoes was gone and the user had
  /// moved on. The newest message is the only one worth reading.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> replaceSnackBar(
    SnackBar snackBar,
  ) {
    hideCurrentSnackBar();
    return showSnackBar(snackBar);
  }
}
