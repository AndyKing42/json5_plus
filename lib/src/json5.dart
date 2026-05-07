import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5_accessor.dart';
import 'json5_comment_registry.dart';
import 'json5_extensions.dart';
import 'json5_io_stub.dart' if (dart.library.io) 'json5_io_native.dart' as io;
import 'json5_parser.dart';
import 'json5_util.dart';

// TODO(andy): document this!
/// Represents a JSON object as a map of keys (strings) to values (objects). The values can be of
/// type String, double, int, Json5, list of objects, or Boolean.
class Json5 with Json5Accessor {
  //--------------------------------------------------------------------------------------------------
  /// An empty unmodifiable `double` list.
  static final List<double> emptyDoubleList = List.unmodifiable([]);

  /// An empty unmodifiable `dynamic` list.
  static final List<dynamic> emptyDynamicList = List.unmodifiable([]);

  /// An empty unmodifiable `int` list.
  static final List<int> emptyIntList = List.unmodifiable([]);

  /// Gets the [Json5] as a [=].
  static final Json5 emptyJson = Json5(readOnly: true);

  /// An empty unmodifiable `Json5` list.
  static final List<Json5> emptyJsonList = List.unmodifiable([]);

  /// An empty unmodifiable `String` list.
  static final List<String> emptyStringList = List.unmodifiable([]);
  static const Map<int, String> _escapedCodeUnitMap = {
    // code unit -> replacement string
    8: r"\b",
    9: r"\t",
    10: r"\n",
    12: r"\f",
    13: r"\r",
    34: r'\"',
    92: r'\\',
  };

  /// Indicates whether JSON keys are case sensitive.
  final bool caseSensitiveKeys;
  Json5CommentRegistry? _commentRegistry;
  final Map<String, dynamic> _keyToValueMap;

  /// Indicates whether this Json5 object is read-only.
  final bool readOnly;

  //--------------------------------------------------------------------------------------------------
  static List<dynamic> _copyList(final List<dynamic> other) {
    final List<dynamic> result = [];
    for (final dynamic listItem in other) {
      switch (listItem) {
        case List<dynamic> listValue:
          result.add(_copyList(listValue));
        case Json5 json5Value:
          result.add(Json5.fromJson5(json5Value, caseSensitiveKeys: json5Value.caseSensitiveKeys));
        default:
          result.add(listItem);
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects/arrays and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    bool caseSensitiveKeys = false,
    required String jsonString,
    bool readOnly = false,
  }) => Json5Parser.decodeMultiple(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    readOnly: readOnly,
  );

  //--------------------------------------------------------------------------------------------------
  static String _escapeString(String originalValue) {
    StringBuffer? buffer;
    for (int charIndex = 0; charIndex < originalValue.length; ++charIndex) {
      final int codeUnit = originalValue.codeUnitAt(charIndex);
      final String? escapedValue = _escapedCodeUnitMap[codeUnit];
      if (escapedValue != null) {
        buffer ??= StringBuffer(originalValue.substring(0, charIndex));
        buffer.write(escapedValue);
      } else {
        buffer?.writeCharCode(codeUnit);
      }
    }
    return buffer?.toString() ?? originalValue;
  }

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by reading and parsing the contents of the file at [path].
  factory Json5.fromFile(String path, {bool caseSensitiveKeys = false, bool readOnly = false}) =>
      io.fromFile(caseSensitiveKeys: caseSensitiveKeys, path: path, readOnly: readOnly);

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by performing a deep copy from another Json5 object.
  factory Json5.fromJson5(Json5 json5, {bool caseSensitiveKeys = false, bool readOnly = false}) =>
      Json5(caseSensitiveKeys: caseSensitiveKeys, readOnly: readOnly)..setFromJson(json5);

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a list of keys and a list of values. The values are lined up
  /// positionally with the keys.
  factory Json5.fromKeyAndValueLists({
    bool caseSensitiveKeys = false,
    required List<String> keyList,
    bool readOnly = false,
    required List<dynamic> valueList,
  }) =>
      Json5(caseSensitiveKeys: caseSensitiveKeys, readOnly: readOnly)
        ..setFromkeyAndValueLists(keyList, valueList);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): explain this more
  /// Creates a Json5 object from a map of key to index and a list of values.
  factory Json5.fromKeyToIndexMapAndValueList({
    bool caseSensitiveKeys = false,
    required Map<String, int> keyToIndexMap,
    bool readOnly = false,
    required List<dynamic> valueList,
  }) =>
      Json5(caseSensitiveKeys: caseSensitiveKeys, readOnly: readOnly)
        ..setFromkeyToIndexAndValueList(keyToIndexMap, valueList);

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a Map.
  factory Json5.fromMap(
    Map<dynamic, dynamic> map, {
    bool caseSensitiveKeys = false,
    bool readOnly = false,
  }) => Json5(caseSensitiveKeys: caseSensitiveKeys, readOnly: readOnly)..addAll(map);

