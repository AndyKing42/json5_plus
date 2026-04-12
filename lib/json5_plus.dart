import 'dart:collection';
import 'dart:convert';

import 'json5_accessor.dart';
import 'json5_extensions.dart';
import 'json5_util.dart';

part 'src/json5_parser.dart';

/// Represents a JSON object as a map of keys (strings) to values (objects). The values can be of
/// type String, double, int, Json5, list of objects, or Boolean.
class Json5 with Json5Accessor {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  static final List<double> emptyDoubleList = List.unmodifiable([]);
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

  final SplayTreeMap<String, dynamic> _keyToValueMap;
  bool _readOnly;

  //--------------------------------------------------------------------------------------------------
  static List<dynamic> _copyList(final List<dynamic> other) {
    final List<dynamic> result = [];
    for (final dynamic listItem in other) {
      if (listItem is List) {
        result.add(_copyList(listItem));
      } else if (listItem is Json5) {
        result.add(Json5(json: listItem));
      } else {
        result.add(listItem);
      }
    }
    return result;
  }

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
    for (final MapEntry<String, dynamic> entry in json2._keyToValueMap.entries) {
      if (json1._keyToValueMap[entry.key] != entry.value) {
        result._keyToValueMap[entry.key] = entry.value;
      }
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Json5({
    Json5? json,
    String? jsonString,
    Map<dynamic, dynamic>? map,
    List<String>? keyList,
    Map<String, int>? keyToIndexMap,
    bool readOnly = false,
    List<dynamic>? valueList,
  }) : _keyToValueMap = SplayTreeMap((String key1, String key2) => key1.compareToIgnoreCase(key2)),
       _readOnly = false {
    if (json != null) {
      for (final MapEntry<String, dynamic> entry in json._keyToValueMap.entries) {
        switch (entry.value) {
          case List<dynamic> listValue:
            _keyToValueMap[entry.key] = _copyList(listValue);
          case Json5 jsonValue:
            _keyToValueMap[entry.key] = Json5(json: jsonValue);
          default:
            _keyToValueMap[entry.key] = entry.value;
        }
      }
    }
    if (jsonString != null && jsonString.isNotEmpty) {
      _Json5Parser(jsonString).parseInto(this);
    }
    if (map != null) {
      addAll(map);
    }
    setFromkeyAndValueLists(keyList, valueList);
    setFromkeyToIndexAndValueList(keyToIndexMap, valueList);
    _readOnly = readOnly;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void addAll(Map<dynamic, dynamic>? map) {
    assert(!_readOnly, "Cannot add entries to a read-only JSON");
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
  ///
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
  ///
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
  ///
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
  dynamic asType(dynamic key) => _keyToValueMap[_getkey(key)];

  //--------------------------------------------------------------------------------------------------
  void _convertList(List<dynamic> list) {
    for (int listIndex = 0; listIndex < list.length; ++listIndex) {
      if (list[listIndex] is Map) {
        list[listIndex] = Json5(map: list[listIndex] as Map<dynamic, dynamic>);
      } else if (list[listIndex] is List) {
        _convertList(list[listIndex] as List<dynamic>);
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _convertMap() {
    _keyToValueMap.forEach((final String key, final dynamic value) {
      if (value is Map) {
        _keyToValueMap[key] = Json5(map: value);
      } else if (value is List) {
        _convertList(value);
      }
    });
  }

  //--------------------------------------------------------------------------------------------------
  void _formatEntry({
    required StringBuffer buffer,
    required MapEntry<String, dynamic> entry,
    required int level,
  }) {
    String prefix = "  " * level;
    final dynamic value = entry.value;
    switch (value) {
      case bool boolValue:
        buffer.writeln('$prefix"${entry.key}":${boolValue ? "true" : "false"}');
      case List<dynamic> listValue:
        _formatList(buffer: buffer, level: level, list: listValue);
      case Map<String, dynamic> mapValue:
        _formatMap(buffer: buffer, level: level, map: mapValue);
      case num numValue:
        buffer.writeln('$prefix"${entry.key}":$numValue');
      case String stringValue:
        buffer.writeln('$prefix"${entry.key}":"$stringValue"');
    }
  }

  //--------------------------------------------------------------------------------------------------
  void _formatList({
    required StringBuffer buffer,
    required int level,
    required List<dynamic> list,
  }) {}

  //--------------------------------------------------------------------------------------------------
  void _formatMap({
    required StringBuffer buffer,
    required int level,
    required Map<String, dynamic> map,
  }) {
    String prefix = "  " * level;
    buffer.writeln("{");
    for (final MapEntry<String, dynamic> entry in map.entries) {
      _formatEntry(buffer: buffer, entry: entry, level: level);
    }
    buffer.writeln("}");
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Iterable<MapEntry<String, dynamic>> get entries => _keyToValueMap.entries;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  String get jsonString {
    String result = '{';
    bool firstEntry = true;
    _keyToValueMap.forEach((String key, dynamic value) {
      result += firstEntry ? '' : ',';
      result += '"$key":${_valueToString(value)}';
      firstEntry = false;
    });
    result += '}';
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  Iterable<String> get keys => _keyToValueMap.keys;

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
  Map<String, dynamic> get keyToValueMap => _keyToValueMap;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void set(dynamic key, final dynamic value) {
    assert(!_readOnly, "Cannot add entries to a read-only JSON");
    String localKey = _getkey(key);
    if (value == null) {
      _keyToValueMap.remove(localKey);
      return;
    }
    if (value is DateTime) {
      _keyToValueMap[localKey] = value.formatIso8601();
      return;
    }
    if (value is Map) {
      _keyToValueMap[localKey] = Json5(map: value);
      return;
    }
    _keyToValueMap[localKey] = value;
  }

  //--------------------------------------------------------------------------------------------------
  /// Copies entries from [copyFromJson] into this object.
  /// Performs a deep copy of nested Json5 objects and Lists.
  void setFromJson(final Json5 copyFromJson) {
    assert(!_readOnly, "Cannot add entries to a read-only JSON");
    for (final MapEntry<String, dynamic> newEntry in copyFromJson._keyToValueMap.entries) {
      final dynamic value = newEntry.value;

      if (value is List<dynamic>) {
        _keyToValueMap[newEntry.key] = _copyList(value);
      } else if (value is Json5) {
        _keyToValueMap[newEntry.key] = Json5(json: value);
      } else {
        // Primitives (String, num, bool, null, Enum) are immutable in Dart,
        // so a direct assignment is perfectly safe for a deep copy.
        _keyToValueMap[newEntry.key] = value;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void setFromMap(final Map<dynamic, dynamic> copyFromMap) {
    assert(!_readOnly, "Cannot add entries to a read-only JSON");
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
    if (newValue != oldJson._keyToValueMap[localKey]) {
      set(localKey, newValue);
    }
    return;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  String toFormattedString() => JsonEncoder.withIndent("  ").convert(jsonDecode(jsonString));

  //--------------------------------------------------------------------------------------------------
  @override
  String toString() => jsonString;

  //--------------------------------------------------------------------------------------------------
  String _valueToString(dynamic value) {
    if (value is String) {
      return '"${escapeString(value)}"';
    }
    if (value is num) {
      return value.toString();
    }
    if (value is bool) {
      return value ? "true" : "false";
    }
    if (value is Json5) {
      return value.jsonString;
    }
    if (value is List) {
      return '[${value.map(_valueToString).join(',')}]';
    }
    if (value is Enum) {
      return '"${_getkey(value)}"';
    }
    if (value == null) {
      return "null";
    }
    if (json5Util.isEnum(value)) {
      String valueString = value.toString();
      return '"${valueString.substring(valueString.indexOf(".") + 1)}"';
    }
    return '"${escapeString(value.toString())}"';
  }

  //--------------------------------------------------------------------------------------------------
}
