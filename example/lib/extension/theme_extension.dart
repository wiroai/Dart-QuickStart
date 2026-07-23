import 'package:flutter/material.dart';

/// Theme shortcuts used by example widgets.
extension ThemeExtension on BuildContext {
  /// Active material theme.
  ThemeData get theme => Theme.of(this);

  /// Active text theme.
  TextTheme get textTheme => theme.textTheme;

  /// Active color scheme.
  ColorScheme get colorScheme => theme.colorScheme;
}
