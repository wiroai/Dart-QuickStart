/// A JSON object used by the Wiro API.
typedef WiroJson = Map<String, Object?>;

/// Receives a nested JSON string that could not be decoded.
typedef WiroMalformedJsonCallback =
    void Function(String source, FormatException error);
