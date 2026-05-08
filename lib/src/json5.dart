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
  static List<dynamic> _copyList(final List<dynamic> otherList) {
    final List<dynamic> resultList = [];
    for (final dynamic listItem in otherList) {
      switch (listItem) {
        case List<dynamic> listValue:
          resultList.add(_copyList(listValue));
        case Json5 json5Value:
          resultList.add(
            Json5.fromJson5(json5Value, caseSensitiveKeys: json5Value.caseSensitiveKeys),
          );
        default:
          resultList.add(listItem);
      }
    }
    return resultList;
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
        ..setFromKeyAndValueLists(keyList, valueList);

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
        ..setFromKeyToIndexAndValueList(keyToIndexMap, valueList);

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a Map.
  factory Json5.fromMap(
    Map<dynamic, dynamic> jsonMap, {
    bool caseSensitiveKeys = false,
    bool readOnly = false,
  }) => Json5(caseSensitiveKeys: caseSensitiveKeys, readOnly: readOnly)..addAll(jsonMap);

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
              equals: (String stringA, String stringB) {
                if (stringA.length != stringB.length) return false;
                for (int i = 0; i < stringA.length; ++i) {
                  int codeUnitA = stringA.codeUnitAt(i);
                  int codeUnitB = stringB.codeUnitAt(i);
                  if (codeUnitA == codeUnitB) {
                    continue;
                  }
                  if (codeUnitA > 127 || codeUnitB > 127) {
                    return stringA.toLowerCase() == stringB.toLowerCase();
                  }
                  if (codeUnitA >= 65 && codeUnitA <= 90) codeUnitA |= 0x20;
                  if (codeUnitB >= 65 && codeUnitB <= 90) codeUnitB |= 0x20;
                  if (codeUnitA != codeUnitB) return false;
                }
                return true;
              },
              hashCode: (String stringValue) {
                for (int i = 0; i < stringValue.length; ++i) {
                  if (stringValue.codeUnitAt(i) > 127) {
                    return stringValue.toLowerCase().hashCode;
                  }
                }
                int hash = 0;
                for (int i = 0; i < stringValue.length; ++i) {
                  int codeUnit = stringValue.codeUnitAt(i);
                  if (codeUnit >= 65 && codeUnit <= 90) codeUnit |= 0x20;
                  hash = 0x1fff_ffff & (hash + codeUnit);
                  hash = 0x1fff_ffff & (hash + ((0x0007_ffff & hash) << 10));
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
  void addAll(Map<dynamic, dynamic>? jsonMap) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    if (jsonMap == null || jsonMap.isEmpty) {
      return;
    }
    for (final MapEntry<dynamic, dynamic> entry in jsonMap.entries) {
      set(entry.key, entry.value);
    }
    _convertMap();
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asDoubleList] as a [List<double>].
  List<double> asDoubleList(final dynamic key) {
    List<double> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyDoubleList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem is num) {
        resultList.add(listItem.toDouble());
      } else {
        resultList.add(listItem.toString().toDouble());
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asDynamicList] as a [List<dynamic>].
  List<dynamic> asDynamicList(final dynamic key) {
    final dynamic resultList = _keyToValueMap[_getKey(key)];
    if (resultList is List<dynamic>) {
      return resultList;
    }
    return emptyDynamicList;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asIntList] as a [List<int>].
  List<int> asIntList(final dynamic key) {
    List<int> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyIntList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem is num) {
        resultList.add(listItem.toInt());
      } else {
        resultList.add(listItem.toString().toInt());
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  /// @return EmptyJson if no entry is found.
  Json5 asJson(final dynamic key) => _keyToValueMap[_getKey(key)] as Json5? ?? emptyJson;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asJsonList] as a [List<Json5>].
  List<Json5> asJsonList(final dynamic key) {
    List<Json5> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyJsonList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem is Json5) {
        resultList.add(listItem);
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Gets the [asStringList] as a [List<String>].
  List<String> asStringList(final dynamic key) {
    List<String> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyStringList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem != null) {
        resultList.add(listItem.toString());
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  @override
  @internal
  dynamic asType(dynamic key) => _keyToValueMap[_getKey(key)];

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
    for (final MapEntry<String, dynamic> entry in _keyToValueMap.entries) {
      final String key = entry.key;
      switch (entry.value) {
        case Map<dynamic, dynamic> mapValue:
          _keyToValueMap[key] = Json5.fromMap(mapValue, caseSensitiveKeys: caseSensitiveKeys);
        case List<dynamic> listValue:
          _convertList(listValue);
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _formatEntry({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
    required int index,
    required bool json5,
    required String key,
    required int level,
    required dynamic value,
  }) {
    final String prefix = "  " * level;
    buffer.write(prefix);
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: index,
      level: level,
      location: ECommentLocation.beforeColon,
      skipPrecedingNewline: true,
    );
    buffer
      ..write(json5 ? "" : '"')
      ..write(key)
      ..write(json5 ? "" : '"')
      ..write(":");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: index,
      level: level,
      location: ECommentLocation.afterColon,
    );
    buffer.write(" ");
    if (value is Json5) {
      _formatMap(
        buffer: buffer,
        container: value,
        includeComments: includeComments,
        json5: json5,
        jsonMap: value._keyToValueMap,
        level: level,
      );
    } else if (value is List) {
      _formatList(
        buffer: buffer,
        container: value,
        dynamicList: value,
        includeComments: includeComments,
        json5: json5,
        level: level,
      );
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
    required Object container,
    required List<dynamic> dynamicList,
    required bool includeComments,
    required bool json5,
    required int level,
  }) {
    if (dynamicList.isEmpty) {
      buffer.write("[]");
      return;
    }
    buffer.write("[");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: 0,
      level: level + 1,
      location: ECommentLocation.standaloneBefore,
    );
    buffer.writeln();
    final String prefix = "  " * (level + 1);
    for (int i = 0; i < dynamicList.length; ++i) {
      dynamic value = dynamicList[i];
      switch (value) {
        case Json5 jsonValue:
          buffer.write(prefix);
          _formatMap(
            buffer: buffer,
            container: jsonValue,
            includeComments: includeComments,
            json5: json5,
            jsonMap: jsonValue._keyToValueMap,
            level: level + 1,
          );
        case List<dynamic> listValue:
          buffer.write(prefix);
          _formatList(
            buffer: buffer,
            container: listValue,
            dynamicList: listValue,
            includeComments: includeComments,
            json5: json5,
            level: level + 1,
          );
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
      if (json5 || i < dynamicList.length - 1) {
        buffer.write(",");
      }
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.beforeComma,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.afterComma,
      );
      buffer.writeln();
    }
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: dynamicList.length,
      level: level + 1,
      location: ECommentLocation.standaloneAfter,
      skipPrecedingNewline: true,
    );
    buffer
      ..write("  " * level)
      ..write("]");
  }

  //--------------------------------------------------------------------------------------------------
  void _formatMap({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
    required bool json5,
    required Map<String, dynamic> jsonMap,
    required int level,
  }) {
    if (jsonMap.isEmpty) {
      buffer.write("{}");
      return;
    }
    buffer.write("{");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: 0,
      level: level + 1,
      location: ECommentLocation.standaloneBefore,
    );
    buffer.writeln();
    final List<String> sortedKeyList = jsonMap.keys.toList();
    for (int i = 0; i < sortedKeyList.length; ++i) {
      final String key = sortedKeyList[i];
      _formatEntry(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        json5: json5,
        key: key,
        level: level + 1,
        value: jsonMap[key],
      );
      if (json5 || i < sortedKeyList.length - 1) {
        buffer.write(",");
      }
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.beforeComma,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.afterComma,
      );
      buffer.writeln();
    }
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      index: sortedKeyList.length,
      level: level + 1,
      location: ECommentLocation.standaloneAfter,
      skipPrecedingNewline: true,
    );
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
  String _getKey(dynamic key) {
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
    String localKey = _getKey(key);
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
  /// Gets the [setFromKeyAndValueLists] as a [void].
  void setFromKeyAndValueLists(List<String>? keyList, List<dynamic>? valueList) {
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
  /// Gets the [setFromKeyToIndexAndValueList] as a [void].
  void setFromKeyToIndexAndValueList(Map<String, int>? keyToIndexMap, List<dynamic>? valueList) {
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
    String localKey = _getKey(key);
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
    bool isEqual(dynamic valueA, dynamic valueB) {
      if (identical(valueA, valueB)) return true;
      if (valueA is Json5 && valueB is Json5) {
        if (valueA._keyToValueMap.length != valueB._keyToValueMap.length) return false;
        for (final String mapKey in valueA._keyToValueMap.keys) {
          if (!valueB._keyToValueMap.containsKey(mapKey)) return false;
          if (!isEqual(valueA._keyToValueMap[mapKey], valueB._keyToValueMap[mapKey])) return false;
        }
        return true;
      }
      if (valueA is Map<dynamic, dynamic> && valueB is Map<dynamic, dynamic>) {
        if (valueA.length != valueB.length) return false;
        for (final Object? mapKey in valueA.keys) {
          if (!valueB.containsKey(mapKey)) return false;
          if (!isEqual(valueA[mapKey], valueB[mapKey])) return false;
        }
        return true;
      }
      if (valueA is Iterable<dynamic> && valueB is Iterable<dynamic>) {
        if (valueA.length != valueB.length) return false;
        final Iterator<dynamic> iteratorA = valueA.iterator;
        final Iterator<dynamic> iteratorB = valueB.iterator;
        while (iteratorA.moveNext() && iteratorB.moveNext()) {
          if (!isEqual(iteratorA.current, iteratorB.current)) return false;
        }
        return true;
      }
      return valueA == valueB;
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
  String toFormattedString({bool includeComments = true, bool json5 = true}) {
    StringBuffer result = StringBuffer();
    _formatMap(
      buffer: result,
      container: this,
      includeComments: includeComments,
      json5: json5,
      jsonMap: _keyToValueMap,
      level: 0,
    );
    return result.toString();
  }

  //--------------------------------------------------------------------------------------------------
  /// Generates a JSON5 or JSON string representation of the object. For a pretty-printed version,
  /// use [toFormattedString]. Use [json5]: false to return a JSON string (the default is a JSON5
  /// string).
  String toJsonString({bool json5 = true}) {
    final buffer = StringBuffer("{");
    bool firstEntry = true;
    for (final MapEntry<String, dynamic> entry in _keyToValueMap.entries) {
      buffer
        ..write(firstEntry ? "" : ",")
        ..write(json5 ? "" : '"')
        ..write(entry.key)
        ..write(json5 ? "" : '"')
        ..write(":")
        ..write(_valueToString(entry.value, json5: json5));
      firstEntry = false;
    }
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
  String _valueToString(dynamic value, {bool json5 = true}) {
    switch (value) {
      case String stringValue:
        return '"${_escapeString(stringValue)}"';
      case num numValue:
        return numValue.toString();
      case bool boolValue:
        return boolValue ? "true" : "false";
      case Json5 jsonValue:
        return jsonValue.toJsonString(json5: json5);
      case List<dynamic> listValue:
        final StringBuffer buffer = StringBuffer("[");
        for (int i = 0; i < listValue.length; ++i) {
          if (i > 0) {
            buffer.write(",");
          }
          buffer.write(_valueToString(listValue[i], json5: json5));
        }
        buffer.write("]");
        return buffer.toString();
      case Enum enumValue:
        return '"${_getKey(enumValue)}"';
      case null:
        return "null";
      default:
        if (json5Util.isEnum(value)) {
          return '"${value.toString().split(".").last}"';
        }
        return '"${_escapeString(value.toString())}"';
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _writeComments({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
    required int index,
    required int level,
    required ECommentLocation location,
    bool skipPrecedingNewline = false,
  }) {
    final Json5CommentRegistry? registry = _commentRegistry;
    if (!includeComments || registry == null) return;
    final List<Json5Comment>? comments = registry.getComments(container, index, location);
    if (comments == null) return;
    final String indent = "  " * level;
    for (int i = 0; i < comments.length; ++i) {
      final Json5Comment comment = comments[i];
      if (comment.precededByNewline) {
        if (!(skipPrecedingNewline && i == 0)) {
          buffer.writeln();
        }
        buffer.write(indent);
      } else {
        buffer.write(" ");
      }
      buffer.write(comment.comment);
    }
  }

  //--------------------------------------------------------------------------------------------------
}
