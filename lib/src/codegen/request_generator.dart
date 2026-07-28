/// Generates typed `WiroModelRequest` source files from live model
/// schemas. Used by the `wiro_client:generate` command line tool; not
/// part of the public SDK API.
library;

import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_model.dart';

/// Generates a complete Dart source file containing a typed request
/// class (and its enums) for the model described by [schema].
String generateRequestSource({
  required WiroModelSchema schema,
  required WiroModelId modelId,
  DateTime? generatedAt,
}) {
  final date = (generatedAt ?? DateTime.now()).toIso8601String().split('T')[0];
  final classPrefix = 'Wiro${_pascalFromSlug(modelId.project)}';
  final className = '${classPrefix}Request';

  final fields = <_FieldPlan>[];
  final skipped = <String>[];
  for (final parameter in schema.parameters) {
    final plan = _planField(parameter, classPrefix);
    if (plan == null) {
      skipped.add('${parameter.id} (unsupported type)');
    } else {
      fields.add(plan);
    }
  }
  // Required fields first, preserving schema order within each group.
  final ordered = [
    ...fields.where((field) => field.isRequired),
    ...fields.where((field) => !field.isRequired),
  ];

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - do not edit by hand.')
    ..writeln('//')
    ..writeln('// Model: ${modelId.value}')
    ..writeln('// Schema snapshot: $date')
    ..writeln('// Regenerate: dart run tool/generate.dart ${modelId.value}')
    ..writeln(_skippedComment(skipped))
    ..writeln("import 'package:wiro_client/wiro_client.dart';")
    ..writeln();

  for (final field in ordered) {
    final enumPlan = field.enumPlan;
    if (enumPlan != null) {
      _writeEnum(buffer, enumPlan, className);
      buffer.writeln();
    }
  }

  _writeClass(
    buffer,
    schema: schema,
    modelId: modelId,
    className: className,
    fields: ordered,
    date: date,
  );

  return buffer.toString();
}

String _skippedComment(List<String> skipped) {
  if (skipped.isEmpty) {
    return '';
  }
  return '// Skipped parameters: ${skipped.join(', ')}\n';
}

// ---------------------------------------------------------------------
// Field planning
// ---------------------------------------------------------------------

enum _FieldKind {
  text,
  number,
  file,
  enumValue,
  boolTrueFalse,
  boolOnOff,
  intSelect,
}

final class _EnumPlan {
  const _EnumPlan({
    required this.name,
    required this.members,
    required this.label,
  });

  final String name;
  final String label;
  final List<({String name, String value, String doc})> members;
}

final class _FieldPlan {
  const _FieldPlan({
    required this.kind,
    required this.name,
    required this.jsonKey,
    required this.isRequired,
    required this.docLines,
    this.enumPlan,
    this.allowedInts,
    this.minimum,
    this.maximum,
    this.isDouble = false,
  });

  final _FieldKind kind;
  final String name;
  final String jsonKey;
  final bool isRequired;
  final List<String> docLines;
  final _EnumPlan? enumPlan;
  final List<int>? allowedInts;
  final num? minimum;
  final num? maximum;
  final bool isDouble;

  String get dartType {
    final base = switch (kind) {
      _FieldKind.text => 'String',
      _FieldKind.number => isDouble ? 'double' : 'int',
      _FieldKind.file => 'List<WiroFileInput>',
      _FieldKind.enumValue => enumPlan!.name,
      _FieldKind.boolTrueFalse || _FieldKind.boolOnOff => 'bool',
      _FieldKind.intSelect => 'int',
    };
    return isRequired ? base : '$base?';
  }
}

_FieldPlan? _planField(WiroModelParameter parameter, String classPrefix) {
  final name = _identifierFromId(parameter.id);
  final docLines = _docLines(parameter);

  switch (parameter) {
    case WiroSelectParameter(:final options):
      final values = options
          .map((option) => option.value)
          .where((value) => value.isNotEmpty)
          .toList();
      if (values.isEmpty) {
        return _FieldPlan(
          kind: _FieldKind.text,
          name: name,
          jsonKey: parameter.id,
          isRequired: parameter.isRequired,
          docLines: docLines,
        );
      }
      final valueSet = values.toSet();
      if (valueSet.length == 2 && valueSet.containsAll({'true', 'false'})) {
        return _FieldPlan(
          kind: _FieldKind.boolTrueFalse,
          name: name,
          jsonKey: parameter.id,
          isRequired: parameter.isRequired,
          docLines: docLines,
        );
      }
      if (valueSet.length == 2 && valueSet.containsAll({'on', 'off'})) {
        return _FieldPlan(
          kind: _FieldKind.boolOnOff,
          name: name,
          jsonKey: parameter.id,
          isRequired: parameter.isRequired,
          docLines: docLines,
        );
      }
      final asInts = values.map(int.tryParse).toList();
      if (asInts.every((value) => value != null)) {
        return _FieldPlan(
          kind: _FieldKind.intSelect,
          name: name,
          jsonKey: parameter.id,
          isRequired: parameter.isRequired,
          docLines: docLines,
          allowedInts: asInts.cast<int>(),
        );
      }
      return _FieldPlan(
        kind: _FieldKind.enumValue,
        name: name,
        jsonKey: parameter.id,
        isRequired: parameter.isRequired,
        docLines: docLines,
        enumPlan: _planEnum(parameter, options, classPrefix, name),
      );
    case WiroNumberParameter(
      :final minimum,
      :final maximum,
      :final step,
      :final defaultValue,
    ):
      final isDouble = [
        minimum,
        maximum,
        step,
        defaultValue,
      ].whereType<double>().any((value) => value != value.roundToDouble());
      return _FieldPlan(
        kind: _FieldKind.number,
        name: name,
        jsonKey: parameter.id,
        isRequired: parameter.isRequired,
        docLines: docLines,
        minimum: minimum,
        maximum: maximum,
        isDouble: isDouble,
      );
    case WiroTextParameter():
      return _FieldPlan(
        kind: _FieldKind.text,
        name: name,
        jsonKey: parameter.id,
        isRequired: parameter.isRequired,
        docLines: docLines,
      );
    case WiroFileParameter():
      return _FieldPlan(
        kind: _FieldKind.file,
        name: name,
        jsonKey: parameter.id,
        isRequired: parameter.isRequired,
        docLines: docLines,
      );
    case WiroUnknownParameter():
      return null;
  }
}

