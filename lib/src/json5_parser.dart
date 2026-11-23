import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5.dart';
import 'json5_comment_registry.dart';

@internal
class Json5Parser {
  //------------------------------------------------------------------------------------------------
  static final RegExp _paramsRegExp = RegExp(r"\$\{params\.([^}]+)\}");

  final bool _caseSensitiveKeys;
  Json5CommentRegistry? _commentRegistry;
  final EDateTimeFormat _dateTimeFormat;
  final Set<String>? _includePathSet;
  final String _jsonString;
  final int _jsonStringLength;
  final Map<String, String> _keyCacheMap;
  int _lineNumber;
  bool _newlineFoundInWhitespace;
  final Map<String, dynamic>? _params;
  int _pos;
  final bool _readOnly;
  final bool _sortedKeys;
  final String? _sourcePath;
  final bool _useKeyCache;

  //------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string.
  static Json5 decode({
    bool caseSensitiveKeys = false,
    EDateTimeFormat dateTimeFormat = EDateTimeFormat.iso8601,
    Set<String>? includePathSet,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool sortedKeys = false,
    String? sourcePath,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    includePathSet: includePathSet,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
    sourcePath: sourcePath,
  )._parse();

  //------------------------------------------------------------------------------------------------
  /// Decodes any valid JSON5 string (Object, Array, Primitive).
  static dynamic decodeAny({
    bool caseSensitiveKeys = false,
    EDateTimeFormat dateTimeFormat = EDateTimeFormat.iso8601,
    Set<String>? includePathSet,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool sortedKeys = false,
    String? sourcePath,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    includePathSet: includePathSet,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
    sourcePath: sourcePath,
  )._parseAny();

  //------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    required bool caseSensitiveKeys,
    required EDateTimeFormat dateTimeFormat,
    required String jsonString,
    Map<String, dynamic>? params,
    required bool readOnly,
    required bool sortedKeys,
  }) {
    final List<Json5> jsonList = [];
    final Json5Parser parser = Json5Parser._(
      caseSensitiveKeys: caseSensitiveKeys,
      dateTimeFormat: dateTimeFormat,
      jsonString: jsonString,
      params: params,
      readOnly: readOnly,
      sortedKeys: sortedKeys,
    );
    while (true) {
      if (parser._skipWhitespace()) {
        parser._skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.standaloneBefore,
          container: jsonList,
          keyOrIndex: 0,
        );
      }
      if (parser._pos >= parser._jsonStringLength) {
        break;
      }
      if (parser._jsonString.codeUnitAt(parser._pos) != 123 /* { */ ) {
        break;
      }
      final int objectStartPos = parser._pos;
      try {
        jsonList.add(parser._parseObject());
      } catch (e) {
        parser._pos = objectStartPos;
        break;
      }
    }
    return (jsonList: jsonList, unprocessed: jsonString.substring(parser._pos));
  }

  //------------------------------------------------------------------------------------------------
  Json5Parser._({
    required bool caseSensitiveKeys,
    required EDateTimeFormat dateTimeFormat,
    Set<String>? includePathSet,
    required String jsonString,
    Map<String, dynamic>? params,
    required bool readOnly,
    required bool sortedKeys,
    String? sourcePath,
  }) : _caseSensitiveKeys = caseSensitiveKeys,
       _dateTimeFormat = dateTimeFormat,
       _includePathSet = includePathSet,
       _jsonString = jsonString,
       _jsonStringLength = jsonString.length,
       _keyCacheMap = {},
       _lineNumber = 1,
       _newlineFoundInWhitespace = false,
       _params = params,
       _pos = 0,
       _readOnly = readOnly,
       _sortedKeys = sortedKeys,
       _sourcePath = sourcePath,
       _useKeyCache = jsonString.length > 16_384;

  //------------------------------------------------------------------------------------------------
  List<Json5Comment> _collectComments() {
    final List<Json5Comment> commentList = <Json5Comment>[];
    bool newlineFound = _newlineFoundInWhitespace;
    _newlineFoundInWhitespace = false;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (_isWhitespace(codeUnit)) {
        if (codeUnit == 10) /* \n */ {
          newlineFound = true;
          ++_lineNumber;
        }
        ++_pos;
      } else if (codeUnit == 47 /* / */ ) {
        if (_pos + 1 >= _jsonStringLength) {
          break;
        }
        final int nextCodeUnit = _jsonString.codeUnitAt(_pos + 1);
        if (nextCodeUnit == 47 /* / */ || nextCodeUnit == 42 /* * */ ) {
          final bool blockComment = nextCodeUnit == 42;
          final int startPos = _pos;
          _pos += 2;
          if (blockComment) {
            bool closed = false;
            while (_pos < _jsonStringLength - 1) {
              if (_jsonString.codeUnitAt(_pos) == 42 /* * */ &&
                  _jsonString.codeUnitAt(_pos + 1) == 47 /* / */ ) {
                _pos += 2;
                closed = true;
                break;
              }
              if (_jsonString.codeUnitAt(_pos) == 10) {
                ++_lineNumber;
              }
              ++_pos;
            }
            if (!closed) {
              _error("Unterminated block comment");
            }
          } else /* this is a line comment */ {
            while (_pos < _jsonStringLength) {
              final int c = _jsonString.codeUnitAt(_pos);
              if (c == 10 || c == 13 || c == 0x2028 || c == 0x2029) break;
              ++_pos;
            }
          }
          commentList.add(
            Json5Comment(
              _jsonString.substring(startPos, _pos),
              blockComment: blockComment,
              precededByNewline: newlineFound,
            ),
          );
          newlineFound = false;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return commentList;
  }

  //------------------------------------------------------------------------------------------------
  dynamic _convertResolvedValue(dynamic value) => switch (value) {
    Json5 jsonValue =>
      _readOnly && !jsonValue.readOnly ? Json5.fromJson5(jsonValue, readOnly: true) : jsonValue,
    Map<dynamic, dynamic> mapValue => Json5.fromMap(
      mapValue,
      caseSensitiveKeys: _caseSensitiveKeys,
      dateTimeFormat: _dateTimeFormat,
      readOnly: _readOnly,
      sortedKeys: _sortedKeys,
    ),
    Iterable<dynamic> iterableValue => _convertResolvedIterable(iterableValue),
    _ => value,
  };

  //------------------------------------------------------------------------------------------------
  Iterable<dynamic> _convertResolvedIterable(Iterable<dynamic> iterable) {
    if (iterable is Set<dynamic>) {
      final Set<dynamic> resultSet = <dynamic>{};
      for (final Object? item in iterable) {
        resultSet.add(_convertResolvedValue(item));
      }
      return _readOnly ? UnmodifiableSetView<dynamic>(resultSet) : resultSet;
    }
    final List<dynamic> resultList = <dynamic>[];
    for (final Object? item in iterable) {
      resultList.add(_convertResolvedValue(item));
    }
    return _readOnly ? UnmodifiableListView<dynamic>(resultList) : resultList;
  }

  //------------------------------------------------------------------------------------------------
  Never _error(String message) => throw FormatException("$message at line $_lineNumber, pos $_pos");

  //------------------------------------------------------------------------------------------------
  Json5 _parse() {
    Json5 result;
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: this,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_pos >= _jsonStringLength || _jsonString.codeUnitAt(_pos) != 123 /* { */ ) {
      _error("Source does not start with a JSON5 object");
    }
    result = _parseObject();
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: this,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_commentRegistry != null) {
      _commentRegistry!.moveContainer(this, result);
      result.commentRegistry = _commentRegistry!;
    }
    return result;
  }

  //------------------------------------------------------------------------------------------------
  dynamic _parseAny() {
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: this,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_pos >= _jsonStringLength) {
      _error("Source is empty or only contains whitespace");
    }
    final dynamic result = _parseValue(
      commentLocation: ECommentLocation.standaloneBefore,
      container: this,
      keyOrIndex: Json5CommentRegistry.trailingKey,
    );
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: this,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_pos < _jsonStringLength) {
      _error("Unexpected data after parsed value");
    }
    if (result is Json5 && _commentRegistry != null) {
      _commentRegistry!.moveContainer(this, result);
      result.commentRegistry = _commentRegistry!;
    }
    return result;
  }

  //------------------------------------------------------------------------------------------------
  List<dynamic> _parseArray() {
    final List<dynamic> valueList = [];
    ++_pos; // skip "["
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: valueList,
        keyOrIndex: 0,
      );
    }
    while (_pos < _jsonStringLength) {
      if (_jsonString.codeUnitAt(_pos) == 93) /* "]" */ {
        break;
      }
      valueList.add(
        _parseValue(
          commentLocation: ECommentLocation.standaloneBefore,
          container: valueList,
          keyOrIndex: valueList.length,
        ),
      );
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeComma,
          container: valueList,
          keyOrIndex: valueList.length,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          _skipWhitespaceAndRegisterComments(
            commentLocation: ECommentLocation.afterComma,
            container: valueList,
            keyOrIndex: valueList.length,
          );
        }
      } else if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) != 93 /* ] */ ) {
        _error("Expected ',' or ']' after array element");
      }
    }
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: valueList,
        keyOrIndex: valueList.length,
      );
    }
    if (_pos >= _jsonStringLength || _jsonString.codeUnitAt(_pos) != 93 /* ] */ ) {
      _error("Expected ']' at end of array");
    }
    ++_pos;
    if (_readOnly) {
      final List<dynamic> unmodifiableList = UnmodifiableListView<dynamic>(valueList);
      _commentRegistry?.moveContainer(valueList, unmodifiableList);
      return unmodifiableList;
    }
    return valueList;
  }

  //------------------------------------------------------------------------------------------------
  dynamic _parseFunctionCall(
    String functionName, {
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
    required int startPos,
  }) {
    ++_pos; // skip "("
    if (functionName == r"$include") {
      _skipWhitespace();
      if (_pos >= _jsonStringLength) {
        _error("Unexpected end of string in function call");
      }
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit != 34 /* " */ && codeUnit != 39 /* ' */ ) {
        _error("Expected string literal for included file path");
      }
      final String includePath = _parseString(codeUnit);
      Map<String, dynamic>? includeParams;
      _skipWhitespace();
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
        ++_pos;
        _skipWhitespace();
        if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 123 /* { */ ) {
          final Json5 parsedObject = _parseObject();
          includeParams = {};
          for (final String key in parsedObject.keys) {
            includeParams[key] = parsedObject.asType(key);
          }
        }
        _skipWhitespace();
        if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
          ++_pos; // skip optional trailing comma
          _skipWhitespace();
        }
      }
      if (_pos >= _jsonStringLength || _jsonString.codeUnitAt(_pos) != 41 /* ) */ ) {
        _error("Expected ')' after function arguments");
      }
      ++_pos;
      int pairStart = startPos - 1;
      while (pairStart >= 0) {
        final int c = _jsonString.codeUnitAt(pairStart);
        if (c == 10 /* \n */ || c == 44 /* , */ || c == 123 /* { */ || c == 91 /* [ */ ) {
          break;
        }
        pairStart--;
      }
      pairStart++;
      final String originalText = _jsonString.substring(pairStart, _pos);
      final List<String> lines = originalText.split('\n');
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].endsWith('\r')) {
          lines[i] = lines[i].substring(0, lines[i].length - 1);
        }
      }
      while (lines.isNotEmpty && lines.first.trim().isEmpty) {
        lines.removeAt(0);
      }
      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }
      int baseIndent = -1;
      for (final String line in lines) {
        if (line.trim().isNotEmpty) {
          final int indent = line.length - line.trimLeft().length;
          if (baseIndent == -1 || indent < baseIndent) {
            baseIndent = indent;
          }
        }
      }
      if (baseIndent > 0) {
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].length >= baseIndent && lines[i].substring(0, baseIndent).trim().isEmpty) {
            lines[i] = lines[i].substring(baseIndent);
          }
        }
      }
      final ECommentLocation targetLocation;
      final Object targetKeyOrIndex;
      if (container is Json5) {
        targetLocation = ECommentLocation.beforeKey;
        targetKeyOrIndex = keyOrIndex;
      } else {
        final int index = keyOrIndex is int ? keyOrIndex : 0;
        targetLocation = index == 0
            ? ECommentLocation.standaloneBefore
            : ECommentLocation.afterComma;
        targetKeyOrIndex = index == 0 ? 0 : index - 1;
      }
      _commentRegistry ??= Json5CommentRegistry();
      for (final String line in lines) {
        _commentRegistry!.add(
          comment: Json5Comment("// $line", blockComment: false, precededByNewline: true),
          commentLocation: targetLocation,
          container: container,
          keyOrIndex: targetKeyOrIndex,
        );
      }
      return Json5.loadIncludeFile(
        baseFilePath: _sourcePath,
        caseSensitiveKeys: _caseSensitiveKeys,
        dateTimeFormat: _dateTimeFormat,
        includePathSet: _includePathSet,
        params: includeParams,
        path: includePath,
        readOnly: _readOnly,
        sortedKeys: _sortedKeys,
      );
    }
    _error("Unknown function call: $functionName");
  }

  //------------------------------------------------------------------------------------------------
  String _parseKey() {
    String result;
    int codeUnit = _jsonString.codeUnitAt(_pos);
    if (codeUnit == 34 /* " */ || codeUnit == 39 /* ' */ ) {
      result = _parseString(codeUnit);
    } else {
      final int start = _pos;
      int localPos = start;
      while (localPos < _jsonStringLength) {
        codeUnit = _jsonString.codeUnitAt(localPos);
        if (codeUnit == 58 /* : */ ||
            _isWhitespace(codeUnit) ||
            codeUnit == 44 /* , */ ||
            codeUnit == 125 /* } */ ) {
          break;
        }
        ++localPos;
      }
      result = _jsonString.substring(start, localPos);
      _pos = localPos;
    }
    if (_useKeyCache) {
      return _keyCacheMap[result] ??= result;
    }
    return result;
  }

  //------------------------------------------------------------------------------------------------
  Json5 _parseObject() {
    final Json5 result = Json5(
      caseSensitiveKeys: _caseSensitiveKeys,
      dateTimeFormat: _dateTimeFormat,
      readOnly: _readOnly,
      sortedKeys: _sortedKeys,
    );
    ++_pos; // skip "{"
    List<Json5Comment>? pendingBeforeCommentList;
    if (_skipWhitespace()) {
      pendingBeforeCommentList = _collectComments();
    }
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == 125) /* "}" */ {
        break;
      }
      final String key = _parseKey();
      if (pendingBeforeCommentList != null && pendingBeforeCommentList.isNotEmpty) {
        _commentRegistry ??= Json5CommentRegistry();
        _commentRegistry!.addAll(
          commentLocation: ECommentLocation.beforeKey,
          commentList: pendingBeforeCommentList,
          container: result,
          keyOrIndex: key,
        );
        pendingBeforeCommentList = null;
      }
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeColon,
          container: result,
          keyOrIndex: key,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 58 /* : */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          _skipWhitespaceAndRegisterComments(
            commentLocation: ECommentLocation.afterColon,
            container: result,
            keyOrIndex: key,
          );
        }
      } else {
        _error("Expected ':' after object key");
      }
      result.setParsedEntry(
        key,
        _parseValue(
          commentLocation: ECommentLocation.afterColon,
          container: result,
          keyOrIndex: key,
        ),
      );
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeComma,
          container: result,
          keyOrIndex: key,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          final List<Json5Comment> afterCommaCommentList = _collectComments();
          if (afterCommaCommentList.isNotEmpty) {
            int splitIndex = afterCommaCommentList.length;
            for (int i = 0; i < afterCommaCommentList.length; ++i) {
              if (afterCommaCommentList[i].precededByNewline) {
                splitIndex = i;
                break;
              }
            }
            if (splitIndex > 0) {
              _commentRegistry ??= Json5CommentRegistry();
              _commentRegistry!.addAll(
                commentLocation: ECommentLocation.afterComma,
                commentList: afterCommaCommentList.sublist(0, splitIndex),
                container: result,
                keyOrIndex: key,
              );
            }
            if (splitIndex < afterCommaCommentList.length) {
              pendingBeforeCommentList = afterCommaCommentList.sublist(splitIndex);
            }
          }
        }
      } else if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) != 125 /* } */ ) {
        _error("Expected ',' or '}' after object property");
      }
    }
    if (pendingBeforeCommentList != null && pendingBeforeCommentList.isNotEmpty) {
      _commentRegistry ??= Json5CommentRegistry();
      _commentRegistry!.addAll(
        commentLocation: ECommentLocation.standaloneAfter,
        commentList: pendingBeforeCommentList,
        container: result,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: result,
        keyOrIndex: Json5CommentRegistry.trailingKey,
      );
    }
    if (_pos >= _jsonStringLength || _jsonString.codeUnitAt(_pos) != 125 /* "}" */ ) {
      _error("Expected '}'");
    }
    ++_pos;
    return result;
  }

  //------------------------------------------------------------------------------------------------
  @pragma('vm:prefer-inline')
  bool _isPrimitiveBoundary(int codeUnit) =>
      codeUnit == 44 || // ,
      codeUnit == 125 || // }
      codeUnit == 93 || // ]
      _isWhitespace(codeUnit) ||
      codeUnit == 58 || // :
      codeUnit == 40; // (

  //------------------------------------------------------------------------------------------------
  @pragma('vm:prefer-inline')
  bool _isWhitespace(int codeUnit) =>
      codeUnit <= 32 ||
      (codeUnit >= 0x00A0 &&
          (codeUnit == 0x00A0 || codeUnit == 0x2028 || codeUnit == 0x2029 || codeUnit == 0xFEFF));

  //------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive({
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
  }) {
    final int start = _pos;
    final int firstChar = _jsonString.codeUnitAt(_pos);
    final ({bool matched, dynamic value}) result = _parsePrimitiveBooleansNullOrInclude(
      commentLocation: commentLocation,
      container: container,
      firstChar: firstChar,
      keyOrIndex: keyOrIndex,
      start: start,
    );
    if (result.matched) {
      return result.value;
    }
    bool isSimpleNumber = firstChar >= 48 && firstChar <= 57;
    bool hasDigits = isSimpleNumber;
    int numberValue = isSimpleNumber ? firstChar - 48 : 0;
    bool isNegative = false;
    bool isDouble = false;
    int maxLength = 15;
    switch (firstChar) {
      case 45: /* - */
        isNegative = true;
        isSimpleNumber = true;
        maxLength = 16;
      case 43: /* + */
        isSimpleNumber = true;
        maxLength = 16;
      case 46: /* . */
        isSimpleNumber = true;
        isDouble = true;
    }
    int i = _pos + 1;
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (_isPrimitiveBoundary(codeUnit)) {
        break;
      }
      if (isSimpleNumber) {
        if (codeUnit >= 48 && codeUnit <= 57) {
          hasDigits = true;
          numberValue = numberValue * 10 + (codeUnit - 48);
        } else if (codeUnit == 46 && !isDouble) {
          isDouble = true;
        } else {
          isSimpleNumber = false;
        }
      }
      ++i;
    }
    int firstDigitPos = start;
    if (firstChar == 45 /* - */ || firstChar == 43 /* + */ ) {
      ++firstDigitPos;
    }
    if (i - firstDigitPos > 1 && _jsonString.codeUnitAt(firstDigitPos) == 48 /* 0 */ ) {
      final int nextChar = _jsonString.codeUnitAt(firstDigitPos + 1);
      if (nextChar >= 48 && nextChar <= 57) {
        _pos = start;
        _error("Numbers cannot have leading zeros");
      }
    }
    if (isSimpleNumber && hasDigits) {
      if (!isDouble && (i - start) <= maxLength) {
        _pos = i;
        return isNegative ? -numberValue : numberValue;
      }
      if (isDouble) {
        final String s = _jsonString.substring(start, i);
        _pos = i;
        final double? parsedDouble = double.tryParse(s);
        if (parsedDouble == null) {
          _pos = start;
          _error("Invalid number: $s");
        }
        return parsedDouble;
      }
    }
    final String s = _jsonString.substring(start, i);
    _pos = i;
    final dynamic parsed;
    if ((firstChar >= 48 && firstChar <= 57) ||
        firstChar == 45 || // -
        firstChar == 43 || // +
        firstChar == 46 /* . */ ) {
      parsed = switch (s) {
        "-Infinity" => double.negativeInfinity,
        "+Infinity" => double.infinity,
        "-NaN" || "+NaN" => double.nan,
        _ => _tryParseHex(s) ?? num.tryParse(s),
      };
      if (parsed == null) {
        _pos = start;
        _error("Invalid number: $s");
      }
    } else {
      parsed = switch (s) {
        "true" => true,
        "false" => false,
        "null" => null,
        "Infinity" => double.infinity,
        "NaN" => double.nan,
        _ => null,
      };
      if (parsed == null && s != "null") {
        _pos = start;
        _error("Invalid unquoted value: $s");
      }
    }
    return parsed;
  }

  //------------------------------------------------------------------------------------------------
  ({bool matched, dynamic value}) _parsePrimitiveBooleansNullOrInclude({
    required ECommentLocation commentLocation,
    required Object container,
    required int firstChar,
    required Object keyOrIndex,
    required int start,
  }) {
    if (firstChar == 116 /* t */ && _jsonString.startsWith("true", _pos)) {
      final int nextPos = _pos + 4;
      if (nextPos >= _jsonStringLength || _isPrimitiveBoundary(_jsonString.codeUnitAt(nextPos))) {
        _pos = nextPos;
        return (matched: true, value: true);
      }
    } else if (firstChar == 102 /* f */ && _jsonString.startsWith("false", _pos)) {
      final int nextPos = _pos + 5;
      if (nextPos >= _jsonStringLength || _isPrimitiveBoundary(_jsonString.codeUnitAt(nextPos))) {
        _pos = nextPos;
        return (matched: true, value: false);
      }
    } else if (firstChar == 110 /* n */ && _jsonString.startsWith("null", _pos)) {
      final int nextPos = _pos + 4;
      if (nextPos >= _jsonStringLength || _isPrimitiveBoundary(_jsonString.codeUnitAt(nextPos))) {
        _pos = nextPos;
        return (matched: true, value: null);
      }
    } else if (firstChar == 36 /* $ */ && _jsonString.startsWith(r"$include", _pos)) {
      final int savedPos = _pos;
      final int savedLine = _lineNumber;
      final bool savedNewline = _newlineFoundInWhitespace;
      _pos += 8;
      _skipWhitespace();
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 40 /* ( */ ) {
        final dynamic result = _parseFunctionCall(
          r"$include",
          commentLocation: commentLocation,
          container: container,
          keyOrIndex: keyOrIndex,
          startPos: start,
        );
        return (matched: true, value: result);
      }
      _pos = savedPos;
      _lineNumber = savedLine;
      _newlineFoundInWhitespace = savedNewline;
    }
    return (matched: false, value: null);
  }

  //------------------------------------------------------------------------------------------------
  String _parseString(int quote) {
    final int start = ++_pos;
    int i = start;
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (codeUnit == quote) {
        final String s = _jsonString.substring(start, i);
        _pos = i + 1;
        return s;
      }
      if (codeUnit == 92 || codeUnit == 10) {
        return _parseStringWithEscapes(firstSpecialIndex: i, quote: quote, start: start);
      }
      ++i;
    }
    _error("Unterminated string");
  }

  //------------------------------------------------------------------------------------------------
  String _parseStringWithEscapes({
    required int firstSpecialIndex,
    required int quote,
    required int start,
  }) {
    final StringBuffer buffer = StringBuffer();
    int chunkStart = start;
    int i = firstSpecialIndex;
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (codeUnit == quote) {
        if (i > chunkStart) {
          buffer.write(_jsonString.substring(chunkStart, i));
        }
        _pos = i + 1;
        return buffer.toString();
      }
      if (codeUnit == 92) /* "\" */ {
        if (i > chunkStart) {
          buffer.write(_jsonString.substring(chunkStart, i));
        }
        ++i;
        if (i >= _jsonStringLength) {
          break;
        }
        final int nextCodeUnit = _jsonString.codeUnitAt(i);
        switch (nextCodeUnit) {
          case 10:
            ++_lineNumber;
            buffer.writeCharCode(10); // Escaped newline
          case 13:
            if (i + 1 < _jsonStringLength && _jsonString.codeUnitAt(i + 1) == 10) {
              ++i;
            }
            ++_lineNumber;
            buffer.writeCharCode(10); // Escaped CR / CRLF newline
          case 48:
            buffer.writeCharCode(0); // "\0"
          case 98:
            buffer.writeCharCode(8); // "\b"
          case 102:
            buffer.writeCharCode(12); // "\f"
          case 110:
            buffer.writeCharCode(10); // "\n"
          case 114:
            buffer.writeCharCode(13); // "\r"
          case 116:
            buffer.writeCharCode(9); // "\t"
          case 117: // "\u"
            if (i + 4 >= _jsonStringLength) {
              _pos = i;
              _error("Incomplete unicode escape");
            }
            final int? charCode = int.tryParse(_jsonString.substring(i + 1, i + 5), radix: 16);
            if (charCode == null || charCode < 0) {
              _pos = i;
              _error("Invalid unicode escape");
            }
            buffer.writeCharCode(charCode);
            i += 4;
          case 118:
            buffer.writeCharCode(11); // "\v"
          case 120: // "\x"
            if (i + 2 >= _jsonStringLength) {
              _pos = i;
              _error("Incomplete hex escape");
            }
            final int? charCode = int.tryParse(_jsonString.substring(i + 1, i + 3), radix: 16);
            if (charCode == null || charCode < 0) {
              _pos = i;
              _error("Invalid hex escape");
            }
            buffer.writeCharCode(charCode);
            i += 2;
          default:
            buffer.writeCharCode(nextCodeUnit);
        }
        chunkStart = i + 1;
      } else if (codeUnit == 10) {
        ++_lineNumber;
      }
      ++i;
    }
    _pos = i;
    _error("Unterminated string");
  }

  //------------------------------------------------------------------------------------------------
  dynamic _parseValue({
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
  }) {
    if (_pos >= _jsonStringLength) {
      return null;
    }
    final int codeUnit = _jsonString.codeUnitAt(_pos);
    if (codeUnit == 123) return _parseObject(); // {
    if (codeUnit == 91) return _parseArray(); // [
    if (codeUnit == 34 || codeUnit == 39) /* "/' */ {
      return _resolveStringOrParam(_parseString(codeUnit)); // "/'
    }
    if (codeUnit == 43 || // +
        codeUnit == 45 || // -
        codeUnit == 46 || // .
        (codeUnit >= 48 && codeUnit <= 57) || // +/-/./0-9
        codeUnit == 116 || // t
        codeUnit == 102 || // f
        codeUnit == 110 || // n
        codeUnit == 73 || // I
        codeUnit == 78 || // t/f/n/I/N
        (codeUnit >= 65 && codeUnit <= 90) || // A-Z
        (codeUnit >= 97 && codeUnit <= 122) || // a-z
        codeUnit == 95 || // _
        codeUnit == 36 /* $ */ ) {
      return _parsePrimitive(
        commentLocation: commentLocation,
        container: container,
        keyOrIndex: keyOrIndex,
      );
    }
    _error('Unexpected character "${String.fromCharCode(codeUnit)}",');
  }

  //------------------------------------------------------------------------------------------------
  dynamic _resolveParam(String key) {
    if (_params == null) {
      return null;
    }
    dynamic current = _params;
    for (final String keyPart in key.split(".")) {
      current = switch (current) {
        Map<dynamic, dynamic> currentMap => currentMap[keyPart],
        Json5 json5Value => json5Value.asType(keyPart),
        _ => null,
      };
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  //------------------------------------------------------------------------------------------------
  dynamic _resolveStringOrParam(String stringValue) {
    if (_params == null || stringValue.length < 11 || !stringValue.contains(r"${params.")) {
      return stringValue;
    }
    if (stringValue.startsWith(r"${params.") && stringValue.endsWith("}")) {
      final String key = stringValue.substring(9, stringValue.length - 1);
      if (key.isNotEmpty && !key.contains("}")) {
        final dynamic resolved = _resolveParam(key);
        if (resolved != null) {
          return _convertResolvedValue(resolved);
        }
      }
    }
    return stringValue.replaceAllMapped(_paramsRegExp, (Match match) {
      final String key = match.group(1)!;
      final dynamic resolved = _resolveParam(key);
      return resolved != null ? resolved.toString() : match.group(0)!;
    });
  }

  //------------------------------------------------------------------------------------------------
  @pragma('vm:prefer-inline')
  bool _skipWhitespace() {
    _newlineFoundInWhitespace = false;
    int i = _pos;
    if (i >= _jsonStringLength) {
      return false;
    }
    final int firstCodeUnit = _jsonString.codeUnitAt(i);
    if (!_isWhitespace(firstCodeUnit)) {
      return firstCodeUnit == 47; // '/'
    }
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (_isWhitespace(codeUnit)) {
        if (codeUnit == 10) {
          ++_lineNumber;
          _newlineFoundInWhitespace = true;
        }
        ++i;
        continue;
      }
      _pos = i;
      return codeUnit == 47; // '/'
    }
    _pos = i;
    return false;
  }

  //------------------------------------------------------------------------------------------------
  void _skipWhitespaceAndRegisterComments({
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
  }) {
    final List<Json5Comment> commentList = _collectComments();
    if (commentList.isEmpty) {
      return;
    }
    _commentRegistry ??= Json5CommentRegistry();
    _commentRegistry!.addAll(
      commentLocation: commentLocation,
      commentList: commentList,
      container: container,
      keyOrIndex: keyOrIndex,
    );
  }

  //------------------------------------------------------------------------------------------------
  int? _tryParseHex(String value) {
    int startIndex = 0;
    bool isNegative = false;
    final int firstCodeUnit = value.codeUnitAt(0);
    if (firstCodeUnit == 45 /* - */ ) {
      isNegative = true;
      startIndex = 1;
    } else if (firstCodeUnit == 43 /* + */ ) {
      startIndex = 1;
    }
    if (value.length - startIndex < 3) {
      return null;
    }
    if (value.codeUnitAt(startIndex) != 48 /* 0 */ ) {
      return null;
    }
    final int prefixChar = value.codeUnitAt(startIndex + 1);
    if (prefixChar != 120 /* x */ && prefixChar != 88 /* X */ ) {
      return null;
    }
    final int firstHexDigit = value.codeUnitAt(startIndex + 2);
    final bool isHexDigit =
        (firstHexDigit >= 48 && firstHexDigit <= 57) ||
        (firstHexDigit >= 65 && firstHexDigit <= 70) ||
        (firstHexDigit >= 97 && firstHexDigit <= 102);
    if (!isHexDigit) {
      return null;
    }
    final String hexDigits = value.substring(startIndex + 2);
    return int.tryParse(isNegative ? "-$hexDigits" : hexDigits, radix: 16);
  }

  //------------------------------------------------------------------------------------------------
}
