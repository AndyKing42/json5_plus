import 'dart:io' as io;

import 'json5.dart';
import 'json5_parser.dart';

/// Creates a Json5 object by reading and parsing the contents of the file at [path].
Json5 fromFile({
  String? baseFilePath,
  required bool caseSensitiveKeys,
  required EDateTimeFormat dateTimeFormat,
  Set<String>? includePathSet,
  Map<String, dynamic>? params,
  required String path,
  required bool readOnly,
  required bool sortedKeys,
}) {
  final String resolvedPath = _resolvePath(path, baseFilePath: baseFilePath);
  final io.File file = io.File(resolvedPath);
  if (!file.existsSync()) {
    throw io.FileSystemException("JSON file not found", resolvedPath);
  }
  final String canonicalPath = file.resolveSymbolicLinksSync();
  final Set<String> activeIncludePathSet = includePathSet ?? <String>{};
  if (activeIncludePathSet.contains(canonicalPath)) {
    throw FormatException('Circular \$include detected for "$resolvedPath"');
  }
  activeIncludePathSet.add(canonicalPath);
  try {
    final String jsonString = file.readAsStringSync();
    if (Json5.isBlankString(jsonString)) {
      if (Json5.defaultAllowBlankString) {
        return Json5(
          caseSensitiveKeys: caseSensitiveKeys,
          dateTimeFormat: dateTimeFormat,
          readOnly: readOnly,
          sortedKeys: sortedKeys,
        );
      }
      throw const FormatException("JSON5 string cannot be blank");
    }
    return Json5Parser.decode(
      caseSensitiveKeys: caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat,
      includePathSet: activeIncludePathSet,
      jsonString: jsonString,
      params: params,
      readOnly: readOnly,
      sortedKeys: sortedKeys,
      sourcePath: canonicalPath,
    );
  } finally {
    activeIncludePathSet.remove(canonicalPath);
  }
}

/// Writes the formatted JSON5 representation of [json] to the file at [path].
void toFile(Json5 json, String path, {bool includeComments = true, bool json5 = true}) => io.File(
  path,
).writeAsStringSync(json.toFormattedString(includeComments: includeComments, json5: json5));

bool _isAbsolutePath(String path) {
  if (path.isEmpty) {
    return false;
  }
  final int first = path.codeUnitAt(0);
  if (first == 47 /* / */ || first == 92 /* \ */ ) {
    return true;
  }
  if (path.length >= 3 && path.codeUnitAt(1) == 58 /* : */ ) {
    final bool isLetter = (first >= 65 && first <= 90) || (first >= 97 && first <= 122);
    final int third = path.codeUnitAt(2);
    return isLetter && (third == 47 /* / */ || third == 92 /* \ */ );
  }
  return false;
}

String _resolvePath(String path, {String? baseFilePath}) {
  if (baseFilePath == null || _isAbsolutePath(path)) {
    return path;
  }
  final String normalizedRelative = path.replaceAll(r"\", "/");
  return io.File(baseFilePath).absolute.uri
      .resolveUri(Uri(path: normalizedRelative))
      .toFilePath(windows: io.Platform.isWindows);
}