_EnumPlan _planEnum(
  WiroSelectParameter parameter,
  List<WiroModelParameterOption> options,
  String classPrefix,
  String fieldName,
) {
  final enumName = '$classPrefix${_capitalize(fieldName)}';
  final used = <String>{};
  final members = <({String name, String value, String doc})>[];
  for (final option in options) {
    if (option.value.isEmpty) {
      continue;
    }
    var memberName = _enumMemberName(option.value);
    var suffix = 2;
    while (!used.add(memberName)) {
      memberName = '${_enumMemberName(option.value)}$suffix';
      suffix += 1;
    }
    final doc = option.label.isNotEmpty && option.label != option.value
        ? option.label
        : 'Wire value `${option.value}`.';
    members.add((name: memberName, value: option.value, doc: doc));
  }
  final label = parameter.label.isNotEmpty ? parameter.label : fieldName;
  return _EnumPlan(name: enumName, members: members, label: label);
}

// ---------------------------------------------------------------------
// Emission
// ---------------------------------------------------------------------

void _writeEnum(StringBuffer buffer, _EnumPlan plan, String className) {
  buffer
    ..writeln('/// ${plan.label} accepted by [$className].')
    ..writeln('enum ${plan.name} {');
  for (final (index, member) in plan.members.indexed) {
    buffer
      ..writeln('  /// ${member.doc}')
      ..write("  ${member.name}('${_escape(member.value)}')")
      ..writeln(index == plan.members.length - 1 ? ';' : ',')
      ..writeln();
  }
  buffer
    ..writeln('  /// Creates a value with its Wiro wire value.')
    ..writeln('  const ${plan.name}(this.apiValue);')
    ..writeln()
    ..writeln('  /// Value sent to the Wiro API.')
    ..writeln('  final String apiValue;')
    ..writeln('}');
}

void _writeClass(
  StringBuffer buffer, {
  required WiroModelSchema schema,
  required WiroModelId modelId,
  required String className,
  required List<_FieldPlan> fields,
  required String date,
}) {
  final title = schema.model.title;
  buffer
    ..writeln('/// Typed request for the `${modelId.value}` model.')
    ..writeln('///');
  if (title != null && title.isNotEmpty) {
    for (final line in _wrap(title, 73)) {
      buffer.writeln('/// $line');
    }
    buffer.writeln('///');
  }
  // Class doc and constructor.
  buffer
    ..writeln('/// Generated from the live Wiro schema on $date.')
    ..writeln('final class $className implements WiroModelRequest {')
    ..writeln('  /// Creates a `${modelId.value}` request.')
    ..writeln('  const $className({');
  for (final field in fields) {
    buffer.writeln(
      field.isRequired
          ? '    required this.${field.name},'
          : '    this.${field.name},',
    );
  }
  final asserts = fields.expand(_assertsFor).toList();
  if (asserts.isEmpty) {
    buffer.writeln('  });');
  } else {
    buffer
      ..write('  }) : ')
      ..write(asserts.join(',\n       '))
      ..writeln(';');
  }

  // Fields.
  for (final field in fields) {
    buffer.writeln();
    for (final line in field.docLines) {
      buffer.writeln('  /// $line');
    }
    buffer.writeln('  final ${field.dartType} ${field.name};');
  }

  // Model getter.
  buffer
    ..writeln()
    ..writeln('  @override')
    ..writeln(
      '  WiroModelId get model =>\n'
      "      WiroModelId('${modelId.owner}', '${modelId.project}');",
    )
    ..writeln();

  // toJson.
  final hasOptional = fields.any((field) => !field.isRequired);
  buffer
    ..writeln('  @override')
    ..writeln('  WiroJson toJson() {')
    ..writeln('    return <String, Object?>{');
  for (final field in fields) {
    buffer.writeln("      '${field.jsonKey}': ${_jsonValue(field)},");
  }
  buffer.write('    }');
  if (hasOptional) {
    buffer.write('..removeWhere((key, value) => value == null)');
  }
  buffer
    ..writeln(';')
    ..writeln('  }')
    ..writeln('}');
}

