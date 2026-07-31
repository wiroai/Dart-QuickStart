// Internal parsing helpers are not part of the exported public API.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:convert';

import 'package:wiro_client/src/model/wiro_json.dart';

const _malformedJsonHandlerKey = Object();

final class JsonReader {
  const JsonReader._();

  static T runWithMalformedJsonHandler<T>(
    WiroMalformedJsonCallback onError,
    T Function() action,
  ) {
    return runZoned(action, zoneValues: {_malformedJsonHandlerKey: onError});
  }

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
    return integerOrNull(value) ?? fallback;
  }

  static int? integerOrNull(Object? value) {
    return switch (value) {
      final int number => number,
      final num number => number.toInt(),
      final String text => int.tryParse(text),
      _ => null,
    };
  }

  static double? decimal(Object? value) {
    return switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text),
      _ => null,
    };
  }

  static DateTime? dateTime(Object? value) {
    if (value case final DateTime dateTime) {
      return dateTime;
    }
    final text = string(value);
    if (text == null) {
      return null;
    }
    final epoch = int.tryParse(text);
    if (epoch != null && RegExp(r'^-?\d{10,13}$').hasMatch(text)) {
      final milliseconds = epoch.abs() >= 100000000000 ? epoch : epoch * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }
    return DateTime.tryParse(text);
  }

  static WiroJson map(Object? value, {WiroMalformedJsonCallback? onError}) {
    if (value case final Map<Object?, Object?> source) {
      return Map.unmodifiable(
        source.map((key, value) => MapEntry('$key', value)),
      );
    }

    if (value case final String text when text.isNotEmpty) {
      try {
        return map(jsonDecode(text), onError: onError);
      } on FormatException catch (error) {
        final zoneHandler =
            Zone.current[_malformedJsonHandlerKey]
                as WiroMalformedJsonCallback?;
        (onError ?? zoneHandler)?.call(text, error);
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
