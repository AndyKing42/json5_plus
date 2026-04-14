import 'dart:io' as io;
import 'json5.dart';

/// Creates a Json5 object by reading and parsing the contents of the file at [path].
Json5 fromFile(String path) {
  io.File file = io.File(path);
  if (!file.existsSync()) {
    throw io.FileSystemException("JSON file not found", path);
  }
  return Json5(jsonString: file.readAsStringSync());
}
