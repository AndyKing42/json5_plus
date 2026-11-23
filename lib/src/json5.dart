import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5_comment_registry.dart';
import 'json5_extensions.dart';
import 'json5_io_stub.dart' if (dart.library.io) 'json5_io_native.dart' as io;
import 'json5_parser.dart';
import 'json5_util.dart';
import 'typed_accessor_mixin.dart';

//==================================================================================================
/// Supported DateTime serialization formats.
enum EDateTimeFormat {
  /// Standard ISO 8601 format (e.g. `2026-08-12T15:48:31Z`).
  iso8601,

  /// Compact YYYYMMDDHHMMSS format (e.g. `20260812154831`).
  yyyymmddhhmmss,
}

//==================================================================================================
/// Represents a JSON5 object.
class Json5 with TypedAccessorMixin {
  //------------------------------------------------------------------------------------------------
  /// Default setting for whether [Json5.fromString] allows a blank string input (`false` by default).
  static bool defaultAllowBlankString = false;

  /// Default DateTime format used for DateTime accessors and serialization.
  static EDateTimeFormat defaultDateTimeFormat = EDateTimeFormat.iso8601;

  /// Default format used by [toJsonString] and [toString] (`true` for JSON5, `false` for standard JSON).
  static bool defaultUseJson5ForToString = true;

  /// Default setting for whether newly constructed `Json5` objects sort their keys case-insensitively.
  static bool defaultUseSortedKeys = false;

  /// An empty unmodifiable `bool` list.
  static final List<bool> emptyBoolList = List.unmodifiable([]);

  /// An empty unmodifiable `bool` set.
  static final Set<bool> emptyBoolSet = Set.unmodifiable({});

  /// An empty unmodifiable `DateTime` list.
  static final List<DateTime> emptyDateTimeList = List.unmodifiable([]);

  /// An empty unmodifiable `DateTime` set.
  static final Set<DateTime> emptyDateTimeSet = Set.unmodifiable({});

  /// An empty unmodifiable `double` list.
  static final List<double> emptyDoubleList = List.unmodifiable([]);

  /// An empty unmodifiable `double` set.
  static final Set<double> emptyDoubleSet = Set.unmodifiable({});

  /// An empty unmodifiable `dynamic` list.
  static final List<dynamic> emptyDynamicList = List.unmodifiable([]);

  /// An empty unmodifiable `dynamic` set.
  static final Set<dynamic> emptyDynamicSet = Set.unmodifiable({});

  /// An empty unmodifiable `int` list.
  static final List<int> emptyIntList = List.unmodifiable([]);

  /// An empty unmodifiable `int` set.
  static final Set<int> emptyIntSet = Set.unmodifiable({});

  /// An empty unmodifiable `Json5` object.
  static final Json5 emptyJson = Json5(readOnly: true);

  /// An empty unmodifiable `Json5` list.
  static final List<Json5> emptyJsonList = List.unmodifiable([]);

  /// An empty unmodifiable `Json5` set.
  static final Set<Json5> emptyJsonSet = Set.unmodifiable({});

  /// An empty unmodifiable `String` list.
  static final List<String> emptyStringList = List.unmodifiable([]);

  /// An empty unmodifiable `String` set.
  static final Set<String> emptyStringSet = Set.unmodifiable({});
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

  /// The DateTime format used by this object.
  final EDateTimeFormat dateTimeFormat;
  Set<String>? _ephemeralKeys;
  final Map<String, dynamic> _keyToValueMap;

  /// Indicates whether this Json5 object is read-only.
  final bool readOnly;

  /// Indicates whether JSON keys are sorted case-insensitively.
  final bool sortedKeys;

  //------------------------------------------------------------------------------------------------
  static int _caseInsensitiveCompare(String key1, String key2) {
    final int len = key1.length;
    final int otherLen = key2.length;
    final int minLen = len < otherLen ? len : otherLen;
    for (int i = 0; i < minLen; ++i) {
      int codeUnit1 = key1.codeUnitAt(i);
      int codeUnit2 = key2.codeUnitAt(i);
      if (codeUnit1 != codeUnit2) {
        if (codeUnit1 > 127 || codeUnit2 > 127) {
          return key1.toLowerCase().compareTo(key2.toLowerCase());
        }
        if (codeUnit1 >= 65 && codeUnit1 <= 90) {
          codeUnit1 |= 0x20;
        }
        if (codeUnit2 >= 65 && codeUnit2 <= 90) {
          codeUnit2 |= 0x20;
        }
        if (codeUnit1 != codeUnit2) {
          return codeUnit1 - codeUnit2;
        }
      }
    }
    return len - otherLen;
  }

  //------------------------------------------------------------------------------------------------
  /// Internal use.
  @internal
  static bool caseInsensitiveKeyEquals(String s1, String s2) {
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
  }

  //------------------------------------------------------------------------------------------------
  /// Internal use.
  @internal
  static int caseInsensitiveKeyHashCode(String stringValue) {
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
  }

  //------------------------------------------------------------------------------------------------
  static int _caseSensitiveCompare(String key1, String key2) => key1.compareTo(key2);

  //------------------------------------------------------------------------------------------------
  static dynamic _copyValue(
    final dynamic value, {
    required bool readOnly,
    Json5CommentRegistry? sourceRegistry,
    Json5CommentRegistry? targetRegistry,
  }) {
    if (value is Json5) {
      final Json5 copy = Json5(
        caseSensitiveKeys: value.caseSensitiveKeys,
        dateTimeFormat: value.dateTimeFormat,
        readOnly: readOnly,
        sortedKeys: value.sortedKeys,
      ).._setFromJsonInternal(value, targetRegistry: targetRegistry);
      if (targetRegistry != null) {
        copy._commentRegistry = targetRegistry;
        sourceRegistry?.copyContainerCommentsTo(value, copy, targetRegistry);
      }
      return copy;
    } else if (value is List<dynamic>) {
      final List<dynamic> resultList = [];
      for (final Object? item in value) {
        resultList.add(
          _copyValue(
            item,
            readOnly: readOnly,
            sourceRegistry: sourceRegistry,
            targetRegistry: targetRegistry,
          ),
        );
      }
      if (readOnly) {
        final List<dynamic> unmodifiableList = UnmodifiableListView<dynamic>(resultList);
        if (targetRegistry != null) {
          sourceRegistry?.copyContainerCommentsTo(value, unmodifiableList, targetRegistry);
        }
        return unmodifiableList;
      }
      if (targetRegistry != null) {
        sourceRegistry?.copyContainerCommentsTo(value, resultList, targetRegistry);
      }
      return resultList;
    } else if (value is Set<dynamic>) {
      final Set<dynamic> resultSet = {};
      for (final Object? item in value) {
        resultSet.add(
          _copyValue(
            item,
            readOnly: readOnly,
            sourceRegistry: sourceRegistry,
            targetRegistry: targetRegistry,
          ),
        );
      }
      return readOnly ? UnmodifiableSetView<dynamic>(resultSet) : resultSet;
    }
    return value;
  }

