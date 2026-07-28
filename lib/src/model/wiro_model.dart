import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_identifier.dart';
import 'package:wiro_client/src/model/wiro_json.dart';
import 'package:wiro_client/src/wiro_exception.dart';

/// Field used to sort Wiro model search results.
///
/// Wire values were verified against the Wiro MCP `search_models` input
/// schema on 2026-07-24.
enum WiroModelSort {
  /// Sorts by search relevance.
  relevance('relevance'),

  /// Sorts by publication time.
  time('time'),

  /// Sorts by the number of user ratings.
  ratedUserCount('ratedusercount'),

  /// Sorts by the number of comments.
  commentCount('commentcount'),

  /// Sorts by average user rating.
  averagePoint('averagepoint');

  /// Creates a model sort with its Wiro wire value.
  const WiroModelSort(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// Direction used to order Wiro model search results.
enum WiroSortOrder {
  /// Sorts from the smallest or oldest value.
  ascending('ASC'),

  /// Sorts from the largest or newest value.
  descending('DESC');

  /// Creates a sort order with its Wiro wire value.
  const WiroSortOrder(this.apiValue);

  /// Value sent to the Wiro API.
  final String apiValue;
}

/// A model available through Wiro.
final class WiroModel {
  /// Creates a Wiro model.
  const WiroModel({
    required this.id,
    required this.owner,
    required this.slug,
    required this.categories,
    required this.tags,
    required this.samples,
    required this.raw,
    this.title,
    this.description,
    this.seoDescription,
    this.imageUrl,
    this.computingTime,
    this.approximateCost,
    this.dynamicPrice,
    this.cps,
    this.taskStats,
  });

  /// Creates a model from a Wiro API payload.
  factory WiroModel.fromJson(WiroJson json) {
    return WiroModel(
      id: JsonReader.string(json['id']) ?? '',
      title: JsonReader.string(json['title']),
      owner:
          JsonReader.string(json['cleanslugowner']) ??
          JsonReader.string(json['slugowner']) ??
          '',
      slug:
          JsonReader.string(json['cleanslugproject']) ??
          JsonReader.string(json['slugproject']) ??
          '',
      description: JsonReader.string(json['description']),
      seoDescription: JsonReader.string(json['seodescription']),
      imageUrl: JsonReader.uri(json['image']),
      categories: JsonReader.stringList(json['categories']),
      tags: JsonReader.stringList(json['tags']),
      samples: JsonReader.stringList(json['samples']),
      computingTime: JsonReader.string(json['computingtime']),
      approximateCost: JsonReader.string(json['approximatelycost']),
      dynamicPrice: JsonReader.string(json['dynamicprice']),
      cps: JsonReader.string(json['cps']),
      taskStats: json['taskstat'] == null
          ? null
          : WiroModelTaskStats.fromJson(JsonReader.map(json['taskstat'])),
      raw: Map<String, Object?>.unmodifiable(json),
    );
  }

  /// Stable model identifier.
  final String id;

  /// Model owner slug.
  final String owner;

  /// Model project slug.
  final String slug;

  /// Display title.
  final String? title;

  /// Human-readable model description.
  final String? description;

  /// Search-optimized description.
  final String? seoDescription;

  /// Model cover image.
  final Uri? imageUrl;

  /// Categories assigned by Wiro.
  final List<String> categories;

  /// Search and discovery tags.
  final List<String> tags;

  /// Sample output URLs.
  final List<String> samples;

  /// Approximate processing time reported by Wiro.
  final String? computingTime;

  /// Approximate cost reported by Wiro.
  final String? approximateCost;

  /// Dynamic pricing descriptor.
  final String? dynamicPrice;

  /// Cost-per-second descriptor.
  final String? cps;

  /// Aggregate execution statistics.
  final WiroModelTaskStats? taskStats;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;

  /// Canonical `owner/model` identifier, or `null` for missing slugs.
  WiroModelId? get modelId => WiroModelId.tryCreate(owner, slug);
}

/// Aggregate execution statistics for a model.
final class WiroModelTaskStats {
  /// Creates model task statistics.
  const WiroModelTaskStats({
    required this.runCount,
    required this.successCount,
    required this.errorCount,
    this.lastRunTime,
  });

  /// Creates statistics from a Wiro API payload.
  factory WiroModelTaskStats.fromJson(WiroJson json) {
    return WiroModelTaskStats(
      runCount: JsonReader.integer(json['runcount']),
      successCount: JsonReader.integer(json['successcount']),
      errorCount: JsonReader.integer(json['errorcount']),
      lastRunTime: JsonReader.dateTime(json['lastruntime']),
    );
  }

  /// Total number of model runs.
  final int runCount;

  /// Number of successful runs.
  final int successCount;

  /// Number of failed runs.
  final int errorCount;

  /// Timestamp of the most recent run.
  final DateTime? lastRunTime;
}

/// Full input schema for a Wiro model.
final class WiroModelSchema {
  /// Creates a model schema.
  const WiroModelSchema({
    required this.model,
    required this.parameterGroups,
    this.readme,
  });

  /// Creates a schema from a model-detail payload.
  factory WiroModelSchema.fromJson(WiroJson json) {
    final groups = JsonReader.list(json['parameters'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroModelParameterGroup.fromJson)
        .toList(growable: false);

    return WiroModelSchema(
      model: WiroModel.fromJson(json),
      parameterGroups: List.unmodifiable(groups),
      readme: JsonReader.string(json['readme']),
    );
  }

  /// Model described by this schema.
  final WiroModel model;

  /// Parameter groups in display order.
  final List<WiroModelParameterGroup> parameterGroups;

  /// Optional model documentation.
  final String? readme;

  /// All model parameters in display order.
  List<WiroModelParameter> get parameters {
    return List.unmodifiable(
      parameterGroups.expand((group) => group.parameters),
    );
  }

  /// Validates dynamic [parameters] against this model schema.
  ///
  /// Throws [WiroSchemaValidationException] when required, select, or numeric
  /// constraints are not satisfied.
  void validate(WiroJson parameters) {
    final errors = <String>[];
    for (final parameter in this.parameters) {
      final isPresent =
          parameters.containsKey(parameter.id) &&
          parameters[parameter.id] != null;
      if (parameter.isRequired && !isPresent) {
        errors.add('${parameter.id} is required');
        continue;
      }
      if (!isPresent) {
        continue;
      }

      final value = parameters[parameter.id];
      switch (parameter) {
        case WiroSelectParameter(:final options):
          final optionValues = options.map((option) => option.value).toSet();
          final selectedValue = JsonReader.string(value);
          if (selectedValue == null || !optionValues.contains(selectedValue)) {
            errors.add(
              '${parameter.id} must be one of: '
              '${optionValues.join(', ')}',
            );
          }
        case WiroNumberParameter(:final minimum, :final maximum):
          final number = JsonReader.decimal(value);
          if (number == null) {
            errors.add('${parameter.id} must be numeric');
          } else {
            if (minimum != null && number < minimum) {
              errors.add('${parameter.id} must be at least $minimum');
            }
            if (maximum != null && number > maximum) {
              errors.add('${parameter.id} must be at most $maximum');
            }
          }
        case WiroTextParameter() ||
            WiroFileParameter() ||
            WiroUnknownParameter():
          break;
      }
    }
    if (errors.isNotEmpty) {
      throw WiroSchemaValidationException(errors);
    }
  }
}

/// A visual group of model parameters.
final class WiroModelParameterGroup {
  /// Creates a parameter group.
  const WiroModelParameterGroup({
    required this.title,
    required this.parameters,
  });

  /// Creates a parameter group from a Wiro API payload.
  factory WiroModelParameterGroup.fromJson(WiroJson json) {
    final parameters = JsonReader.list(json['items'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroModelParameter.fromJson)
        .toList(growable: false);

    return WiroModelParameterGroup(
      title: JsonReader.string(json['title']) ?? '',
      parameters: List.unmodifiable(parameters),
    );
  }

  /// Group heading.
  final String title;

  /// Parameters contained by this group.
  final List<WiroModelParameter> parameters;
}

/// Base type for a model input parameter.
sealed class WiroModelParameter {
  const WiroModelParameter({
    required this.id,
    required this.label,
    required this.isRequired,
    required this.raw,
    this.description,
    this.placeholder,
    this.note,
  });

  /// Creates a parameter from a Wiro API payload.
  factory WiroModelParameter.fromJson(WiroJson json) {
    final type = JsonReader.string(json['type']) ?? '';
    final options = JsonReader.list(json['options'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroModelParameterOption.fromJson)
        .toList(growable: false);
    final fields = (
      id: JsonReader.string(json['id']) ?? '',
      label: JsonReader.string(json['label']) ?? '',
      description: JsonReader.string(json['description']),
      isRequired: JsonReader.boolean(json['required']),
      placeholder: JsonReader.string(json['placeholder']),
      note: JsonReader.string(json['note']),
      raw: Map<String, Object?>.unmodifiable(json),
    );

    return switch (type.toLowerCase()) {
      'select' => WiroSelectParameter(
        id: fields.id,
        label: fields.label,
        options: List.unmodifiable(options),
        isRequired: fields.isRequired,
        raw: fields.raw,
        description: fields.description,
        defaultValue: JsonReader.string(json['default']),
        placeholder: fields.placeholder,
        note: fields.note,
      ),
      'range' ||
      'number' ||
      'numeric' ||
      'integer' ||
      'float' => WiroNumberParameter(
        id: fields.id,
        label: fields.label,
        isRequired: fields.isRequired,
        raw: fields.raw,
        description: fields.description,
        defaultValue: JsonReader.decimal(json['default']),
        placeholder: fields.placeholder,
        note: fields.note,
        minimum: JsonReader.decimal(json['min']),
        maximum: JsonReader.decimal(json['max']),
        step: JsonReader.decimal(json['step']),
      ),
      'text' || 'textarea' => WiroTextParameter(
        id: fields.id,
        label: fields.label,
        isRequired: fields.isRequired,
        raw: fields.raw,
        description: fields.description,
        defaultValue: JsonReader.string(json['default']),
        placeholder: fields.placeholder,
        note: fields.note,
      ),
      'fileinput' ||
      'multifileinput' ||
      'combinefileinput' => WiroFileParameter(
        id: fields.id,
        label: fields.label,
        isRequired: fields.isRequired,
        raw: fields.raw,
        description: fields.description,
        placeholder: fields.placeholder,
        note: fields.note,
      ),
      _ => WiroUnknownParameter(
        id: fields.id,
        type: type,
        label: fields.label,
        isRequired: fields.isRequired,
        raw: fields.raw,
        description: fields.description,
        defaultValue: json['default'],
        placeholder: fields.placeholder,
        note: fields.note,
      ),
    };
  }

  /// Parameter identifier sent to the API.
  final String id;

  /// Display label.
  final String label;

  /// Human-readable guidance.
  final String? description;

  /// Whether callers must provide this parameter.
  final bool isRequired;

  /// Suggested input placeholder.
  final String? placeholder;

  /// Additional usage note.
  final String? note;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;
}

/// A parameter constrained to one of a declared set of options.
final class WiroSelectParameter extends WiroModelParameter {
  /// Creates a select parameter.
  const WiroSelectParameter({
    required super.id,
    required super.label,
    required this.options,
    required super.isRequired,
    required super.raw,
    super.description,
    super.placeholder,
    super.note,
    this.defaultValue,
  });

  /// Accepted parameter values.
  final List<WiroModelParameterOption> options;

  /// Default selected value.
  final String? defaultValue;
}

/// A numeric parameter with optional bounds and increment.
final class WiroNumberParameter extends WiroModelParameter {
  /// Creates a numeric parameter.
  const WiroNumberParameter({
    required super.id,
    required super.label,
    required super.isRequired,
    required super.raw,
    super.description,
    super.placeholder,
    super.note,
    this.defaultValue,
    this.minimum,
    this.maximum,
    this.step,
  });

  /// Default numeric value.
  final double? defaultValue;

  /// Minimum numeric value.
  final double? minimum;

  /// Maximum numeric value.
  final double? maximum;

  /// Numeric increment.
  final double? step;
}

/// A single-line or multiline text parameter.
final class WiroTextParameter extends WiroModelParameter {
  /// Creates a text parameter.
  const WiroTextParameter({
    required super.id,
    required super.label,
    required super.isRequired,
    required super.raw,
    super.description,
    super.placeholder,
    super.note,
    this.defaultValue,
  });

  /// Default text value.
  final String? defaultValue;
}

/// A single, multiple, or combined file input parameter.
final class WiroFileParameter extends WiroModelParameter {
  /// Creates a file parameter.
  const WiroFileParameter({
    required super.id,
    required super.label,
    required super.isRequired,
    required super.raw,
    super.description,
    super.placeholder,
    super.note,
  });
}

/// A parameter type introduced after this SDK version.
final class WiroUnknownParameter extends WiroModelParameter {
  /// Creates an unknown parameter while preserving its wire [type].
  const WiroUnknownParameter({
    required super.id,
    required this.type,
    required super.label,
    required super.isRequired,
    required super.raw,
    super.description,
    super.placeholder,
    super.note,
    this.defaultValue,
  });

  /// Unrecognized Wiro parameter type.
  final String type;

  /// Unparsed default value for this unknown parameter type.
  final Object? defaultValue;
}

/// An option accepted by a select-like parameter.
final class WiroModelParameterOption {
  /// Creates a model parameter option.
  const WiroModelParameterOption({required this.label, required this.value});

  /// Creates an option from a Wiro API payload.
  factory WiroModelParameterOption.fromJson(WiroJson json) {
    return WiroModelParameterOption(
      label: JsonReader.string(json['label']) ?? '',
      value: JsonReader.string(json['value']) ?? '',
    );
  }

  /// Display label.
  final String label;

  /// Value sent to the Wiro API.
  final String value;
}