List<String> _assertsFor(_FieldPlan field) {
  final name = field.name;
  switch (field.kind) {
    case _FieldKind.text:
      if (!field.isRequired) {
        return const [];
      }
      return ["assert($name != '', '$name cannot be empty')"];
    case _FieldKind.number:
      final checks = <String>[
        if (field.minimum != null) '$name >= ${_num(field.minimum!)}',
        if (field.maximum != null) '$name <= ${_num(field.maximum!)}',
      ];
      if (checks.isEmpty) {
        return const [];
      }
      final bounds = checks.join(' && ');
      final condition = field.isRequired
          ? bounds
          : '$name == null || ($bounds)';
      final range = [
        if (field.minimum != null) 'at least ${_num(field.minimum!)}',
        if (field.maximum != null) 'at most ${_num(field.maximum!)}',
      ].join(' and ');
      final numberAssert =
          'assert(\n'
          '         $condition,\n'
          "         '$name must be $range',\n"
          '       )';
      return [numberAssert];
    case _FieldKind.intSelect:
      final allowed = field.allowedInts!;
      final comparison = allowed.map((value) => '$name == $value').join(' || ');
      final condition = field.isRequired
          ? comparison
          : '$name == null || $comparison';
      final selectAssert =
          'assert(\n'
          '         $condition,\n'
          "         '$name must be one of: ${allowed.join(', ')}',\n"
          '       )';
      return [selectAssert];
    case _FieldKind.file ||
        _FieldKind.enumValue ||
        _FieldKind.boolTrueFalse ||
        _FieldKind.boolOnOff:
      return const [];
  }
}

String _jsonValue(_FieldPlan field) {
  final name = field.name;
  return switch (field.kind) {
    _FieldKind.text || _FieldKind.number => name,
    _FieldKind.enumValue =>
      field.isRequired ? '$name.apiValue' : '$name?.apiValue',
    _FieldKind.boolTrueFalse =>
      field.isRequired ? "'\$$name'" : "$name == null ? null : '\$$name'",
    _FieldKind.boolOnOff =>
      field.isRequired
          ? "$name ? 'on' : 'off'"
          : "$name == null ? null : ($name! ? 'on' : 'off')",
    _FieldKind.intSelect =>
      field.isRequired ? "'\$$name'" : "$name == null ? null : '\$$name'",
    _FieldKind.file =>
      field.isRequired
          ? '$name.map((file) => file.wireValue).toList()'
          : '$name?.map((file) => file.wireValue).toList()',
  };
}

// ---------------------------------------------------------------------
// Naming and text helpers
// ---------------------------------------------------------------------

const _reservedWords = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
};

String _pascalFromSlug(String slug) {
  return slug
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .map(_capitalize)
      .join();
}

String _identifierFromId(String id) {
  final parts = id
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'value';
  }
  final name =
      parts.first[0].toLowerCase() +
      parts.first.substring(1) +
      parts.skip(1).map(_capitalize).join();
  return _reservedWords.contains(name) ? '${name}Value' : name;
}

String _enumMemberName(String value) {
  var name = value.trim();
  if (RegExp(r'^[A-Z0-9_]+$').hasMatch(name) && name.contains('_')) {
    final parts = name.toLowerCase().split('_');
    name = parts.first + parts.skip(1).map(_capitalize).join();
  } else {
    name = name.replaceAll(':', 'x').replaceAll('.', '_');
    final parts = name
        .split(RegExp('[^A-Za-z0-9_]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'empty';
    }
    name = parts.first + parts.skip(1).map(_capitalize).join();
    final segments = name.split('_');
    if (segments.every((s) => s.isNotEmpty && !RegExp('[0-9]').hasMatch(s))) {
      name = segments.first + segments.skip(1).map(_capitalize).join();
    }
    final first = name[0];
    name = first.toLowerCase() + name.substring(1);
  }
  if (RegExp('^[0-9]').hasMatch(name)) {
    name = 'v$name';
  }
  return _reservedWords.contains(name) ? '${name}Value' : name;
}

List<String> _docLines(WiroModelParameter parameter) {
  final text = [
    parameter.description ?? parameter.label,
    if (parameter.note != null && parameter.note!.isNotEmpty) parameter.note!,
  ].join(' ').trim();
  final fallback = text.isEmpty ? parameter.id : text;
  return _wrap(fallback, 73);
}

List<String> _wrap(String text, int width) {
  final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  final lines = <String>[];
  var current = StringBuffer();
  for (final word in words) {
    if (current.isNotEmpty && current.length + 1 + word.length > width) {
      lines.add(current.toString());
      current = StringBuffer();
    }
    if (current.isNotEmpty) {
      current.write(' ');
    }
    current.write(word);
  }
  if (current.isNotEmpty) {
    lines.add(current.toString());
  }
  return lines.isEmpty ? const [''] : lines;
}

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _escape(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
}

String _num(num value) {
  if (value is double && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}
