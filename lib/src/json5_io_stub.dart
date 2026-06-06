import 'json5.dart';

/// fromFile is not supported on the web.
Json5 fromFile({
  required bool caseSensitiveKeys,
  Map<String, dynamic>? params,
  required String path,
  required bool readOnly,
}) => throw UnsupportedError("Json5.fromFile is not supported on the web.");

//------------------------------------------------------------------------------------------------
/// Writes the formatted JSON5 representation of [json] to the file at [path].
void toFile(Json5 json, String path, {bool includeComments = true, bool json5 = true}) =>
    throw UnsupportedError("Json5.toFile is not supported on the web.");