  //------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool? sortedKeys,
  }) => Json5Parser.decodeMultiple(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat ?? defaultDateTimeFormat,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys ?? defaultUseSortedKeys,
  );

  //------------------------------------------------------------------------------------------------
  static bool _deepEquals(dynamic valueA, dynamic valueB) {
    if (identical(valueA, valueB)) {
      return true;
    }
    if (valueA is Json5 && valueB is Json5) {
      if (valueA.length != valueB.length) {
        return false;
      }
      for (final String mapKey in valueA.keys) {
        if (!valueB.containsKey(mapKey)) {
          return false;
        }
        if (!_deepEquals(valueA.asType(mapKey), valueB.asType(mapKey))) {
          return false;
        }
      }
      if (valueA.caseSensitiveKeys != valueB.caseSensitiveKeys) {
        for (final String mapKey in valueB.keys) {
          if (!valueA.containsKey(mapKey)) {
            return false;
          }
        }
      }
      return true;
    }
    if (valueA is Map<dynamic, dynamic> && valueB is Map<dynamic, dynamic>) {
      if (valueA.length != valueB.length) {
        return false;
      }
      for (final Object? mapKey in valueA.keys) {
        if (!valueB.containsKey(mapKey)) {
          return false;
        }
        if (!_deepEquals(valueA[mapKey], valueB[mapKey])) {
          return false;
        }
      }
      return true;
    }
    if (valueA is Iterable<dynamic> && valueB is Iterable<dynamic>) {
      if (valueA.length != valueB.length) {
        return false;
      }
      final Iterator<dynamic> iteratorA = valueA.iterator;
      final Iterator<dynamic> iteratorB = valueB.iterator;
      while (iteratorA.moveNext() && iteratorB.moveNext()) {
        if (!_deepEquals(iteratorA.current, iteratorB.current)) {
          return false;
        }
      }
      return true;
    }
    return valueA == valueB;
  }

  //------------------------------------------------------------------------------------------------
  /// Escapes special characters (control characters, quotes, backslashes) in [originalValue] for
  /// JSON/JSON5 string output.
  static String escapeString(String originalValue) {
    final int length = originalValue.length;
    for (int charIndex = 0; charIndex < length; ++charIndex) {
      final int codeUnit = originalValue.codeUnitAt(charIndex);
      if (codeUnit >= 32 && codeUnit != 34 && codeUnit != 92) {
        continue;
      }
      final StringBuffer buffer = StringBuffer();
      if (charIndex > 0) {
        buffer.write(originalValue.substring(0, charIndex));
      }
      _writeEscapedString(buffer, originalValue, startIndex: charIndex);
      return buffer.toString();
    }
    return originalValue;
  }

  //------------------------------------------------------------------------------------------------
  /// Internal use.
  @internal
  static bool isBlankString(String value) {
    final int length = value.length;
    for (int i = 0; i < length; ++i) {
      final int codeUnit = value.codeUnitAt(i);
      if (codeUnit > 32 &&
          (codeUnit < 0x00A0 ||
              (codeUnit != 0x00A0 &&
                  codeUnit != 0x2028 &&
                  codeUnit != 0x2029 &&
                  codeUnit != 0xFEFF))) {
        return false;
      }
    }
    return true;
  }

  //------------------------------------------------------------------------------------------------
  static bool _isIdentifier(String key) {
    final int keyLength = key.length;
    if (keyLength == 0) {
      return false;
    }
    final int first = key.codeUnitAt(0);
    if (!((first >= 97 && first <= 122) ||
        (first >= 65 && first <= 90) ||
        first == 95 ||
        first == 36)) {
      return false;
    }
    for (int i = 1; i < keyLength; ++i) {
      final int c = key.codeUnitAt(i);
      if (!((c >= 97 && c <= 122) ||
          (c >= 65 && c <= 90) ||
          (c >= 48 && c <= 57) ||
          c == 95 ||
          c == 36)) {
        return false;
      }
    }
    return true;
  }

  //------------------------------------------------------------------------------------------------
  static bool _isValidSplayKey(Object? potentialKey) => potentialKey is String;

  //------------------------------------------------------------------------------------------------
  /// Internal use.
  @internal
  static Json5 loadIncludeFile({
    String? baseFilePath,
    required bool caseSensitiveKeys,
    required EDateTimeFormat dateTimeFormat,
    Set<String>? includePathSet,
    Map<String, dynamic>? params,
    required String path,
    required bool readOnly,
    required bool sortedKeys,
  }) => io.fromFile(
    baseFilePath: baseFilePath,
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    includePathSet: includePathSet,
    params: params,
    path: path,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  );

  //------------------------------------------------------------------------------------------------
  /// Decodes any JSON5 string into its dynamic Dart representation (which could be a Json5 object,
  /// List, String, num, bool, or null).
  static dynamic parseAny(
    String jsonString, {
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool? sortedKeys,
  }) => Json5Parser.decodeAny(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat ?? defaultDateTimeFormat,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys ?? defaultUseSortedKeys,
  );

  //------------------------------------------------------------------------------------------------
  static void _writeEscapedString(
    StringBuffer buffer,
    String originalValue, {
    int startIndex = 0,
  }) {
    int lastCopiedIndex = startIndex;
    final int length = originalValue.length;
    for (int charIndex = startIndex; charIndex < length; ++charIndex) {
      final int codeUnit = originalValue.codeUnitAt(charIndex);
      if (codeUnit >= 32 && codeUnit != 34 && codeUnit != 92) {
        continue;
      }
      if (charIndex > lastCopiedIndex) {
        buffer.write(originalValue.substring(lastCopiedIndex, charIndex));
      }
      final String? escapedValue = _escapedCodeUnitMap[codeUnit];
      if (escapedValue != null) {
        buffer.write(escapedValue);
      } else {
        buffer.write("\\u${codeUnit.toRadixString(16).padLeft(4, '0')}");
      }
      lastCopiedIndex = charIndex + 1;
    }
    if (lastCopiedIndex == 0) {
      buffer.write(originalValue);
    } else if (lastCopiedIndex < length) {
      buffer.write(originalValue.substring(lastCopiedIndex));
    }
  }

  //------------------------------------------------------------------------------------------------
  static void _writeKey(StringBuffer buffer, String key, {required bool json5}) {
    if (_isIdentifier(key)) {
      if (json5) {
        buffer.write(key);
      } else {
        buffer
          ..write('"')
          ..write(key)
          ..write('"');
      }
      return;
    }
    buffer.write('"');
    _writeEscapedString(buffer, key);
    buffer.write('"');
  }

  //------------------------------------------------------------------------------------------------
  static void _writeNum(StringBuffer buffer, num value, {required bool json5}) {
    if (!json5 && !value.isFinite) {
      buffer.write("null");
    } else {
      buffer.write(value);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Creates a new [Json5] object containing entries from [json2] that do not match the values
  /// from [json1].
  factory Json5.fromDiffs(
    final Json5 json1,
    final Json5 json2, {
    bool? caseSensitiveKeys,
    EDateTimeFormat? dateTimeFormat,
    bool readOnly = false,
    bool? sortedKeys,
  }) {
    final Json5 result = Json5(
      caseSensitiveKeys: caseSensitiveKeys ?? json2.caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat ?? json2.dateTimeFormat,
      readOnly: readOnly,
      sortedKeys: sortedKeys ?? json2.sortedKeys,
    );
    for (final MapEntry<String, dynamic> entry in json2.entries) {
      if (!_deepEquals(json1.asType(entry.key), entry.value)) {
        result._setInternal(entry.key, _copyValue(entry.value, readOnly: readOnly));
      }
    }
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by reading and parsing the contents of the file at [path].
  factory Json5.fromFile(
    String path, {
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool? sortedKeys,
  }) => io.fromFile(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat ?? defaultDateTimeFormat,
    params: params,
    path: path,
    readOnly: readOnly,
    sortedKeys: sortedKeys ?? defaultUseSortedKeys,
  );

  //------------------------------------------------------------------------------------------------
  /// Creates a Json5 object by performing a deep copy from another Json5 object.
  factory Json5.fromJson5(
    Json5 json5, {
    bool? caseSensitiveKeys,
    EDateTimeFormat? dateTimeFormat,
    bool readOnly = false,
    bool? sortedKeys,
  }) {
    final Json5CommentRegistry? targetRegistry = json5._commentRegistry != null
        ? Json5CommentRegistry()
        : null;
    final Json5 copy = Json5(
      caseSensitiveKeys: caseSensitiveKeys ?? json5.caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat ?? json5.dateTimeFormat,
      readOnly: readOnly,
      sortedKeys: sortedKeys ?? json5.sortedKeys,
    ).._setFromJsonInternal(json5, targetRegistry: targetRegistry);
    if (targetRegistry != null) {
      json5._commentRegistry!.copyContainerCommentsTo(json5, copy, targetRegistry);
      copy._commentRegistry = targetRegistry;
    }
    return copy;
  }

  //------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a list of keys and a list of values. The values are lined up
  /// positionally with the keys.
  factory Json5.fromKeyAndValueLists({
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    required List<String> keyList,
    bool readOnly = false,
    bool? sortedKeys,
    required List<dynamic> valueList,
  }) => Json5(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  ).._setFromKeyAndValueListsInternal(keyList, valueList);

  //------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a map of keys to indexes and a list of values. The indexes
  /// represent the position of the values in the list.
  factory Json5.fromKeyToIndexMapAndValueList({
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    required Map<String, int> keyToIndexMap,
    bool readOnly = false,
    bool? sortedKeys,
    required List<dynamic> valueList,
  }) => Json5(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  ).._setFromKeyToIndexAndValueListInternal(keyToIndexMap, valueList);

  //------------------------------------------------------------------------------------------------
  /// Creates a Json5 object from a Map.
  factory Json5.fromMap(
    Map<dynamic, dynamic> jsonMap, {
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    bool readOnly = false,
    bool? sortedKeys,
  }) => Json5(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  ).._setFromMapInternal(jsonMap);

  //------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string into a Json5 object.
  factory Json5.fromString(
    String jsonString, {
    bool? allowBlankString,
    bool caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool? sortedKeys,
  }) {
    final bool effectiveAllowBlank = allowBlankString ?? defaultAllowBlankString;
    if (isBlankString(jsonString)) {
      if (effectiveAllowBlank) {
        return Json5(
          caseSensitiveKeys: caseSensitiveKeys,
          dateTimeFormat: dateTimeFormat,
          readOnly: readOnly,
          sortedKeys: sortedKeys,
        );
      } else {
        throw const FormatException("JSON5 string cannot be blank");
      }
    }
    return Json5Parser.decode(
      caseSensitiveKeys: caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat ?? defaultDateTimeFormat,
      jsonString: jsonString,
      params: params,
      readOnly: readOnly,
      sortedKeys: sortedKeys ?? defaultUseSortedKeys,
    );
  }

  //------------------------------------------------------------------------------------------------
  /// Creates an empty Json5 object.
  Json5({
    this.caseSensitiveKeys = false,
    EDateTimeFormat? dateTimeFormat,
    this.readOnly = false,
    bool? sortedKeys,
  }) : dateTimeFormat = dateTimeFormat ?? defaultDateTimeFormat,
       sortedKeys = sortedKeys ?? defaultUseSortedKeys,
       _ephemeralKeys = null,
       _keyToValueMap = (sortedKeys ?? defaultUseSortedKeys)
           ? SplayTreeMap<String, dynamic>(
               caseSensitiveKeys ? _caseSensitiveCompare : _caseInsensitiveCompare,
               _isValidSplayKey,
             )
           : caseSensitiveKeys
           ? <String, dynamic>{}
           : LinkedHashMap<String, dynamic>(
               equals: caseInsensitiveKeyEquals,
               hashCode: caseInsensitiveKeyHashCode,
             );

  //------------------------------------------------------------------------------------------------
  /// Delegates the assignment to the [set] method, for example, json5["key1"] = 1 is equivalent to
  /// json5.set("key1", 1).
  void operator []=(dynamic key, dynamic value) => set(key, value);

  //------------------------------------------------------------------------------------------------
  /// Adds all entries from a [Map] to this Json5 object.
  void addAll(Map<dynamic, dynamic>? jsonMap) {
    _checkMutable();
    if (jsonMap == null || jsonMap.isEmpty) {
      return;
    }
    for (final MapEntry<dynamic, dynamic> entry in jsonMap.entries) {
      set(entry.key, entry.value);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [bool] values for [key].
  List<bool> asBoolList(final dynamic key) =>
      _getList<bool>(key, emptyBoolList, (source, result) => _convertBools(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [bool] values for [key], or `null` if [key] is missing or null.
  List<bool>? asBoolListOrNull(final dynamic key) => containsKey(key) ? asBoolList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [bool] values for [key].
  Set<bool> asBoolSet(final dynamic key) =>
      _getSet<bool>(key, emptyBoolSet, (source, result) => _convertBools(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [bool] values for [key], or `null` if [key] is missing or null.
  Set<bool>? asBoolSetOrNull(final dynamic key) => containsKey(key) ? asBoolSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [DateTime] values for [key].
  List<DateTime> asDateTimeList(final dynamic key) => _getList<DateTime>(
    key,
    emptyDateTimeList,
    (source, result) => _convertDateTimes(source, result.add),
  );

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [DateTime] values for [key], or `null` if [key] is missing or null.
  List<DateTime>? asDateTimeListOrNull(final dynamic key) =>
      containsKey(key) ? asDateTimeList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [DateTime] values for [key].
  Set<DateTime> asDateTimeSet(final dynamic key) => _getSet<DateTime>(
    key,
    emptyDateTimeSet,
    (source, result) => _convertDateTimes(source, result.add),
  );

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [DateTime] values for [key], or `null` if [key] is missing or null.
  Set<DateTime>? asDateTimeSetOrNull(final dynamic key) =>
      containsKey(key) ? asDateTimeSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [double] values for [key].
  List<double> asDoubleList(final dynamic key) => _getList<double>(
    key,
    emptyDoubleList,
    (source, result) => _convertDoubles(source, result.add),
  );

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [double] values for [key], or `null` if [key] is missing or null.
  List<double>? asDoubleListOrNull(final dynamic key) =>
      containsKey(key) ? asDoubleList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [double] values for [key].
  Set<double> asDoubleSet(final dynamic key) =>
      _getSet<double>(key, emptyDoubleSet, (source, result) => _convertDoubles(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [double] values for [key], or `null` if [key] is missing or null.
  Set<double>? asDoubleSetOrNull(final dynamic key) => containsKey(key) ? asDoubleSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of values for [key].
  List<dynamic> asDynamicList(final dynamic key) =>
      _getList<dynamic>(key, emptyDynamicList, (source, result) => result.addAll(source));

  //------------------------------------------------------------------------------------------------
  /// Returns the list of values for [key], or `null` if [key] is missing or null.
  List<dynamic>? asDynamicListOrNull(final dynamic key) =>
      containsKey(key) ? asDynamicList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of values for [key].
  Set<dynamic> asDynamicSet(final dynamic key) =>
      _getSet<dynamic>(key, emptyDynamicSet, (source, result) => result.addAll(source));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of values for [key], or `null` if [key] is missing or null.
  Set<dynamic>? asDynamicSetOrNull(final dynamic key) =>
      containsKey(key) ? asDynamicSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [int] values for [key].
  List<int> asIntList(final dynamic key) =>
      _getList<int>(key, emptyIntList, (source, result) => _convertInts(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [int] values for [key], or `null` if [key] is missing or null.
  List<int>? asIntListOrNull(final dynamic key) => containsKey(key) ? asIntList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [int] values for [key].
  Set<int> asIntSet(final dynamic key) =>
      _getSet<int>(key, emptyIntSet, (source, result) => _convertInts(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [int] values for [key], or `null` if [key] is missing or null.
  Set<int>? asIntSetOrNull(final dynamic key) => containsKey(key) ? asIntSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the [Json5] object for [key].
  Json5 asJson(final dynamic key) => asType(key) as Json5? ?? emptyJson;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [Json5] values for [key].
  List<Json5> asJsonList(final dynamic key) =>
      _getList<Json5>(key, emptyJsonList, (source, result) => _convertJson5s(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [Json5] values for [key], or `null` if [key] is missing or null.
  List<Json5>? asJsonListOrNull(final dynamic key) => containsKey(key) ? asJsonList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the [Json5] object for [key], or `null` if [key] is missing or null.
  Json5? asJsonOrNull(final dynamic key) => asType(key) as Json5?;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [Json5] values for [key].
  Set<Json5> asJsonSet(final dynamic key) =>
      _getSet<Json5>(key, emptyJsonSet, (source, result) => _convertJson5s(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [Json5] values for [key], or `null` if [key] is missing or null.
  Set<Json5>? asJsonSetOrNull(final dynamic key) => containsKey(key) ? asJsonSet(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [String] values for [key].
  List<String> asStringList(final dynamic key) => _getList<String>(
    key,
    emptyStringList,
    (source, result) => _convertStrings(source, result.add),
  );

  //------------------------------------------------------------------------------------------------
  /// Returns the list of [String] values for [key], or `null` if [key] is missing or null.
  List<String>? asStringListOrNull(final dynamic key) =>
      containsKey(key) ? asStringList(key) : null;

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [String] values for [key].
  Set<String> asStringSet(final dynamic key) =>
      _getSet<String>(key, emptyStringSet, (source, result) => _convertStrings(source, result.add));

  //------------------------------------------------------------------------------------------------
  /// Returns the set of [String] values for [key], or `null` if [key] is missing or null.
  Set<String>? asStringSetOrNull(final dynamic key) => containsKey(key) ? asStringSet(key) : null;

  //------------------------------------------------------------------------------------------------
  @override
  @internal
  dynamic asType(dynamic key) {
    final String localKey = _getKey(key);
    if (_isEphemeral(localKey)) {
      return null;
    }
    return _keyToValueMap[localKey];
  }

  //------------------------------------------------------------------------------------------------
  void _checkMutable() {
    if (readOnly) {
      throw UnsupportedError("Cannot modify a read-only Json5 object");
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Clears all entries from this Json5 object.
  void clear() {
    _checkMutable();
    _ephemeralKeys?.clear();
    _keyToValueMap.clear();
  }

  //------------------------------------------------------------------------------------------------
  // ignore: avoid_positional_boolean_parameters
  void _convertBools(Iterable<dynamic> source, void Function(bool) add) {
    for (final Object? listItem in source) {
      if (listItem is bool) {
        add(listItem);
      } else if (listItem != null) {
        add(listItem.toString().toBool());
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  void _convertDateTimes(Iterable<dynamic> source, void Function(DateTime) add) {
    for (final Object? listItem in source) {
      if (listItem is DateTime) {
        add(listItem);
      } else if (listItem is num) {
        add(DateTime.fromMillisecondsSinceEpoch(listItem.toInt()));
      } else if (listItem != null) {
        final DateTime? dt = listItem.toString().toDateTime();
        if (dt != null) add(dt);
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  void _convertDoubles(Iterable<dynamic> source, void Function(double) add) {
    for (final Object? listItem in source) {
      if (listItem is num) {
        add(listItem.toDouble());
      } else {
        add(listItem.toString().toDouble());
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  void _convertInts(Iterable<dynamic> source, void Function(int) add) {
    for (final Object? listItem in source) {
      if (listItem is num) {
        add(listItem.toInt());
      } else {
        add(listItem.toString().toInt());
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  Iterable<dynamic> _convertIterable(Iterable<dynamic> iterable, {bool freeze = false}) {
    if (!freeze &&
        (iterable is List<int> ||
            iterable is List<double> ||
            iterable is List<String> ||
            iterable is List<bool> ||
            iterable is List<Json5> ||
            iterable is Set<int> ||
            iterable is Set<double> ||
            iterable is Set<String> ||
            iterable is Set<bool> ||
            iterable is Set<Json5>)) {
      return iterable;
    }
    if (iterable is Set<dynamic>) {
      Set<dynamic>? convertedSet;
      int itemIndex = 0;
      for (final Object? item in iterable) {
        final Object? convertedItem = _convertNestedCollectionItem(item, freeze: freeze);
        if (!identical(convertedItem, item) && convertedSet == null) {
          convertedSet = <dynamic>{};
          int copyIndex = 0;
          for (final Object? priorItem in iterable) {
            if (copyIndex >= itemIndex) {
              break;
            }
            convertedSet.add(priorItem);
            ++copyIndex;
          }
        }
        convertedSet?.add(convertedItem);
        ++itemIndex;
      }
      final Set<dynamic> resultSet = convertedSet ?? iterable;
      return freeze ? UnmodifiableSetView<dynamic>(resultSet) : resultSet;
    }
    List<dynamic>? convertedList;
    int itemIndex = 0;
    for (final Object? item in iterable) {
      final Object? convertedItem = _convertNestedCollectionItem(item, freeze: freeze);
      if (!identical(convertedItem, item) && convertedList == null) {
        convertedList = <dynamic>[];
        int copyIndex = 0;
        for (final Object? priorItem in iterable) {
          if (copyIndex >= itemIndex) {
            break;
          }
          convertedList.add(priorItem);
          ++copyIndex;
        }
      }
      convertedList?.add(convertedItem);
      ++itemIndex;
    }
    final Iterable<dynamic> resultIterable = convertedList ?? iterable;
    if (freeze) {
      final List<dynamic> listForView;
      if (resultIterable is List<dynamic>) {
        listForView = resultIterable;
      } else {
        listForView = <dynamic>[];
        for (final Object? item in resultIterable) {
          listForView.add(item);
        }
      }
      return UnmodifiableListView<dynamic>(listForView);
    }
    return resultIterable;
  }

  //------------------------------------------------------------------------------------------------
  void _convertJson5s(Iterable<dynamic> source, void Function(Json5) add) {
    for (final Object? listItem in source) {
      if (listItem is Json5) {
        add(listItem);
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  dynamic _convertNestedCollectionItem(dynamic item, {required bool freeze}) => switch (item) {
    Json5 jsonValue =>
      freeze && !jsonValue.readOnly ? Json5.fromJson5(jsonValue, readOnly: true) : jsonValue,
    Map<dynamic, dynamic> mapValue => Json5.fromMap(
      mapValue,
      caseSensitiveKeys: caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat,
      readOnly: freeze,
      sortedKeys: sortedKeys,
    ),
    Iterable<dynamic> iterableValue => _convertIterable(iterableValue, freeze: freeze),
    _ => item,
  };

  //------------------------------------------------------------------------------------------------
  void _convertStrings(Iterable<dynamic> source, void Function(String) add) {
    for (final Object? listItem in source) {
      if (listItem != null) {
        add(listItem.toString());
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  Set<String> _createEphemeralKeys() => caseSensitiveKeys
      ? <String>{}
      : LinkedHashSet<String>(
          equals: caseInsensitiveKeyEquals,
          hashCode: caseInsensitiveKeyHashCode,
        );

  //------------------------------------------------------------------------------------------------
  /// Returns `true` if this object and [other] have deeply equal keys and values.
  bool deepEquals(Json5 other) => _deepEquals(this, other);

  //------------------------------------------------------------------------------------------------
  void _formatEntry({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
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
      keyOrIndex: key,
      level: level,
      location: ECommentLocation.beforeColon,
      registry: registry,
      skipPrecedingNewline: true,
    );
    _writeKey(buffer, key, json5: json5);
    buffer.write(":");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      keyOrIndex: key,
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
    } else if (value is Iterable<dynamic>) {
      _formatIterable(
        buffer: buffer,
        container: value,
        dynamicIterable: value,
        includeComments: includeComments,
        json5: json5,
        level: level,
        registry: registry,
      );
    } else if (value is String) {
      buffer.write('"');
      _writeEscapedString(buffer, value);
      buffer.write('"');
    } else if (value is num) {
      _writeNum(buffer, value, json5: json5);
    } else if (value is bool || value == null) {
      buffer.write(value);
    } else {
      buffer.write('"');
      _writeEscapedString(buffer, value.toString());
      buffer.write('"');
    }
  }

  //------------------------------------------------------------------------------------------------
  void _formatIterable({
    required StringBuffer buffer,
    required Object container,
    required Iterable<dynamic> dynamicIterable,
    required bool includeComments,
    required bool json5,
    required int level,
    Json5CommentRegistry? registry,
  }) {
    if (dynamicIterable.isEmpty) {
      buffer.write("[]");
      return;
    }
    buffer.write("[");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      keyOrIndex: 0,
      level: level + 1,
      location: ECommentLocation.standaloneBefore,
      registry: registry,
    );
    buffer.writeln();
    final String prefix = "  " * (level + 1);
    int i = 0;
    final int length = dynamicIterable.length;
    for (final dynamic value in dynamicIterable) {
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
        case Iterable<dynamic> iterableValue:
          buffer.write(prefix);
          _formatIterable(
            buffer: buffer,
            container: iterableValue,
            dynamicIterable: iterableValue,
            includeComments: includeComments,
            json5: json5,
            level: level + 1,
            registry: registry,
          );
        case String stringValue:
          buffer
            ..write(prefix)
            ..write('"');
          _writeEscapedString(buffer, stringValue);
          buffer.write('"');
        case num numValue:
          buffer.write(prefix);
          _writeNum(buffer, numValue, json5: json5);
        default:
          buffer
            ..write(prefix)
            ..write(value);
      }
      buffer.write(json5 || i < length - 1 ? "," : "");
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        keyOrIndex: i,
        level: level + 1,
        location: ECommentLocation.beforeComma,
        registry: registry,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        keyOrIndex: i,
        level: level + 1,
        location: ECommentLocation.afterComma,
        registry: registry,
      );
      buffer.writeln();
      ++i;
    }
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      keyOrIndex: length,
      level: level + 1,
      location: ECommentLocation.standaloneAfter,
      registry: registry,
      skipPrecedingNewline: true,
    );
    buffer
      ..write("  " * level)
      ..write("]");
  }

  //------------------------------------------------------------------------------------------------
  void _formatMap({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
    required bool json5,
    required Map<String, dynamic> jsonMap,
    required int level,
    Json5CommentRegistry? registry,
  }) {
    Iterable<String> mapKeys = jsonMap.keys;
    if (container is Json5 && identical(jsonMap, container._keyToValueMap)) {
      mapKeys = container.keys;
    }
    if (mapKeys.isEmpty) {
      final List<Json5Comment>? emptyComments = includeComments && registry != null
          ? registry.getComments(
              container,
              Json5CommentRegistry.trailingKey,
              ECommentLocation.standaloneAfter,
            )
          : null;
      if (emptyComments == null || emptyComments.isEmpty) {
        buffer.write("{}");
        return;
      }
      buffer
        ..write("{")
        ..writeln();
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        keyOrIndex: Json5CommentRegistry.trailingKey,
        level: level + 1,
        location: ECommentLocation.standaloneAfter,
        registry: registry,
        skipPrecedingNewline: true,
      );
      buffer
        ..writeln()
        ..write("  " * level)
        ..write("}");
      return;
    }
    buffer.write("{");
    _writeComments(
      buffer: buffer,
      container: container,
      includeComments: includeComments,
      keyOrIndex: Json5CommentRegistry.trailingKey,
      level: level + 1,
      location: ECommentLocation.standaloneBefore,
      registry: registry,
    );
    buffer.writeln();
    final List<String> sortedKeyList = <String>[];
    for (final String mapKey in mapKeys) {
      sortedKeyList.add(mapKey);
    }
    final String indent = "  " * (level + 1);
    for (int i = 0; i < sortedKeyList.length; ++i) {
      final String key = sortedKeyList[i];
      final List<Json5Comment>? beforeKeyCommentList = includeComments && registry != null
          ? registry.getComments(container, key, ECommentLocation.beforeKey)
          : null;
      if (beforeKeyCommentList != null) {
        for (int commentIndex = 0; commentIndex < beforeKeyCommentList.length; ++commentIndex) {
          final Json5Comment comment = beforeKeyCommentList[commentIndex];
          if (commentIndex == 0 || comment.precededByNewline) {
            if (commentIndex > 0) {
              buffer.writeln();
            }
            buffer.write(indent);
          } else {
            buffer.write(" ");
          }
          buffer.write(comment.comment);
        }
        buffer.writeln();
      }
      _formatEntry(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        json5: json5,
        key: key,
        level: level + 1,
        registry: registry,
        value: jsonMap[key],
      );
      buffer.write(json5 || i < sortedKeyList.length - 1 ? "," : "");
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        keyOrIndex: key,
        level: level + 1,
        location: ECommentLocation.beforeComma,
        registry: registry,
      );
      _writeComments(
        buffer: buffer,
        container: container,
        includeComments: includeComments,
        keyOrIndex: key,
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
      keyOrIndex: Json5CommentRegistry.trailingKey,
      level: level + 1,
      location: ECommentLocation.standaloneAfter,
      registry: registry,
      skipPrecedingNewline: true,
    );
    buffer
      ..write("  " * level)
      ..write("}");
  }

  //------------------------------------------------------------------------------------------------
  /// Returns the key/value entries for this Json5 object.
  Iterable<MapEntry<String, dynamic>> get entries => _ephemeralKeys == null || _ephemeralKeys!.isEmpty
      ? _keyToValueMap.entries
      : _keyToValueMap.entries.where((e) => !_isEphemeral(e.key));

  //------------------------------------------------------------------------------------------------
  bool _isEphemeral(String key) {
    if (_ephemeralKeys == null || !_ephemeralKeys!.contains(key)) return false;
    final dynamic value = _keyToValueMap[key];
    return value is Iterable<dynamic> && value.isEmpty;
  }

  //------------------------------------------------------------------------------------------------
  /// Returns true if this Json5 object is empty.
  bool get isEmpty =>
      _ephemeralKeys == null || _ephemeralKeys!.isEmpty ? _keyToValueMap.isEmpty : keys.isEmpty;

  //------------------------------------------------------------------------------------------------
  /// Returns true if this Json5 object is not empty.
  bool get isNotEmpty => !isEmpty;

  //------------------------------------------------------------------------------------------------
  String _getKey(dynamic key) {
    if (key is String) {
      return key;
    }
    if (key is Enum) {
      return key.name;
    }
    final String keyString = key.toString();
    return keyString.substring(keyString.lastIndexOf(".") + 1);
  }

  //------------------------------------------------------------------------------------------------
  /// Returns the keys for this Json5 object.
  Iterable<String> get keys => _ephemeralKeys == null || _ephemeralKeys!.isEmpty
      ? _keyToValueMap.keys
      : _keyToValueMap.keys.where((k) => !_isEphemeral(k));

  //------------------------------------------------------------------------------------------------
  /// Returns the number of key/value pairs in this Json5 object.
  int get length => keys.length;

  //------------------------------------------------------------------------------------------------
  List<ElementType> _getList<ElementType>(
    dynamic key,
    List<ElementType> emptyCollection,
    void Function(Iterable<dynamic> source, List<ElementType> result) converter,
  ) {
    List<ElementType> result;
    final String localKey = _getKey(key);
    final dynamic value = _keyToValueMap[localKey];
    if (value is List<ElementType>) {
      return readOnly ? UnmodifiableListView<ElementType>(value) : value;
    }
    if (value != null) {
      final Iterable<dynamic> source = value is Iterable<dynamic> ? value : <dynamic>[value];
      result = <ElementType>[];
      converter(source, result);
      if (!readOnly) {
        _keyToValueMap[localKey] = result;
        return result;
      }
      return UnmodifiableListView<ElementType>(result);
    }
    if (!readOnly) {
      result = <ElementType>[];
      _keyToValueMap[localKey] = result;
      (_ephemeralKeys ??= _createEphemeralKeys()).add(localKey);
      return result;
    }
    return emptyCollection;
  }

  //------------------------------------------------------------------------------------------------
  Set<ElementType> _getSet<ElementType>(
    dynamic key,
    Set<ElementType> emptyCollection,
    void Function(Iterable<dynamic> source, Set<ElementType> result) converter,
  ) {
    Set<ElementType> result;
    final String localKey = _getKey(key);
    final dynamic value = _keyToValueMap[localKey];
    if (value is Set<ElementType>) {
      return readOnly ? UnmodifiableSetView<ElementType>(value) : value;
    }
    if (value != null) {
      final Iterable<dynamic> source = value is Iterable<dynamic> ? value : <dynamic>[value];
      result = <ElementType>{};
      converter(source, result);
      if (!readOnly) {
        _keyToValueMap[localKey] = result;
        return result;
      }
      return UnmodifiableSetView<ElementType>(result);
    }
    if (!readOnly) {
      result = <ElementType>{};
      _keyToValueMap[localKey] = result;
      (_ephemeralKeys ??= _createEphemeralKeys()).add(localKey);
      return result;
    }
    return emptyCollection;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its value.
  dynamic remove(dynamic key) {
    _checkMutable();
    final String localKey = _getKey(key);
    _ephemeralKeys?.remove(localKey);
    return _keyToValueMap.remove(localKey);
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its boolean representation.
  bool removeBool(dynamic key, {bool defaultValue = false}) {
    final bool result = asBool(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [bool] elements.
  List<bool> removeBoolList(final dynamic key) {
    final List<bool> result = List<bool>.of(asBoolList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [bool] elements, or `null` if [key] is missing or null.
  List<bool>? removeBoolListOrNull(final dynamic key) {
    final List<bool>? boolList = asBoolListOrNull(key);
    if (boolList == null) {
      return null;
    }
    final List<bool> resultList = List<bool>.of(boolList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its boolean representation, or `null` if [key] is missing or null.
  bool? removeBoolOrNull(dynamic key) {
    final bool? result = asBoolOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [bool] elements.
  Set<bool> removeBoolSet(final dynamic key) {
    final Set<bool> result = Set<bool>.of(asBoolSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [bool] elements, or `null` if [key] is missing or null.
  Set<bool>? removeBoolSetOrNull(final dynamic key) {
    final Set<bool>? boolSet = asBoolSetOrNull(key);
    if (boolSet == null) {
      return null;
    }
    final Set<bool> resultSet = Set<bool>.of(boolSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its date/time representation.
  DateTime removeDateTime(dynamic key, {DateTime? defaultValue}) {
    final DateTime result = asDateTime(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [DateTime] elements.
  List<DateTime> removeDateTimeList(final dynamic key) {
    final List<DateTime> result = List<DateTime>.of(asDateTimeList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [DateTime] elements, or `null` if [key] is missing or null.
  List<DateTime>? removeDateTimeListOrNull(final dynamic key) {
    final List<DateTime>? dateTimeList = asDateTimeListOrNull(key);
    if (dateTimeList == null) {
      return null;
    }
    final List<DateTime> resultList = List<DateTime>.of(dateTimeList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its date/time representation, or `null` if [key] is missing or null.
  DateTime? removeDateTimeOrNull(dynamic key) {
    final DateTime? result = asDateTimeOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [DateTime] elements.
  Set<DateTime> removeDateTimeSet(final dynamic key) {
    final Set<DateTime> result = Set<DateTime>.of(asDateTimeSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [DateTime] elements, or `null` if [key] is missing or null.
  Set<DateTime>? removeDateTimeSetOrNull(final dynamic key) {
    final Set<DateTime>? dateTimeSet = asDateTimeSetOrNull(key);
    if (dateTimeSet == null) {
      return null;
    }
    final Set<DateTime> resultSet = Set<DateTime>.of(dateTimeSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its UTC date/time representation.
  DateTime removeDateTimeUtc(final dynamic key, {final DateTime? defaultValue}) {
    final DateTime result = asDateTimeUtc(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its UTC date/time representation, or `null` if [key] is missing or null.
  DateTime? removeDateTimeUtcOrNull(final dynamic key) {
    final DateTime? result = asDateTimeUtcOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its double representation.
  double removeDouble(dynamic key, {double defaultValue = 0}) {
    final double result = asDouble(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [double] elements.
  List<double> removeDoubleList(final dynamic key) {
    final List<double> result = List<double>.of(asDoubleList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [double] elements, or `null` if [key] is missing or null.
  List<double>? removeDoubleListOrNull(final dynamic key) {
    final List<double>? doubleList = asDoubleListOrNull(key);
    if (doubleList == null) {
      return null;
    }
    final List<double> resultList = List<double>.of(doubleList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its double representation, or `null` if [key] is missing or null.
  double? removeDoubleOrNull(dynamic key) {
    final double? result = asDoubleOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [double] elements.
  Set<double> removeDoubleSet(final dynamic key) {
    final Set<double> result = Set<double>.of(asDoubleSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [double] elements, or `null` if [key] is missing or null.
  Set<double>? removeDoubleSetOrNull(final dynamic key) {
    final Set<double>? doubleSet = asDoubleSetOrNull(key);
    if (doubleSet == null) {
      return null;
    }
    final Set<double> resultSet = Set<double>.of(doubleSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of values.
  List<dynamic> removeDynamicList(final dynamic key) {
    final List<dynamic> result = List<dynamic>.of(asDynamicList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of values, or `null` if [key] is missing or null.
  List<dynamic>? removeDynamicListOrNull(final dynamic key) {
    final List<dynamic>? dynamicList = asDynamicListOrNull(key);
    if (dynamicList == null) {
      return null;
    }
    final List<dynamic> resultList = List<dynamic>.of(dynamicList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of values.
  Set<dynamic> removeDynamicSet(final dynamic key) {
    final Set<dynamic> result = Set<dynamic>.of(asDynamicSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of values, or `null` if [key] is missing or null.
  Set<dynamic>? removeDynamicSetOrNull(final dynamic key) {
    final Set<dynamic>? dynamicSet = asDynamicSetOrNull(key);
    if (dynamicSet == null) {
      return null;
    }
    final Set<dynamic> resultSet = Set<dynamic>.of(dynamicSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its integer representation.
  int removeInt(dynamic key, {int defaultValue = 0}) {
    final int result = asInt(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [int] elements.
  List<int> removeIntList(final dynamic key) {
    final List<int> result = List<int>.of(asIntList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [int] elements, or `null` if [key] is missing or null.
  List<int>? removeIntListOrNull(final dynamic key) {
    final List<int>? intList = asIntListOrNull(key);
    if (intList == null) {
      return null;
    }
    final List<int> resultList = List<int>.of(intList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its integer representation, or `null` if [key] is missing or null.
  int? removeIntOrNull(dynamic key) {
    final int? result = asIntOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [int] elements.
  Set<int> removeIntSet(final dynamic key) {
    final Set<int> result = Set<int>.of(asIntSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [int] elements, or `null` if [key] is missing or null.
  Set<int>? removeIntSetOrNull(final dynamic key) {
    final Set<int>? intSet = asIntSetOrNull(key);
    if (intSet == null) {
      return null;
    }
    final Set<int> resultSet = Set<int>.of(intSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [Json5] elements.
  List<Json5> removeJsonList(final dynamic key) {
    final List<Json5> result = List<Json5>.of(asJsonList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [Json5] elements, or `null` if [key] is missing or null.
  List<Json5>? removeJsonListOrNull(final dynamic key) {
    final List<Json5>? jsonList = asJsonListOrNull(key);
    if (jsonList == null) {
      return null;
    }
    final List<Json5> resultList = List<Json5>.of(jsonList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the [Json5] object for [key], or `null` if [key] is missing or null.
  Json5? removeJsonOrNull(final dynamic key) {
    final Json5? result = asJsonOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [Json5] elements.
  Set<Json5> removeJsonSet(final dynamic key) {
    final Set<Json5> result = Set<Json5>.of(asJsonSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [Json5] elements, or `null` if [key] is missing or null.
  Set<Json5>? removeJsonSetOrNull(final dynamic key) {
    final Set<Json5>? jsonSet = asJsonSetOrNull(key);
    if (jsonSet == null) {
      return null;
    }
    final Set<Json5> resultSet = Set<Json5>.of(jsonSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its string representation.
  String removeString(dynamic key, {String defaultValue = ""}) {
    final String result = asString(key, defaultValue: defaultValue);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [String] elements.
  List<String> removeStringList(final dynamic key) {
    final List<String> result = List<String>.of(asStringList(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the list entry for [key] and returns a detached list of [String] elements, or `null` if [key] is missing or null.
  List<String>? removeStringListOrNull(final dynamic key) {
    final List<String>? stringList = asStringListOrNull(key);
    if (stringList == null) {
      return null;
    }
    final List<String> resultList = List<String>.of(stringList);
    remove(key);
    return resultList;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the entry for [key] and returns its string representation, or `null` if [key] is missing or null.
  String? removeStringOrNull(dynamic key) {
    final String? result = asStringOrNull(key);
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [String] elements.
  Set<String> removeStringSet(final dynamic key) {
    final Set<String> result = Set<String>.of(asStringSet(key));
    remove(key);
    return result;
  }

  //------------------------------------------------------------------------------------------------
  /// Removes the set entry for [key] and returns a detached set of [String] elements, or `null` if [key] is missing or null.
  Set<String>? removeStringSetOrNull(final dynamic key) {
    final Set<String>? stringSet = asStringSetOrNull(key);
    if (stringSet == null) {
      return null;
    }
    final Set<String> resultSet = Set<String>.of(stringSet);
    remove(key);
    return resultSet;
  }

  //------------------------------------------------------------------------------------------------
  /// Sets the value for [key] to [value].
  void set(dynamic key, final dynamic value) {
    _checkMutable();
    _setInternal(key, value);
  }

  //------------------------------------------------------------------------------------------------
  @internal
  /// Internal use.
  // ignore: avoid_setters_without_getters
  set commentRegistry(Json5CommentRegistry commentRegistry) => _commentRegistry = commentRegistry;

  //------------------------------------------------------------------------------------------------
  /// Copies entries from [copyFromJson] into this object.
  /// Performs a deep copy of nested Json5 objects and Lists.
  void setFromJson(final Json5 copyFromJson) {
    _checkMutable();
    _setFromJsonInternal(copyFromJson);
  }

  //------------------------------------------------------------------------------------------------
  void _setFromJsonInternal(final Json5 copyFromJson, {Json5CommentRegistry? targetRegistry}) {
    final Json5CommentRegistry? sourceRegistry = copyFromJson._commentRegistry;
    for (final MapEntry<String, dynamic> newEntry in copyFromJson.entries) {
      final String key = newEntry.key;
      _ephemeralKeys?.remove(key);
      _keyToValueMap[key] = _copyValue(
        newEntry.value,
        readOnly: readOnly,
        sourceRegistry: sourceRegistry,
        targetRegistry: targetRegistry,
      );
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Updates this Json5 object with the entries from [keyList] and [valueList].
  void setFromKeyAndValueLists(List<String>? keyList, List<dynamic>? valueList) {
    _checkMutable();
    _setFromKeyAndValueListsInternal(keyList, valueList);
  }

  //------------------------------------------------------------------------------------------------
  void _setFromKeyAndValueListsInternal(List<String>? keyList, List<dynamic>? valueList) {
    if (keyList == null || valueList == null) {
      return;
    }
    if (valueList.length != keyList.length) {
      throw Exception("keyList and valueList must be the same length");
    }
    for (int keyIndex = 0; keyIndex < keyList.length; ++keyIndex) {
      _setInternal(keyList[keyIndex], valueList[keyIndex]);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Updates this Json5 object with the entries from [keyToIndexMap] and [valueList].
  void setFromKeyToIndexAndValueList(Map<String, int>? keyToIndexMap, List<dynamic>? valueList) {
    _checkMutable();
    _setFromKeyToIndexAndValueListInternal(keyToIndexMap, valueList);
  }

  //------------------------------------------------------------------------------------------------
  void _setFromKeyToIndexAndValueListInternal(
    Map<String, int>? keyToIndexMap,
    List<dynamic>? valueList,
  ) {
    if (keyToIndexMap == null || valueList == null) {
      return;
    }
    for (final MapEntry<String, int> keyToIndex in keyToIndexMap.entries) {
      _setInternal(keyToIndex.key, valueList[keyToIndex.value]);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Updates this Json5 object with the entries from [copyFromMap].
  void setFromMap(final Map<dynamic, dynamic> copyFromMap) {
    _checkMutable();
    _setFromMapInternal(copyFromMap);
  }

  //------------------------------------------------------------------------------------------------
  void _setFromMapInternal(final Map<dynamic, dynamic> copyFromMap) {
    for (final MapEntry<dynamic, dynamic> entry in copyFromMap.entries) {
      _setInternal(entry.key, entry.value);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Sets the value for [key] if the [newValue] has changed for the [oldJson] value.
  void setIfChanged(final dynamic key, final Json5 oldJson, final dynamic newValue) {
    final String localKey = _getKey(key);
    if (!_deepEquals(newValue, oldJson.asType(localKey))) {
      set(localKey, newValue);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not null and not empty (for Strings, Iterables,
  /// Maps, and Json5 objects).
  void setIfNewValueIsNotEmpty(dynamic key, final dynamic newValue) {
    if (newValue == null) return;
    if (newValue is String && newValue.isEmpty) return;
    if (newValue is Iterable<dynamic> && newValue.isEmpty) return;
    if (newValue is Map<dynamic, dynamic> && newValue.isEmpty) return;
    if (newValue is Json5 && newValue.isEmpty) return;
    set(key, newValue);
  }

  //------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not null.
  void setIfNewValueIsNotNull(dynamic key, final dynamic newValue) {
    if (newValue != null) {
      set(key, newValue);
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Sets the value for [key] only if [newValue] is not equal to [oldValue].
  /// For Iterables, equality is determined by having the same elements in the same order.
  /// For Maps, equality is determined by having the same keys with
  /// equal values. For Json5 objects, equality is determined by having the same keys with equal
  /// values.
  /// For other types, equality is determined by the == operator.
  void setIfNotEqual(dynamic key, {required dynamic newValue, required dynamic oldValue}) {
    if (!_deepEquals(oldValue, newValue)) {
      set(key, newValue);
    }
  }

  //------------------------------------------------------------------------------------------------
  void _setInternal(dynamic key, final dynamic value) {
    final String localKey = _getKey(key);
    _ephemeralKeys?.remove(localKey);
    switch (value) {
      case null:
        _keyToValueMap.remove(localKey);
      case DateTime dateTimeValue:
        _keyToValueMap[localKey] = dateTimeValue.format(dateTimeFormat);
      case Map<dynamic, dynamic> mapValue:
        _keyToValueMap[localKey] = Json5.fromMap(
          mapValue,
          caseSensitiveKeys: caseSensitiveKeys,
          dateTimeFormat: dateTimeFormat,
          readOnly: readOnly,
          sortedKeys: sortedKeys,
        );
      case Iterable<dynamic> iterableValue:
        _keyToValueMap[localKey] = _convertIterable(iterableValue, freeze: readOnly);
      default:
        _keyToValueMap[localKey] = value;
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Internal use.
  @internal
  void setParsedEntry(String key, dynamic value) {
    _ephemeralKeys?.remove(key);
    if (value == null) {
      _keyToValueMap.remove(key);
    } else if (value is DateTime) {
      _keyToValueMap[key] = value.format(dateTimeFormat);
    } else {
      _keyToValueMap[key] = value;
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Writes the formatted JSON5 representation of this object to the file at [path].
  void toFile(String path, {bool includeComments = true, bool json5 = true}) =>
      io.toFile(this, path, includeComments: includeComments, json5: json5);

  //------------------------------------------------------------------------------------------------
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

  //------------------------------------------------------------------------------------------------
  /// Generates a JSON5 or JSON string representation of the object. For a pretty-printed version,
  /// use [toFormattedString]. Pass [json5] to override the format (`true` for JSON5, `false` for
  /// standard JSON); defaults to [defaultUseJson5ForToString].
  String toJsonString({bool? json5}) {
    final bool useJson5 = json5 ?? defaultUseJson5ForToString;
    final StringBuffer buffer = StringBuffer();
    _writeJsonToBuffer(buffer, json5: useJson5);
    return buffer.toString();
  }

  //------------------------------------------------------------------------------------------------
  /// Converts this Json5 object to a standard [Map].
  Map<String, dynamic> toMap() {
    if (_ephemeralKeys == null || _ephemeralKeys!.isEmpty) return Map.of(_keyToValueMap);
    final map = <String, dynamic>{};
    for (final String key in keys) {
      map[key] = _keyToValueMap[key];
    }
    return map;
  }

  //------------------------------------------------------------------------------------------------
  @override
  String toString() => toJsonString();

  //------------------------------------------------------------------------------------------------
  void _writeComments({
    required StringBuffer buffer,
    required Object container,
    required bool includeComments,
    required Object keyOrIndex,
    required int level,
    required ECommentLocation location,
    Json5CommentRegistry? registry,
    bool skipPrecedingNewline = false,
  }) {
    if (!includeComments || registry == null) return;
    final List<Json5Comment>? comments = registry.getComments(container, keyOrIndex, location);
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

  //------------------------------------------------------------------------------------------------
  void _writeJsonToBuffer(StringBuffer buffer, {required bool json5}) {
    buffer.write("{");
    bool firstEntry = true;
    for (final String key in keys) {
      if (!firstEntry) {
        buffer.write(",");
      }
      _writeKey(buffer, key, json5: json5);
      buffer.write(":");
      _writeValueToBuffer(buffer, _keyToValueMap[key], json5: json5);
      firstEntry = false;
    }
    buffer.write("}");
  }

  //------------------------------------------------------------------------------------------------
  void _writeValueToBuffer(StringBuffer buffer, dynamic value, {required bool json5}) {
    switch (value) {
      case String stringValue:
        buffer.write('"');
        _writeEscapedString(buffer, stringValue);
        buffer.write('"');
      case num numValue:
        _writeNum(buffer, numValue, json5: json5);
      case bool boolValue:
        buffer.write(boolValue ? "true" : "false");
      case DateTime dateTimeValue:
        buffer
          ..write('"')
          ..write(dateTimeValue.format(dateTimeFormat))
          ..write('"');
      case Json5 jsonValue:
        jsonValue._writeJsonToBuffer(buffer, json5: json5);
      case Iterable<dynamic> iterableValue:
        buffer.write("[");
        bool first = true;
        for (final dynamic item in iterableValue) {
          if (!first) {
            buffer.write(",");
          }
          _writeValueToBuffer(buffer, item, json5: json5);
          first = false;
        }
        buffer.write("]");
      case Enum enumValue:
        buffer
          ..write('"')
          ..write(enumValue.name)
          ..write('"');
      case null:
        buffer.write("null");
      default:
        if (json5Util.isEnum(value)) {
          final String valueString = value.toString();
          buffer
            ..write('"')
            ..write(valueString.substring(valueString.lastIndexOf(".") + 1))
            ..write('"');
        } else {
          buffer.write('"');
          _writeEscapedString(buffer, value.toString());
          buffer.write('"');
        }
    }
  }

  //------------------------------------------------------------------------------------------------
}