  //--------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string into a Json5 object.
  factory Json5.fromString(
    String jsonString, {
    bool caseSensitiveKeys = false,
    bool readOnly = false,
  }) => Json5Parser.decode(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    readOnly: readOnly,
  );

  //--------------------------------------------------------------------------------------------------
  /// Creates an empty Json5 object.
  Json5({this.caseSensitiveKeys = false, this.readOnly = false})
    : _keyToValueMap = caseSensitiveKeys
          ? {}
          : LinkedHashMap(
              equals: (String a, String b) {
                if (a.length != b.length) return false;
                for (int i = 0; i < a.length; i++) {
                  int unitA = a.codeUnitAt(i);
                  int unitB = b.codeUnitAt(i);
                  if (unitA == unitB) {
                    continue;
                  }
                  if (unitA > 127 || unitB > 127) {
                    return a.toLowerCase() == b.toLowerCase();
                  }
                  if (unitA >= 65 && unitA <= 90) unitA |= 0x20;
                  if (unitB >= 65 && unitB <= 90) unitB |= 0x20;
                  if (unitA != unitB) return false;
                }
                return true;
              },
              hashCode: (String s) {
                for (int i = 0; i < s.length; i++) {
                  if (s.codeUnitAt(i) > 127) {
                    return s.toLowerCase().hashCode;
                  }
                }
                int hash = 0;
                for (int i = 0; i < s.length; i++) {
                  int unit = s.codeUnitAt(i);
                  if (unit >= 65 && unit <= 90) unit |= 0x20;
                  hash = 0x1fffffff & (hash + unit);
                  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
                  hash ^= hash >> 6;
                }
                return hash;
              },
            );

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void operator []=(dynamic key, dynamic value) => set(key, value);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [addAll] as a [void].
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
  /// Gets the [asDoubleList] as a [List<double>].
  List<double> asDoubleList(final dynamic key) {
    List<double> result;
    final List<dynamic>? list = _keyToValueMap[_getkey(key)] as List<dynamic>?;
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
  /// Gets the [asDynamicList] as a [List<dynamic>].
  List<dynamic> asDynamicList(final dynamic key) {
    final dynamic result = _keyToValueMap[_getkey(key)];
    if (result is List<dynamic>) {
      return result;
    }
    return emptyDynamicList;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asIntList] as a [List<int>].
  List<int> asIntList(final dynamic key) {
    List<int> result;
    final List<dynamic>? list = _keyToValueMap[_getkey(key)] as List<dynamic>?;
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
  Json5 asJson(final dynamic key) => _keyToValueMap[_getkey(key)] as Json5? ?? emptyJson;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asJsonList] as a [List<Json5>].
  List<Json5> asJsonList(final dynamic key) {
    List<Json5> result;
    final List<dynamic>? list = _keyToValueMap[_getkey(key)] as List<dynamic>?;
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
  /// Gets the [asStringList] as a [List<String>].
  List<String> asStringList(final dynamic key) {
    List<String> result;
    final List<dynamic>? list = _keyToValueMap[_getkey(key)] as List<dynamic>?;
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
  dynamic asType(dynamic key) => _keyToValueMap[_getkey(key)];

  //--------------------------------------------------------------------------------------------------
  void _convertList(List<dynamic> list) {
    for (int listIndex = 0; listIndex < list.length; ++listIndex) {
      switch (list[listIndex]) {
        case Map<dynamic, dynamic> mapValue:
          list[listIndex] = Json5.fromMap(mapValue, caseSensitiveKeys: caseSensitiveKeys);
        case List<dynamic> listValue:
          _convertList(listValue);
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _convertMap() {
    _keyToValueMap.forEach((final String key, final dynamic value) {
      switch (value) {
        case Map<dynamic, dynamic> mapValue:
          _keyToValueMap[key] = Json5.fromMap(mapValue, caseSensitiveKeys: caseSensitiveKeys);
        case List<dynamic> listValue:
          _convertList(listValue);
      }
    });
  }

  //--------------------------------------------------------------------------------------------------
  void _formatEntry({
    required StringBuffer buffer,
    required bool json5,
    required String key,
    required int level,
    required dynamic value,
  }) {
    final String prefix = "  " * level;
    buffer
      ..write(prefix)
      ..write(json5 ? "" : '"')
      ..write(key)
      ..write(json5 ? "" : '"')
      ..write(": ");
    if (value is Json5) {
      _formatMap(buffer: buffer, json5: json5, level: level, map: value._keyToValueMap);
    } else if (value is List) {
      _formatList(buffer: buffer, json5: json5, level: level, list: value);
    } else if (value is String) {
      buffer
        ..write('"')
        ..write(_escapeString(value))
        ..write('"');
    } else if (value is num || value is bool || value == null) {
      buffer.write(value);
    } else {
      buffer
        ..write('"')
        ..write(_escapeString(value.toString()))
        ..write('"');
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _formatList({
    required StringBuffer buffer,
    required bool json5,
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
          _formatMap(buffer: buffer, json5: json5, level: level + 1, map: jsonValue._keyToValueMap);
        case List<dynamic> listValue:
          _formatList(buffer: buffer, json5: json5, level: level + 1, list: listValue);
        case String stringValue:
          buffer
            ..write(prefix)
            ..write('"')
            ..write(_escapeString(stringValue))
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
    required bool json5,
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
      _formatEntry(buffer: buffer, json5: json5, key: key, level: level + 1, value: map[key]);
      buffer.writeln(json5 || i < sortedKeys.length - 1 ? "," : "");
    }
    buffer
      ..write("  " * level)
      ..write("}");
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [keyToValueMap.entries;] as a [=>].
  Iterable<MapEntry<String, dynamic>> get entries => _keyToValueMap.entries;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [keyToValueMap.isEmpty;] as a [=>].
  bool get isEmpty => _keyToValueMap.isEmpty;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [keyToValueMap.isNotEmpty;] as a [=>].
  bool get isNotEmpty => _keyToValueMap.isNotEmpty;

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
  /// Gets the [keyToValueMap.keys;] as a [=>].
  Iterable<String> get keys => _keyToValueMap.keys;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [keyToValueMap.length;] as a [=>].
  int get length => _keyToValueMap.length;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [set] as a [void].
  void set(dynamic key, final dynamic value) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    String localKey = _getkey(key);
    switch (value) {
      case null:
        _keyToValueMap.remove(localKey);
      case DateTime dateTimeValue:
        _keyToValueMap[localKey] = dateTimeValue.formatIso8601();
      case Map<dynamic, dynamic> mapValue:
        _keyToValueMap[localKey] = Json5.fromMap(mapValue, caseSensitiveKeys: caseSensitiveKeys);
      default:
        _keyToValueMap[localKey] = value;
    }
  }

  //--------------------------------------------------------------------------------------------------
  @internal
  /// Internal use.
  // ignore: avoid_setters_without_getters
  set commentRegistry(Json5CommentRegistry commentRegistry) => _commentRegistry = commentRegistry;

  //--------------------------------------------------------------------------------------------------
  /// Copies entries from [copyFromJson] into this object.
  /// Performs a deep copy of nested Json5 objects and Lists.
  void setFromJson(final Json5 copyFromJson) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<String, dynamic> newEntry in copyFromJson._keyToValueMap.entries) {
      final dynamic value = newEntry.value;
      switch (value) {
        case List<dynamic> listValue:
          _keyToValueMap[newEntry.key] = _copyList(listValue);
        case Json5 jsonValue:
          _keyToValueMap[newEntry.key] = Json5.fromJson5(
            jsonValue,
            caseSensitiveKeys: caseSensitiveKeys,
          );
        default:
          _keyToValueMap[newEntry.key] = value;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [setFromMap] as a [void].
  void setFromMap(final Map<dynamic, dynamic> copyFromMap) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<dynamic, dynamic> entry in copyFromMap.entries) {
      set(entry.key, entry.value);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [setFromkeyAndValueLists] as a [void].
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
  /// Gets the [setFromkeyToIndexAndValueList] as a [void].
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
  /// Gets the [setIfChanged] as a [void].
  void setIfChanged(final dynamic key, final Json5 oldJson, final dynamic newValue) {
    String localKey = _getkey(key);
    if (newValue != oldJson._keyToValueMap[localKey]) {
      set(localKey, newValue);
    }
    return;
  }

  //--------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not null and not empty (for Strings, Iterables,
  /// Maps, and Json5 objects).
  void setIfNewValueIsNotEmpty(dynamic key, final dynamic newValue) {
    if (newValue == null) return;
    if (newValue is String && newValue.isEmpty) return;
    if (newValue is Iterable && newValue.isEmpty) return;
    if (newValue is Map && newValue.isEmpty) return;
    if (newValue is Json5 && newValue._keyToValueMap.isEmpty) return;
    set(key, newValue);
  }

  //--------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not equal to [oldValue].
  /// For Iterables, equality is determined by having the same elements in the same order.
  /// For Maps, equality is determined by having the same keys with
  /// equal values. For Json5 objects, equality is determined by having the same keys with equal
  /// values.
  /// For other types, equality is determined by the == operator.
  void setIfNotEqual(dynamic key, {required dynamic newValue, required dynamic oldValue}) {
    bool isEqual(dynamic a, dynamic b) {
      if (identical(a, b)) return true;
      if (a is Json5 && b is Json5) {
        if (a._keyToValueMap.length != b._keyToValueMap.length) return false;
        for (final String k in a._keyToValueMap.keys) {
          if (!b._keyToValueMap.containsKey(k)) return false;
          if (!isEqual(a._keyToValueMap[k], b._keyToValueMap[k])) return false;
        }
        return true;
      }
      if (a is Map<dynamic, dynamic> && b is Map<dynamic, dynamic>) {
        if (a.length != b.length) return false;
        for (final Object? k in a.keys) {
          if (!b.containsKey(k)) return false;
          if (!isEqual(a[k], b[k])) return false;
        }
        return true;
      }
      if (a is Iterable<dynamic> && b is Iterable<dynamic>) {
        if (a.length != b.length) return false;
        final Iterator<dynamic> itA = a.iterator;
        final Iterator<dynamic> itB = b.iterator;
        while (itA.moveNext() && itB.moveNext()) {
          if (!isEqual(itA.current, itB.current)) return false;
        }
        return true;
      }
      return a == b;
    }

    if (!isEqual(oldValue, newValue)) {
      set(key, newValue);
    }
  }

  //--------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not null.
  void setIfNewValueIsNotNull(dynamic key, final dynamic newValue) {
    if (newValue != null) {
      set(key, newValue);
    }
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns a pretty-printed JSON or JSON5 string with 2-space indentation.
  String toFormattedString({bool json5 = true}) {
    StringBuffer result = StringBuffer();
    _formatMap(buffer: result, json5: json5, level: 0, map: _keyToValueMap);
    return result.toString();
  }

  //--------------------------------------------------------------------------------------------------
  /// Generates a JSON5 or JSON string representation of the object. For a pretty-printed version,
  /// use [toFormattedString]. Use [json5]: false to return a JSON string (the default is a JSON5
  /// string).
  String toJsonString({bool json5 = true}) {
    final buffer = StringBuffer("{");
    bool firstEntry = true;
    _keyToValueMap.forEach((String key, dynamic value) {
      buffer
        ..write(firstEntry ? "" : ",")
        ..write(json5 ? "" : '"')
        ..write(key)
        ..write(json5 ? "" : '"')
        ..write(":")
        ..write(_valueToString(value, json5: json5));
      firstEntry = false;
    });
    if (!firstEntry && json5) {
      buffer.write(",");
    }
    buffer.write("}");
    return buffer.toString();
  }

  //--------------------------------------------------------------------------------------------------
  @override
  String toString() => toJsonString();

  //--------------------------------------------------------------------------------------------------
  String _valueToString(dynamic value, {bool json5 = true}) => switch (value) {
    String stringValue => '"${_escapeString(stringValue)}"',
    num numValue => numValue.toString(),
    bool boolValue => boolValue ? "true" : "false",
    Json5 jsonValue => jsonValue.toJsonString(json5: json5),
    List<dynamic> listValue =>
      "[${listValue.map((e) => _valueToString(e, json5: json5)).join(",")}]",
    Enum enumValue => '"${_getkey(enumValue)}"',
    null => "null",
    var v =>
      json5Util.isEnum(v)
          ? '"${v.toString().split('.').last}"'
          : '"${_escapeString(v.toString())}"',
  };

  //--------------------------------------------------------------------------------------------------
}
