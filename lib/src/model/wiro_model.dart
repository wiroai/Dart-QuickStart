import 'package:wiro_client/src/model/json_reader.dart';
import 'package:wiro_client/src/model/wiro_json.dart';

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
      raw: Map.unmodifiable(json),
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

  /// Canonical `owner/model` identifier.
  String get identifier => '$owner/$slug';
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
      lastRunTime: JsonReader.string(json['lastruntime']),
    );
  }

  /// Total number of model runs.
  final int runCount;

  /// Number of successful runs.
  final int successCount;

  /// Number of failed runs.
  final int errorCount;

  /// Timestamp of the most recent run.
  final String? lastRunTime;
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

/// A single accepted model parameter.
final class WiroModelParameter {
  /// Creates a model parameter.
  const WiroModelParameter({
    required this.id,
    required this.type,
    required this.label,
    required this.options,
    required this.isRequired,
    this.description,
    this.defaultValue,
    this.placeholder,
    this.note,
    this.minimum,
    this.maximum,
    this.step,
  });

  /// Creates a parameter from a Wiro API payload.
  factory WiroModelParameter.fromJson(WiroJson json) {
    final options = JsonReader.list(json['options'])
        .map(JsonReader.map)
        .where((item) => item.isNotEmpty)
        .map(WiroModelParameterOption.fromJson)
        .toList(growable: false);

    return WiroModelParameter(
      id: JsonReader.string(json['id']) ?? '',
      type: JsonReader.string(json['type']) ?? '',
      label: JsonReader.string(json['label']) ?? '',
      description: JsonReader.string(json['description']),
      defaultValue: json['default'],
      isRequired: JsonReader.boolean(json['required']),
      placeholder: JsonReader.string(json['placeholder']),
      note: JsonReader.string(json['note']),
      options: List.unmodifiable(options),
      minimum: JsonReader.decimal(json['min']),
      maximum: JsonReader.decimal(json['max']),
      step: JsonReader.decimal(json['step']),
    );
  }

  /// Parameter identifier sent to the API.
  final String id;

  /// Wiro input type such as `textarea`, `select`, or `fileinput`.
  final String type;

  /// Display label.
  final String label;

  /// Human-readable guidance.
  final String? description;

  /// Default parameter value.
  final Object? defaultValue;

  /// Whether callers must provide this parameter.
  final bool isRequired;

  /// Suggested input placeholder.
  final String? placeholder;

  /// Additional usage note.
  final String? note;

  /// Accepted values for select-like parameters.
  final List<WiroModelParameterOption> options;

  /// Minimum numeric value.
  final double? minimum;

  /// Maximum numeric value.
  final double? maximum;

  /// Numeric increment.
  final double? step;
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
