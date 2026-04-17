import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5_accessor.dart';
import 'json5_extensions.dart';
import 'json5_io_stub.dart' if (dart.library.io) 'json5_io_native.dart' as io;
import 'json5_options.dart';
import 'json5_parser.dart';
import 'json5_util.dart';

/// Represents a JSON object as a map of keys (strings) to values (objects). The values can be of
/// type String, double, int, Json5, list of objects, or Boolean.
class Json5 with Json5Accessor {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  static final List<double> emptyDoubleList = List.unmodifiable([]);
  // TODO(andy): document this!
  ///
  static final List<dynamic> emptyDynamicList = List.unmodifiable([]);
  // TODO(andy): document this!
  ///
  static final List<int> emptyIntList = List.unmodifiable([]);
  // TODO(andy): document this!
  ///
  static final Json5 emptyJson = Json5(readOnly: true);
  // TODO(andy): document this!
  ///
  static final List<Json5> emptyJsonList = List.unmodifiable([]);
  // TODO(andy): document this!
  ///
  static final List<String> emptyStringList = List.unmodifiable([]);
  static const Map<String, String> _escapedCharMap = {
    // search string -> replacement string
    '\b': r'\b',
    '\t': r'\t',
    '\n': r'\n',
    '\f': r'\f',
    '\r': r'\r',
    '"': r'\"',
    r'\': r'\\',
  };

  // TODO(andy): document this!
  ///
  // @internal
  final Map<String, dynamic> keyToValueMap;
  // TODO(andy): document this!
  ///
  // @internal
  bool readOnly;

