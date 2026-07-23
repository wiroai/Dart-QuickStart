import 'package:flutter/widgets.dart';

/// Responsive size shortcuts used by example widgets.
extension MediaQueryExtension on BuildContext {
  /// Current viewport width.
  double get width => MediaQuery.sizeOf(this).width;

  /// Current viewport height.
  double get height => MediaQuery.sizeOf(this).height;

  /// Scales [value] against a 390 logical-pixel design width.
  double dynamicWidth(double value) => width * value / 390;

  /// Scales [value] against an 844 logical-pixel design height.
  double dynamicHeight(double value) => height * value / 844;
}
