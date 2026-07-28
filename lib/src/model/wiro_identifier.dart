/// A validated Wiro model identifier in `owner/project` form.
extension type const WiroModelId._(String value) {
  /// Creates a model identifier from validated [owner] and [project] slugs.
  factory WiroModelId(String owner, String project) {
    _validateSlug(owner, 'owner');
    _validateSlug(project, 'project');
    return WiroModelId._('$owner/$project');
  }

  /// Parses and validates an `owner/project` model identifier.
  factory WiroModelId.parse(String value) {
    final parts = value.split('/');
    if (parts.length != 2) {
      throw ArgumentError.value(
        value,
        'value',
        'Use the "owner/project" format',
      );
    }
    return WiroModelId(parts.first, parts.last);
  }

  /// Returns a model identifier, or `null` when either slug is invalid.
  static WiroModelId? tryCreate(String? owner, String? project) {
    if (owner == null ||
        project == null ||
        !_isValidSlug(owner) ||
        !_isValidSlug(project)) {
      return null;
    }
    return WiroModelId._('$owner/$project');
  }

  /// Model owner slug.
  String get owner => value.split('/').first;

  /// Model project slug.
  String get project => value.split('/').last;

  static void _validateSlug(String slug, String name) {
    if (!_isValidSlug(slug)) {
      throw ArgumentError.value(slug, name, 'Must be a valid Wiro slug');
    }
  }

  static bool _isValidSlug(String slug) {
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(slug);
  }
}

/// A validated token used to access and observe a Wiro task.
extension type const WiroTaskToken._(String value) {
  /// Creates a task token from a non-empty [value].
  factory WiroTaskToken(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Cannot be empty');
    }
    return WiroTaskToken._(value);
  }

  /// Returns a task token, or `null` when [value] is absent or empty.
  static WiroTaskToken? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return WiroTaskToken._(value);
  }
}

/// A validated server-side Wiro task identifier.
extension type const WiroTaskId._(String value) {
  /// Creates a task identifier from a non-empty [value].
  factory WiroTaskId(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Cannot be empty');
    }
    return WiroTaskId._(value);
  }

  /// Returns a task identifier, or `null` when [value] is absent or empty.
  static WiroTaskId? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return WiroTaskId._(value);
  }
}
