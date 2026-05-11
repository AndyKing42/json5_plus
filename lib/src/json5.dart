import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5_comment_registry.dart';
import 'json5_extensions.dart';
import 'json5_io_stub.dart' if (dart.library.io) 'json5_io_native.dart' as io;
import 'json5_parser.dart';
import 'json5_util.dart';
import 'typed_accessor_mixin.dart';

/// Represents a JSON object.
class Json5 with TypedAccessorMixin {
  //--------------------------------------------------------------------------------------------------
  /// An empty unmodifiable `bool` list.
  static final List<bool> emptyBoolList = List.unmodifiable([]);

  /// An empty unmodifiable `DateTime` list.
  static final List<DateTime> emptyDateTimeList = List.unmodifiable([]);

  /// An empty unmodifiable `double` list.
  static final List<double> emptyDoubleList = List.unmodifiable([]);

  /// An empty unmodifiable `dynamic` list.
  static final List<dynamic> emptyDynamicList = List.unmodifiable([]);

  /// An empty unmodifiable `int` list.
  static final List<int> emptyIntList = List.unmodifiable([]);

  /// An empty unmodifiable `Json5` object.
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
  /// Parses a string containing multiple JSON5 objects and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    bool caseSensitiveKeys = false,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
  }) => Json5Parser.decodeMultiple(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    params: params,
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
      } else if (codeUnit < 32) {
        buffer ??= StringBuffer(originalValue.substring(0, charIndex));
        buffer.write("\\u${codeUnit.toRadixString(16).padLeft(4, '0')}");
      } else {
        buffer?.writeCharCode(codeUnit);
      }
    }
    return buffer?.toString() ?? originalValue;
  }

  //--------------------------------------------------------------------------------------------------
  /// Decodes any JSON5 string into its dynamic Dart representation (which could be a Json5 object,
  /// List, String, num, bool, or null).
  static dynamic parseAny(
    String jsonString, {
    bool caseSensitiveKeys = false,
    Map<String, dynamic>? params,
    bool readOnly = false,
  }) => Json5Parser.decodeAny(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
  );

  //--------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by reading and parsing the contents of the file at [path].
  factory Json5.fromFile(
    String path, {
    bool caseSensitiveKeys = false,
    Map<String, dynamic>? params,
    bool readOnly = false,
  }) => io.fromFile(
    caseSensitiveKeys: caseSensitiveKeys,
    params: params,
    path: path,
    readOnly: readOnly,
  );

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
  /// Creates a Json5 object from a map of keys to indexes and a list of values. The indexes
  /// represent the position of the values in the list.
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
    Map<String, dynamic>? params,
    bool readOnly = false,
  }) => Json5Parser.decode(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
  );

  //--------------------------------------------------------------------------------------------------
  /// Creates an empty Json5 object.
  Json5({this.caseSensitiveKeys = false, this.readOnly = false})
    : _keyToValueMap = caseSensitiveKeys
          ? {}
          : LinkedHashMap(
              equals: (String s1, String s2) {
                final int len = s1.length;
                if (len != s2.length) {
                  return false;
                }
                for (int i = 0; i < len; ++i) {
                  int codeUnit1 = s1.codeUnitAt(i);
                  int codeUnit2 = s2.codeUnitAt(i);
                  if (codeUnit1 == codeUnit2) {
                    continue;
                  }
                  if (codeUnit1 > 127 || codeUnit2 > 127) {
                    return s1.toLowerCase() == s2.toLowerCase();
                  }
                  if (codeUnit1 >= 65 && codeUnit1 <= 90) {
                    codeUnit1 |= 0x20;
                  }
                  if (codeUnit2 >= 65 && codeUnit2 <= 90) {
                    codeUnit2 |= 0x20;
                  }
                  if (codeUnit1 != codeUnit2) {
                    return false;
                  }
                }
                return true;
              },
              hashCode: (String stringValue) {
                int hash = 0;
                final int len = stringValue.length;
                for (int i = 0; i < len; ++i) {
                  int codeUnit = stringValue.codeUnitAt(i);
                  if (codeUnit > 127) {
                    return stringValue.toLowerCase().hashCode;
                  }
                  if (codeUnit >= 65 && codeUnit <= 90) {
                    codeUnit |= 0x20;
                  }
                  hash = 0x1fff_ffff & (hash + codeUnit);
                  hash = 0x1fff_ffff & (hash + ((0x0007_ffff & hash) << 10));
                  hash ^= hash >> 6;
                }
                return hash;
              },
            );

  //--------------------------------------------------------------------------------------------------
  /// Delegates the assignment to the [set] method, for example, json5["asdf"] = 1 is equivalent to
  /// json5.set("asdf", 1).
  void operator []=(dynamic key, dynamic value) => set(key, value);

  //--------------------------------------------------------------------------------------------------
  /// Adds all entries from a [Map] to this Json5 object.
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
  /// Returns the list of [bool] values for [key].
  List<bool> asBoolList(final dynamic key) {
    List<bool> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyBoolList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem is bool) {
        resultList.add(listItem);
      } else if (listItem != null) {
        resultList.add(listItem.toString().toBool());
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns the list of [DateTime] values for [key].
  List<DateTime> asDateTimeList(final dynamic key) {
    List<DateTime> resultList;
    final List<dynamic>? dynamicList = _keyToValueMap[_getKey(key)] as List<dynamic>?;
    if (dynamicList == null) {
      return emptyDateTimeList;
    }
    resultList = [];
    for (final Object? listItem in dynamicList) {
      if (listItem is DateTime) {
        resultList.add(listItem);
      } else if (listItem is num) {
        resultList.add(DateTime.fromMillisecondsSinceEpoch(listItem.toInt()));
      } else if (listItem != null) {
        final DateTime? dt = listItem.toString().toDateTime();
        if (dt != null) resultList.add(dt);
      }
    }
    return resultList;
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns the list of [double] values for [key].
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
  /// Returns the list of values for [key].
  List<dynamic> asDynamicList(final dynamic key) {
    final dynamic resultList = _keyToValueMap[_getKey(key)];
    if (resultList is List<dynamic>) {
      return resultList;
    }
    return emptyDynamicList;
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns the list of [int] values for [key].
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
  /// Returns the [Json5] object for [key].
  Json5 asJson(final dynamic key) => _keyToValueMap[_getKey(key)] as Json5? ?? emptyJson;

  //--------------------------------------------------------------------------------------------------
  /// Returns the list of [Json5] values for [key].
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
  /// Returns the list of [String] values for [key].
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
  /// Clears all entries from this Json5 object.
  void clear() {
    assert(!readOnly, "Cannot clear a read-only JSON");
    _keyToValueMap.clear();
  }

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
    Json5CommentRegistry? registry,
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
      registry: registry,
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
      registry: registry,
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
        registry: value._commentRegistry ?? registry,
      );
    } else if (value is List) {
      _formatList(
        buffer: buffer,
        container: value,
        dynamicList: value,
        includeComments: includeComments,
        json5: json5,
        level: level,
        registry: registry,
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
    Json5CommentRegistry? registry,
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
      registry: registry,
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
            registry: jsonValue._commentRegistry ?? registry,
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
            registry: registry,
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
        registry: registry,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.afterComma,
        registry: registry,
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
      registry: registry,
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
    Json5CommentRegistry? registry,
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
      registry: registry,
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
        registry: registry,
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
        registry: registry,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        index: i,
        level: level + 1,
        location: ECommentLocation.afterComma,
        registry: registry,
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
      registry: registry,
      skipPrecedingNewline: true,
    );
    buffer
      ..write("  " * level)
      ..write("}");
  }

  //--------------------------------------------------------------------------------------------------
  /// Returns the key/value entries for this Json5 object.
  Iterable<MapEntry<String, dynamic>> get entries => _keyToValueMap.entries;

  //--------------------------------------------------------------------------------------------------
  /// Returns true if this Json5 object is empty.
  bool get isEmpty => _keyToValueMap.isEmpty;

  //--------------------------------------------------------------------------------------------------
  /// Returns true if this Json5 object is not empty.
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
  /// Returns the keys for this Json5 object.
  Iterable<String> get keys => _keyToValueMap.keys;

  //--------------------------------------------------------------------------------------------------
  /// Returns the number of key/value pairs in this Json5 object.
  int get length => _keyToValueMap.length;

  //--------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its value.
  dynamic remove(dynamic key) {
    assert(!readOnly, "Cannot remove entries from a read-only JSON");
    return _keyToValueMap.remove(_getKey(key));
  }

  //--------------------------------------------------------------------------------------------------
  /// Sets the value for [key] to [value].
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
  /// Updates this Json5 object with the entries from [copyFromMap].
  void setFromMap(final Map<dynamic, dynamic> copyFromMap) {
    assert(!readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<dynamic, dynamic> entry in copyFromMap.entries) {
      set(entry.key, entry.value);
    }
  }

  //--------------------------------------------------------------------------------------------------
  /// Updates this Json5 object with the entries from [keyList] and [valueList].
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
  /// Updates this Json5 object with the entries from [keyToIndexMap] and [valueList].
  void setFromKeyToIndexAndValueList(Map<String, int>? keyToIndexMap, List<dynamic>? valueList) {
    if (keyToIndexMap == null || valueList == null) {
      return;
    }
    for (final MapEntry<String, int> keyToIndex in keyToIndexMap.entries) {
      set(keyToIndex.key, valueList[keyToIndex.value]);
    }
  }

  //--------------------------------------------------------------------------------------------------
  /// Sets the value for [key] if the [newValue] has changed for the [oldJson] value.
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
  /// Writes the formatted JSON5 representation of this object to the file at [path].
  void toFile(String path, {bool includeComments = true, bool json5 = true}) =>
      io.toFile(this, path, includeComments: includeComments, json5: json5);

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
      registry: _commentRegistry,
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
  /// Converts this Json5 object to a standard [Map].
  Map<String, dynamic> toMap() => Map.of(_keyToValueMap);

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
    Json5CommentRegistry? registry,
    bool skipPrecedingNewline = false,
  }) {
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