  //--------------------------------------------------------------------------------------------------
  static List<dynamic> _copyList(final List<dynamic> other) {
    final List<dynamic> result = [];
    for (final dynamic listItem in other) {
      switch (listItem) {
        case List<dynamic> listValue:
          result.add(_copyList(listValue));
        case Json5 jsonValue:
          result.add(Json5(json: jsonValue));
        default:
          result.add(listItem);
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string into a Dart object.
  ///
  /// Returns a [Json5] object for JSON objects, a [List] for arrays,
  /// or a primitive value (String, num, bool, null).
  static dynamic decode(String jsonString) => Json5Parser.decode(jsonString);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  static String escapeString(String originalValue) {
    String result;
    Set<String>? charToEscapeSet;
    for (int charIndex = 0; charIndex < originalValue.length; ++charIndex) {
      if (_escapedCharMap.containsKey(originalValue[charIndex])) {
        charToEscapeSet ??= {};
        charToEscapeSet.add(originalValue[charIndex]);
      }
    }
    if (charToEscapeSet == null) {
      return originalValue;
    }
    result = originalValue;
    for (final String charToEscape in charToEscapeSet) {
      result = result.replaceAll(charToEscape, _escapedCharMap[charToEscape]!);
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  /// Creates a new GlJson object that contains entries from json2 that do not match the values from
  /// json1.
  factory Json5.fromDiffs(final Json5 json1, final Json5 json2) {
    final Json5 result = Json5();
    for (final MapEntry<String, dynamic> entry in json2.keyToValueMap.entries) {
      if (json1.keyToValueMap[entry.key] != entry.value) {
        result.keyToValueMap[entry.key] = entry.value;
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by reading and parsing the contents of the file at [path].
  factory Json5.fromFile(String path) => io.fromFile(path);

  //--------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects/arrays and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) loadMultiple({required String jsons}) {
    final List<Json5> results = [];
    Json5Parser parser = Json5Parser.createJson5Instance(jsons);
    while (true) {
      parser.skipWhitespace();
      if (parser.atEnd) break;
      try {
        final json = Json5();
        parser.parseInto(json);
        results.add(json);
      } catch (e) {
        break;
      }
    }
    return (jsonList: results, unprocessed: jsons.substring(parser.pos));
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Json5({
    bool? caseSensitiveKeys,
    Json5? json,
    String? jsonString,
    List<String>? keyList,
    Map<String, int>? keyToIndexMap,
    Map<dynamic, dynamic>? map,
    this.readOnly = false,
    List<dynamic>? valueList,
  }) : keyToValueMap = caseSensitiveKeys ?? json5Options.caseSensitiveKeys
           ? {}
           : SplayTreeMap((String key1, String key2) => key1.compareToIgnoreCase(key2)) {
    if (json != null) {
      for (final MapEntry<String, dynamic> entry in json.keyToValueMap.entries) {
        switch (entry.value) {
          case List<dynamic> listValue:
            keyToValueMap[entry.key] = _copyList(listValue);
          case Json5 jsonValue:
            keyToValueMap[entry.key] = Json5(json: jsonValue);
          default:
            keyToValueMap[entry.key] = entry.value;
        }
      }
    }
    if (jsonString != null && jsonString.isNotEmpty) {
      Json5Parser.decodeInternal(json5: this, jsonString: jsonString);
    }
    if (map != null) {
      addAll(map);
    }
    setFromkeyAndValueLists(keyList, valueList);
    setFromkeyToIndexAndValueList(keyToIndexMap, valueList);
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void operator []=(dynamic key, dynamic value) => set(key, value);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void addAll(Map<dynamic, dynamic>? map) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    if (map == null || map.isEmpty) {
      return;
    }
    map.forEach(set);
    _convertMap();
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  List<double> asDoubleList(final dynamic key) {
    List<double> result;
    final List<dynamic>? list = keyToValueMap[_getkey(key)] as List<dynamic>?;
    if (list == null) {
      return emptyDoubleList;
    }
    result = [];
    for (final Object? listItem in list) {
      if (listItem is num) {
        result.add(listItem.toDouble());
      } else {
        result.add(listItem.toString().toDouble());
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  List<dynamic> asDynamicList(final dynamic key) {
    final dynamic result = keyToValueMap[_getkey(key)];
    if (result is List<dynamic>) {
      return result;
    }
    return emptyDynamicList;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  List<int> asIntList(final dynamic key) {
    List<int> result;
    final List<dynamic>? list = keyToValueMap[_getkey(key)] as List<dynamic>?;
    if (list == null) {
      return emptyIntList;
    }
    result = [];
    for (final Object? listItem in list) {
      if (listItem is num) {
        result.add(listItem.toInt());
      } else {
        result.add(listItem.toString().toInt());
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  /// @return EmptyJson if no entry is found.
  Json5 asJson(final dynamic key) => keyToValueMap[_getkey(key)] as Json5? ?? emptyJson;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  List<Json5> asJsonList(final dynamic key) {
    List<Json5> result;
    final List<dynamic>? list = keyToValueMap[_getkey(key)] as List<dynamic>?;
    if (list == null) {
      return emptyJsonList;
    }
    result = [];
    for (final Object? listItem in list) {
      if (listItem is Json5) {
        result.add(listItem);
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  List<String> asStringList(final dynamic key) {
    List<String> result;
    final List<dynamic>? list = keyToValueMap[_getkey(key)] as List<dynamic>?;
    if (list == null) {
      return emptyStringList;
    }
    result = [];
    for (final Object? listItem in list) {
      if (listItem != null) {
        result.add(listItem.toString());
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  @override
  @internal
  dynamic asType(dynamic key) => keyToValueMap[_getkey(key)];

  //--------------------------------------------------------------------------------------------------
  void _convertList(List<dynamic> list) {
    for (int listIndex = 0; listIndex < list.length; ++listIndex) {
      switch (list[listIndex]) {
        case Map<dynamic, dynamic> mapValue:
          list[listIndex] = Json5(map: mapValue);
        case List<dynamic> listValue:
          _convertList(listValue);
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _convertMap() {
    keyToValueMap.forEach((final String key, final dynamic value) {
      switch (value) {
        case Map<dynamic, dynamic> mapValue:
          keyToValueMap[key] = Json5(map: mapValue);
        case List<dynamic> listValue:
          _convertList(listValue);
      }
    });
  }

  //--------------------------------------------------------------------------------------------------
  void _formatEntry({
    required StringBuffer buffer,
    required String key,
    required int level,
    required dynamic value,
  }) {
    final String prefix = "  " * level;
    buffer
      ..write(prefix)
      ..write(key)
      ..write(": ");
    if (value is Json5) {
      _formatMap(buffer: buffer, level: level, map: value.keyToValueMap);
    } else if (value is List) {
      _formatList(buffer: buffer, level: level, list: value);
    } else if (value is String) {
      buffer
        ..write('"')
        ..write(escapeString(value))
        ..write('"');
    } else if (value is num || value is bool || value == null) {
      buffer.write(value);
    } else {
      buffer
        ..write('"')
        ..write(escapeString(value.toString()))
        ..write('"');
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _formatList({
    required StringBuffer buffer,
    required int level,
    required List<dynamic> list,
  }) {
    if (list.isEmpty) {
      buffer
        ..write("  " * level)
        ..write("[]");
      return;
    }
    buffer.writeln("[");
    final String prefix = "  " * (level + 1);
    for (int i = 0; i < list.length; ++i) {
      dynamic value = list[i];
      switch (value) {
        case Json5 jsonValue:
          buffer.write(prefix);
          _formatMap(buffer: buffer, level: level + 1, map: jsonValue.keyToValueMap);
        case List<dynamic> listValue:
          _formatList(buffer: buffer, level: level + 1, list: listValue);
        case String stringValue:
          buffer
            ..write(prefix)
            ..write('"')
            ..write(escapeString(stringValue))
            ..write('"');
        default:
          buffer
            ..write(prefix)
            ..write(value);
      }
      buffer.writeln(",");
    }
    buffer
      ..write("  " * level)
      ..write("]");
  }

  //--------------------------------------------------------------------------------------------------
  void _formatMap({
    required StringBuffer buffer,
    required int level,
    required Map<String, dynamic> map,
  }) {
    if (map.isEmpty) {
      buffer.write("{}");
      return;
    }
    buffer.writeln("{");
    final List<String> sortedKeys = map.keys.toList();
    for (int i = 0; i < sortedKeys.length; ++i) {
      final String key = sortedKeys[i];
      _formatEntry(buffer: buffer, key: key, level: level + 1, value: map[key]);
      buffer.writeln(",");
    }
    buffer
      ..write("  " * level)
      ..write("}");
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Iterable<MapEntry<String, dynamic>> get entries => keyToValueMap.entries;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool get isEmpty => keyToValueMap.isEmpty;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool get isNotEmpty => keyToValueMap.isNotEmpty;

  //--------------------------------------------------------------------------------------------------
  /// Generates a JSON5 representation of the object. The result is a single line, with no extra
  /// spaces, and no comments. For a pretty-printed version, use [toFormattedString].
  String get json5String {
    final buffer = StringBuffer("{");
    bool firstEntry = true;
    keyToValueMap.forEach((String key, dynamic value) {
      if (!firstEntry) buffer.write(",");
      buffer
        ..write(key)
        ..write(":")
        ..write(_valueToString(value));
      firstEntry = false;
    });
    if (!firstEntry) buffer.write(",");
    buffer.write("}");
    return buffer.toString();
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  String get jsonString {
    final buffer = StringBuffer("{");
    bool firstEntry = true;
    keyToValueMap.forEach((String key, dynamic value) {
      buffer
        ..write(firstEntry ? "" : ",")
        ..write('"')
        ..write(key)
        ..write('":')
        ..write(_valueToString(value, json5: false));
      firstEntry = false;
    });
    buffer.write("}");
    return buffer.toString();
  }

  //--------------------------------------------------------------------------------------------------
  String _getkey(dynamic key) {
    if (key is String) {
      return key;
    }
    String keyString = key.toString();
    return keyString.substring(keyString.lastIndexOf(".") + 1);
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Iterable<String> get keys => keyToValueMap.keys;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  int get length => keyToValueMap.length;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void set(dynamic key, final dynamic value) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    String localKey = _getkey(key);
    switch (value) {
      case null:
        keyToValueMap.remove(localKey);
      case DateTime dateTimeValue:
        keyToValueMap[localKey] = dateTimeValue.formatIso8601();
      case Map<dynamic, dynamic> mapValue:
        keyToValueMap[localKey] = Json5(map: mapValue);
      default:
        keyToValueMap[localKey] = value;
    }
  }

  //--------------------------------------------------------------------------------------------------
  /// Copies entries from [copyFromJson] into this object.
  /// Performs a deep copy of nested Json5 objects and Lists.
  void setFromJson(final Json5 copyFromJson) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<String, dynamic> newEntry in copyFromJson.keyToValueMap.entries) {
      final dynamic value = newEntry.value;
      switch (value) {
        case List<dynamic> listValue:
          keyToValueMap[newEntry.key] = _copyList(listValue);
        case Json5 jsonValue:
          keyToValueMap[newEntry.key] = Json5(json: jsonValue);
        default:
          keyToValueMap[newEntry.key] = value;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void setFromMap(final Map<dynamic, dynamic> copyFromMap) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<dynamic, dynamic> entry in copyFromMap.entries) {
      set(entry.key, entry.value);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void setFromkeyAndValueLists(List<String>? keyList, List<dynamic>? valueList) {
    if (keyList == null || valueList == null) {
      return;
    }
    if (valueList.length != keyList.length) {
      throw Exception("keyList and valueList must be the same length");
    }
    for (int keyIndex = 0; keyIndex < keyList.length; ++keyIndex) {
      set(keyList[keyIndex], valueList[keyIndex]);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void setFromkeyToIndexAndValueList(Map<String, int>? keyToIndexMap, List<dynamic>? valueList) {
    if (keyToIndexMap == null || valueList == null) {
      return;
    }
    for (final MapEntry<String, int> keyToIndex in keyToIndexMap.entries) {
      set(keyToIndex.key, valueList[keyToIndex.value]);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void setIfChanged(final dynamic key, final Json5 oldJson, final dynamic newValue) {
    String localKey = _getkey(key);
    if (newValue != oldJson.keyToValueMap[localKey]) {
      set(localKey, newValue);
    }
    return;
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns a pretty-printed JSON5 string with 2-space indentation.
  String toFormattedString() {
    StringBuffer result = StringBuffer();
    _formatMap(buffer: result, level: 0, map: keyToValueMap);
    return result.toString();
  }

  //--------------------------------------------------------------------------------------------------
  @override
  String toString() => json5String;

  //--------------------------------------------------------------------------------------------------
  String _valueToString(dynamic value, {bool json5 = true}) => switch (value) {
    String stringValue => '"${escapeString(stringValue)}"',
    num numValue => numValue.toString(),
    bool boolValue => boolValue ? "true" : "false",
    Json5 jsonValue => json5 ? jsonValue.json5String : jsonValue.jsonString,
    List<dynamic> listValue =>
      "[${listValue.map((e) => _valueToString(e, json5: json5)).join(',')}]",
    Enum enumValue => '"${_getkey(enumValue)}"',
    null => "null",
    var v =>
      json5Util.isEnum(v) ? '"${v.toString().split('.').last}"' : '"${escapeString(v.toString())}"',
  };

  //--------------------------------------------------------------------------------------------------
}
