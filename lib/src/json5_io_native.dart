import 'dart:io' as io;
import 'json5.dart';

/// Creates a Json5 object by reading and parsing the contents of the file at [path].
Json5 fromFile({required bool caseSensitiveKeys, required String path, required bool readOnly}) {
  io.File file = io.File(path);
  if (!file.existsSync()) {
    throw io.FileSystemException("JSON file not found", path);
  }
  return Json5.fromString(
    file.readAsStringSync(),
    caseSensitiveKeys: caseSensitiveKeys,
    readOnly: readOnly,
  );
}
