import 'package:wiro_ai/src/model/json_reader.dart';
import 'package:wiro_ai/src/model/wiro_json.dart';

/// A model available through Wiro.
final class WiroModel {
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

  final String id;
  final String owner;
  final String slug;
  final String? title;
  final String? description;
  final String? seoDescription;
  final Uri? imageUrl;
  final List<String> categories;
  final List<String> tags;
  final List<String> samples;
  final String? computingTime;
  final String? approximateCost;
  final String? dynamicPrice;
  final String? cps;
  final WiroModelTaskStats? taskStats;

  /// Original API payload for forward-compatible access.
  final WiroJson raw;

  /// Canonical `owner/model` identifier.
  String get identifier => '$owner/$slug';
}

/// Aggregate execution statistics for a model.
final class WiroModelTaskStats {
  const WiroModelTaskStats({
    required this.runCount,
    required this.successCount,
    required this.errorCount,
    this.lastRunTime,
  });

  factory WiroModelTaskStats.fromJson(WiroJson json) {
    return WiroModelTaskStats(
      runCount: JsonReader.integer(json['runcount']),
      successCount: JsonReader.integer(json['successcount']),
      errorCount: JsonReader.integer(json['errorcount']),
      lastRunTime: JsonReader.string(json['lastruntime']),
    );
  }

  final int runCount;
  final int successCount;
  final int errorCount;
  final String? lastRunTime;
}

/// Full input schema for a Wiro model.
final class WiroModelSchema {
  const WiroModelSchema({
    required this.model,
    required this.parameterGroups,
    this.readme,
  });

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

  final WiroModel model;
  final List<WiroModelParameterGroup> parameterGroups;
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
  const WiroModelParameterGroup({
    required this.title,
    required this.parameters,
  });

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

  final String title;
  final List<WiroModelParameter> parameters;
}

/// A single accepted model parameter.
final class WiroModelParameter {
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

  final String id;
  final String type;
  final String label;
  final String? description;
  final Object? defaultValue;
  final bool isRequired;
  final String? placeholder;
  final String? note;
  final List<WiroModelParameterOption> options;
  final double? minimum;
  final double? maximum;
  final double? step;
}

/// An option accepted by a select-like parameter.
final class WiroModelParameterOption {
  const WiroModelParameterOption({required this.label, required this.value});

  factory WiroModelParameterOption.fromJson(WiroJson json) {
    return WiroModelParameterOption(
      label: JsonReader.string(json['label']) ?? '',
      value: JsonReader.string(json['value']) ?? '',
    );
  }

  final String label;
  final String value;
}
