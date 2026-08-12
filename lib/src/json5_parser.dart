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
  final String _jsonString;
  final int _jsonStringLength;
  final Map<String, String> _keyCacheMap;
  int _lineNumber;
  bool _newlineFoundInWhitespace;
  final Map<String, dynamic>? _params;
  int _pos;
  final bool _readOnly;
  final bool _sortedKeys;
  final bool _useKeyCache;

  //------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string.
  static Json5 decode({
    bool caseSensitiveKeys = false,
    EDateTimeFormat dateTimeFormat = EDateTimeFormat.iso8601,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool sortedKeys = false,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
  )._parse();

  //------------------------------------------------------------------------------------------------
  /// Decodes any valid JSON5 string (Object, Array, Primitive).
  static dynamic decodeAny({
    bool caseSensitiveKeys = false,
    EDateTimeFormat dateTimeFormat = EDateTimeFormat.iso8601,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
    bool sortedKeys = false,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    dateTimeFormat: dateTimeFormat,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
    sortedKeys: sortedKeys,
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
          index: 0,
        );
      }
      if (parser._pos >= parser._jsonStringLength) {
        break;
      }
      if (parser._jsonString.codeUnitAt(parser._pos) != 123 /* { */ ) {
        break;
      }
      try {
        jsonList.add(parser._parseObject());
      } catch (e) {
        break;
      }
    }
    return (jsonList: jsonList, unprocessed: jsonString.substring(parser._pos));
  }

  //------------------------------------------------------------------------------------------------
  Json5Parser._({
    required bool caseSensitiveKeys,
    required EDateTimeFormat dateTimeFormat,
    required String jsonString,
    Map<String, dynamic>? params,
    required bool readOnly,
    required bool sortedKeys,
  }) : _caseSensitiveKeys = caseSensitiveKeys,
       _dateTimeFormat = dateTimeFormat,
       _jsonString = jsonString,
       _jsonStringLength = jsonString.length,
       _keyCacheMap = {},
       _lineNumber = 1,
       _newlineFoundInWhitespace = false,
       _params = params,
       _pos = 0,
       _readOnly = readOnly,
       _sortedKeys = sortedKeys,
       _useKeyCache = jsonString.length > 16_384;

  //------------------------------------------------------------------------------------------------
  Never _error(String message) => throw FormatException("$message at line $_lineNumber, pos $_pos");

  //------------------------------------------------------------------------------------------------
  Json5 _parse() {
    Json5 result;
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: this,
        index: 0,
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
        index: 0,
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
        index: 0,
      );
    }
    if (_pos >= _jsonStringLength) {
      _error("Source is empty or only contains whitespace");
    }
    final dynamic result = _parseValue(
      commentLocation: ECommentLocation.standaloneBefore,
      container: this,
      index: 0,
    );
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: this,
        index: 0,
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
        index: 0,
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
          index: valueList.length,
        ),
      );
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeComma,
          container: valueList,
          index: valueList.length,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          _skipWhitespaceAndRegisterComments(
            commentLocation: ECommentLocation.afterComma,
            container: valueList,
            index: valueList.length,
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
        index: valueList.length,
      );
    }
    if (_pos >= _jsonStringLength || _jsonString.codeUnitAt(_pos) != 93 /* ] */ ) {
      _error("Expected ']' at end of array");
    }
    ++_pos;
    return valueList;
  }

  //------------------------------------------------------------------------------------------------
  dynamic _parseFunctionCall(
    String functionName, {
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
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
      final ECommentLocation targetLocation = index == 0
          ? ECommentLocation.standaloneBefore
          : ECommentLocation.afterComma;
      final int targetIndex = index == 0 ? 0 : index - 1;
      _commentRegistry ??= Json5CommentRegistry();
      for (final String line in lines) {
        _commentRegistry!.add(
          comment: Json5Comment("// $line", blockComment: false, precededByNewline: true),
          commentLocation: targetLocation,
          container: container,
          index: targetIndex,
        );
      }
      return Json5.fromFile(includePath, params: includeParams);
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
            codeUnit <= 32 ||
            codeUnit == 0x2028 ||
            codeUnit == 0x2029 ||
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
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: result,
        index: 0,
      );
    }
    int keyIndex = 0;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == 125) /* "}" */ {
        break;
      }
      final String key = _parseKey();
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeColon,
          container: result,
          index: keyIndex,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 58 /* : */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          _skipWhitespaceAndRegisterComments(
            commentLocation: ECommentLocation.afterColon,
            container: result,
            index: keyIndex,
          );
        }
      } else {
        _error("Expected ':' after object key");
      }
      result.set(
        key,
        _parseValue(
          commentLocation: ECommentLocation.afterColon,
          container: result,
          index: keyIndex,
        ),
      );
      if (_skipWhitespace()) {
        _skipWhitespaceAndRegisterComments(
          commentLocation: ECommentLocation.beforeComma,
          container: result,
          index: keyIndex,
        );
      }
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 44 /* , */ ) {
        ++_pos;
        if (_skipWhitespace()) {
          _skipWhitespaceAndRegisterComments(
            commentLocation: ECommentLocation.afterComma,
            container: result,
            index: keyIndex,
          );
        }
      } else if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) != 125 /* } */ ) {
        _error("Expected ',' or '}' after object property");
      }
      ++keyIndex;
    }
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneAfter,
        container: result,
        index: keyIndex,
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
      codeUnit <= 32 || // whitespace
      codeUnit == 0x2028 || // line separator
      codeUnit == 0x2029 || // paragraph separator
      codeUnit == 58 || // :
      codeUnit == 40; // (

  //------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive({
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
  }) {
    final int start = _pos;
    final int firstChar = _jsonString.codeUnitAt(_pos);
    final ({bool matched, dynamic value}) result =
        _parsePrimitiveBooleansNullOrInclude(
      commentLocation: commentLocation,
      container: container,
      firstChar: firstChar,
      index: index,
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
    int fractionalDivisor = 1;
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
      if (codeUnit == 44 || // ,
          codeUnit == 125 || // }
          codeUnit == 93 || // ]
          codeUnit <= 32 || // whitespace
          codeUnit == 0x2028 ||
          codeUnit == 0x2029 ||
          codeUnit == 58 || // :
          codeUnit == 40) /* ( */ {
        break;
      }
      if (isSimpleNumber) {
        if (codeUnit >= 48 && codeUnit <= 57) {
          hasDigits = true;
          numberValue = numberValue * 10 + (codeUnit - 48);
          if (isDouble) {
            fractionalDivisor *= 10;
          }
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
      firstDigitPos++;
    }
    if (i - firstDigitPos > 1 && _jsonString.codeUnitAt(firstDigitPos) == 48 /* 0 */ ) {
      final int nextChar = _jsonString.codeUnitAt(firstDigitPos + 1);
      if (nextChar >= 48 && nextChar <= 57) {
        _pos = start;
        _error("Numbers cannot have leading zeros");
      }
    }
    if (isSimpleNumber && hasDigits && (i - start) <= maxLength) {
      _pos = i;
      if (isDouble) {
        return (isNegative ? -numberValue : numberValue) / fractionalDivisor;
      }
      return isNegative ? -numberValue : numberValue;
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
        _ =>
          s.startsWith("0x")
              ? int.tryParse(s.substring(2), radix: 16)
              : s.startsWith("-0x")
              ? int.tryParse("-${s.substring(3)}", radix: 16)
              : s.startsWith("+0x")
              ? int.tryParse(s.substring(3), radix: 16)
              : num.tryParse(s),
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
    required int index,
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
          index: index,
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
        _pos = start;
        return _parseStringWithEscapes(quote);
      }
      ++i;
    }
    _error("Unterminated string");
  }

  //------------------------------------------------------------------------------------------------
  String _parseStringWithEscapes(int quote) {
    final StringBuffer buffer = StringBuffer();
    int i = _pos;
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (codeUnit == quote) {
        _pos = i + 1;
        return buffer.toString();
      }
      if (codeUnit == 92) /* "\" */ {
        ++i;
        if (i >= _jsonStringLength) {
          break;
        }
        final int nextCodeUnit = _jsonString.codeUnitAt(i);
        switch (nextCodeUnit) {
          case 10:
            ++_lineNumber;
            buffer.writeCharCode(10); // Escaped newline
          case 98:
            buffer.writeCharCode(8); // "\b"
          case 116:
            buffer.writeCharCode(9); // "\t"
          case 110:
            buffer.writeCharCode(10); // "\n"
          case 102:
            buffer.writeCharCode(12); // "\f"
          case 114:
            buffer.writeCharCode(13); // "\r"
          case 117: // "\u"
            if (i + 4 >= _jsonStringLength) {
              _pos = i;
              _error("Incomplete unicode escape");
            }
            final int? charCode = int.tryParse(_jsonString.substring(i + 1, i + 5), radix: 16);
            if (charCode == null) {
              _pos = i;
              _error("Invalid unicode escape");
            }
            buffer.writeCharCode(charCode);
            i += 4;
          case 120: // "\x"
            if (i + 2 >= _jsonStringLength) {
              _pos = i;
              _error("Incomplete hex escape");
            }
            final int? charCode = int.tryParse(_jsonString.substring(i + 1, i + 3), radix: 16);
            if (charCode == null) {
              _pos = i;
              _error("Invalid hex escape");
            }
            buffer.writeCharCode(charCode);
            i += 2;
          default:
            buffer.writeCharCode(nextCodeUnit);
        }
      } else {
        if (codeUnit == 10) ++_lineNumber;
        buffer.writeCharCode(codeUnit);
      }
      ++i;
    }
    _pos = i;
    return buffer.toString();
  }

  //------------------------------------------------------------------------------------------------
  dynamic _parseValue({
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
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
      return _parsePrimitive(commentLocation: commentLocation, container: container, index: index);
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
    if (_params == null ||
        stringValue.length < 4 ||
        stringValue.codeUnitAt(0) != 36 /* $ */ ||
        stringValue.codeUnitAt(1) != 123 /* { */ ) {
      return stringValue;
    }
    if (stringValue.startsWith(r"${params.") && stringValue.endsWith("}")) {
      final String key = stringValue.substring(10, stringValue.length - 1);
      if (stringValue == "${r"${params."}$key}") {
        final dynamic resolved = _resolveParam(key);
        if (resolved != null) {
          return resolved;
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
    if (firstCodeUnit > 32 && firstCodeUnit != 0x2028 && firstCodeUnit != 0x2029) {
      return firstCodeUnit == 47; // '/'
    }
    while (i < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(i);
      if (codeUnit <= 32 || codeUnit == 0x2028 || codeUnit == 0x2029) {
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
    required int index,
  }) {
    bool newlineFound = _newlineFoundInWhitespace;
    _newlineFoundInWhitespace = false;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit <= 32 || codeUnit == 0x2028 || codeUnit == 0x2029) {
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
          _commentRegistry ??= Json5CommentRegistry();
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
          final Json5Comment comment = Json5Comment(
            _jsonString.substring(startPos, _pos),
            blockComment: blockComment,
            precededByNewline: newlineFound,
          );
          _commentRegistry?.add(
            comment: comment,
            commentLocation: commentLocation,
            container: container,
            index: index,
          );
          newlineFound = false;
        }
      } else {
        break;
      }
    }
  }

  //------------------------------------------------------------------------------------------------
}
