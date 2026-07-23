import 'dart:convert';

import 'package:wiro_ai/src/model/wiro_json.dart';

final class JsonReader {
  const JsonReader._();

  static String? string(Object? value) {
    return switch (value) {
      final String text when text.isNotEmpty => text,
      final num number => '$number',
      _ => null,
    };
  }

  static bool boolean(Object? value, {bool fallback = false}) {
    return switch (value) {
      final bool result => result,
      1 || '1' || 'true' => true,
      0 || '0' || 'false' => false,
      _ => fallback,
    };
  }

  static int integer(Object? value, {int fallback = 0}) {
    return switch (value) {
      final int number => number,
      final num number => number.toInt(),
      final String text => int.tryParse(text) ?? fallback,
      _ => fallback,
    };
  }

  static double? decimal(Object? value) {
    return switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };
  }

  static WiroJson map(Object? value) {
    if (value case final Map<Object?, Object?> source) {
      return Map.unmodifiable(
        source.map((key, value) => MapEntry('$key', value)),
      );
    }

    if (value case final String text when text.isNotEmpty) {
      try {
        return map(jsonDecode(text));
      } on FormatException {
        return const {};
      }
    }

    return const {};
  }

  static List<Object?> list(Object? value) {
    return switch (value) {
      final List<Object?> values => List.unmodifiable(values),
      _ => const [],
    };
  }

  static List<String> stringList(Object? value) {
    return List.unmodifiable(list(value).map(string).whereType<String>());
  }

  static Uri? uri(Object? value) {
    final text = string(value);
    return text == null ? null : Uri.tryParse(text);
  }
}
