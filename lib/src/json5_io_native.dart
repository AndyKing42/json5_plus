import 'dart:io' as io;
import 'json5.dart';

/// Creates a Json5 object by reading and parsing the contents of the file at [path].
Json5 fromFile({
  required bool caseSensitiveKeys,
  required EDateTimeFormat dateTimeFormat,
  Map<String, dynamic>? params,
  required String path,
  required bool readOnly,
  required bool sortedKeys,
}) {
  io.File file = io.File(path);
  if (!file.existsSync()) {
    throw io.FileSystemException("JSON file not found", path);
  }
  return Json5.fromString(
    file.readAsStringSync(),
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  );
}

/// Writes the formatted JSON5 representation of [json] to the file at [path].
void toFile(Json5 json, String path, {bool includeComments = true, bool json5 = true}) => io.File(
  path,
).writeAsStringSync(json.toFormattedString(includeComments: includeComments, json5: json5));
