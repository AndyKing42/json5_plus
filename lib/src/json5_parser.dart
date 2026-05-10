import 'package:meta/meta.dart';

import 'json5.dart';
import 'json5_comment_registry.dart';

@internal
class Json5Parser {
  //--------------------------------------------------------------------------------------------------
  final bool _caseSensitiveKeys;
  final Json5CommentRegistry _commentRegistry;
  final String _jsonString;
  final int _jsonStringLength;
  final Map<String, String> _keyCacheMap;
  int _lineNumber;
  bool _newlineFoundInWhitespace;
  final Map<String, dynamic>? _params;
  int _pos;
  final bool _readOnly;
  final bool _useKeyCache;

  //--------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string.
  static Json5 decode({
    bool caseSensitiveKeys = false,
    required String jsonString,
    Map<String, dynamic>? params,
    bool readOnly = false,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    params: params,
    readOnly: readOnly,
  )._parse();

  //--------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    required bool caseSensitiveKeys,
    required String jsonString,
    Map<String, dynamic>? params,
    required bool readOnly,
  }) {
    final List<Json5> jsonList = [];
    final Json5Parser parser = Json5Parser._(
      caseSensitiveKeys: caseSensitiveKeys,
      jsonString: jsonString,
      params: params,
      readOnly: readOnly,
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

  //--------------------------------------------------------------------------------------------------
  Json5Parser._({
    required bool caseSensitiveKeys,
    required String jsonString,
    Map<String, dynamic>? params,
    required bool readOnly,
  }) : _caseSensitiveKeys = caseSensitiveKeys,
       _commentRegistry = Json5CommentRegistry(),
       _jsonString = jsonString,
       _jsonStringLength = jsonString.length,
       _keyCacheMap = {},
       _lineNumber = 1,
       _newlineFoundInWhitespace = false,
       _params = params,
       _pos = 0,
       _readOnly = readOnly,
       _useKeyCache = jsonString.length > 16_384;

  //--------------------------------------------------------------------------------------------------
  Never _error(String message) => throw FormatException("$message at line $_lineNumber, pos $_pos");

  //--------------------------------------------------------------------------------------------------
  Json5 _parse() {
    Json5 result;
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: ECommentLocation.standaloneBefore,
        container: _commentRegistry,
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
        container: _commentRegistry,
        index: 0,
      );
    }
    _commentRegistry.moveContainer(_commentRegistry, result);
    result.commentRegistry = _commentRegistry;
    return result;
  }

  //--------------------------------------------------------------------------------------------------
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

  //--------------------------------------------------------------------------------------------------
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
      for (final String line in lines) {
        _commentRegistry.add(
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

  //--------------------------------------------------------------------------------------------------
  String _parseKey() {
    String result;
    int codeUnit = _jsonString.codeUnitAt(_pos);
    if (codeUnit == 34 /* " */ || codeUnit == 39 /* ' */ ) {
      result = _parseString(codeUnit);
    } else {
      final int start = _pos;
      while (_pos < _jsonStringLength) {
        codeUnit = _jsonString.codeUnitAt(_pos);
        if (codeUnit == 58 /* : */ ||
            codeUnit <= 32 ||
            codeUnit == 44 /* , */ ||
            codeUnit == 125 /* } */ ) {
          break;
        }
        ++_pos;
      }
      result = _jsonString.substring(start, _pos);
    }
    if (_useKeyCache) {
      return _keyCacheMap[result] ??= result;
    }
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  Json5 _parseObject() {
    final Json5 result = Json5(caseSensitiveKeys: _caseSensitiveKeys, readOnly: _readOnly);
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
      if (_jsonString.codeUnitAt(_pos) == 125) /* "}" */ {
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

  //--------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive({
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
  }) {
    final int start = _pos;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == 44 ||
          codeUnit == 125 ||
          codeUnit == 93 ||
          codeUnit <= 32 ||
          codeUnit == 58 ||
          codeUnit == 40) {
        break;
      }
      ++_pos;
    }
    final String s = _jsonString.substring(start, _pos);
    if (s == r"$include") {
      final int savedPos = _pos;
      final int savedLine = _lineNumber;
      final bool savedNewline = _newlineFoundInWhitespace;
      _skipWhitespace();
      if (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) == 40 /* ( */ ) {
        return _parseFunctionCall(
          s,
          commentLocation: commentLocation,
          container: container,
          index: index,
          startPos: start,
        );
      }
      _pos = savedPos;
      _lineNumber = savedLine;
      _newlineFoundInWhitespace = savedNewline;
    }
    final dynamic parsed = switch (s) {
      "true" => true,
      "false" => false,
      "null" => null,
      _ => s.startsWith("0x") ? int.parse(s.substring(2), radix: 16) : num.tryParse(s) ?? s,
    };
    return parsed is String ? _resolveStringOrParam(parsed) : parsed;
  }

  //--------------------------------------------------------------------------------------------------
  String _parseString(int quote) {
    final int start = ++_pos;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == quote) {
        final String s = _jsonString.substring(start, _pos);
        ++_pos;
        return s;
      }
      if (codeUnit == 92 || codeUnit == 10) {
        _pos = start;
        return _parseStringWithEscapes(quote);
      }
      ++_pos;
    }
    _error("Unterminated string");
  }

  //--------------------------------------------------------------------------------------------------
  String _parseStringWithEscapes(int quote) {
    final StringBuffer buffer = StringBuffer();
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == quote) {
        ++_pos;
        return buffer.toString();
      }
      if (codeUnit == 92) /* "\" */ {
        ++_pos;
        if (_pos >= _jsonStringLength) {
          break;
        }
        final int nextCodeUnit = _jsonString.codeUnitAt(_pos);
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
            if (_pos + 4 >= _jsonStringLength) {
              _error("Incomplete unicode escape");
            }
            final int? charCode = int.tryParse(
              _jsonString.substring(_pos + 1, _pos + 5),
              radix: 16,
            );
            if (charCode == null) {
              _error("Invalid unicode escape");
            }
            buffer.writeCharCode(charCode);
            _pos += 4;
          case 120: // "\x"
            if (_pos + 2 >= _jsonStringLength) {
              _error("Incomplete hex escape");
            }
            final int? charCode = int.tryParse(
              _jsonString.substring(_pos + 1, _pos + 3),
              radix: 16,
            );
            if (charCode == null) {
              _error("Invalid hex escape");
            }
            buffer.writeCharCode(charCode);
            _pos += 2;
          default:
            buffer.writeCharCode(nextCodeUnit);
        }
      } else {
        if (codeUnit == 10) ++_lineNumber;
        buffer.writeCharCode(codeUnit);
      }
      ++_pos;
    }
    return buffer.toString();
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseValue({
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
  }) {
    if (_skipWhitespace()) {
      _skipWhitespaceAndRegisterComments(
        commentLocation: commentLocation,
        container: container,
        index: index,
      );
    }
    if (_pos >= _jsonStringLength) {
      return null;
    }
    final int codeUnit = _jsonString.codeUnitAt(_pos);
    return switch (codeUnit) {
      123 => _parseObject(), // "{"
      91 => _parseArray(), // "["
      34 || 39 => _resolveStringOrParam(_parseString(codeUnit)), // '"' or "'"
      43 || 45 || 46 || (>= 48 && <= 57) => _parsePrimitive(
        commentLocation: commentLocation,
        container: container,
        index: index,
      ), // Numbers (+, -, ., 0-9)
      116 || 102 || 110 || 73 || 78 => _parsePrimitive(
        commentLocation: commentLocation,
        container: container,
        index: index,
      ), // t, f, n, I, N
      (>= 65 && <= 90) || (>= 97 && <= 122) || 95 || 36 => _parsePrimitive(
        commentLocation: commentLocation,
        container: container,
        index: index,
      ), // A-Z, a-z, _, $
      _ => _error('Unexpected character "${String.fromCharCode(codeUnit)}",'),
    };
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _resolveParam(String key) {
    if (_params == null) {
      return null;
    }
    dynamic current = _params;
    for (final String part in key.split(".")) {
      if (current is Map) {
        current = current[part];
      } else if (current is Json5) {
        current = current.asType(part);
      } else {
        return null;
      }
      if (current == null) {
        return null;
      }
    }
    return current;
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _resolveStringOrParam(String stringValue) {
    if (_params == null || !stringValue.contains(r"${params.")) {
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
    return stringValue.replaceAllMapped(RegExp(r"\$\{params\.([^}]+)\}"), (Match match) {
      final String key = match.group(1)!;
      final dynamic resolved = _resolveParam(key);
      return resolved != null ? resolved.toString() : match.group(0)!;
    });
  }

  //--------------------------------------------------------------------------------------------------
  bool _skipWhitespace() {
    _newlineFoundInWhitespace = false;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit <= 32) {
        if (codeUnit == 10) {
          ++_lineNumber;
          _newlineFoundInWhitespace = true;
        }
        ++_pos;
        continue;
      }
      return codeUnit == 47; // '/'
    }
    return false;
  }

  //--------------------------------------------------------------------------------------------------
  void _skipWhitespaceAndRegisterComments({
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
  }) {
    bool newlineFound = _newlineFoundInWhitespace;
    _newlineFoundInWhitespace = false;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit <= 32) {
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
            while (_pos < _jsonStringLength && _jsonString.codeUnitAt(_pos) != 10) {
              ++_pos;
            }
          }
          final Json5Comment comment = Json5Comment(
            _jsonString.substring(startPos, _pos),
            blockComment: blockComment,
            precededByNewline: newlineFound,
          );
          _commentRegistry.add(
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

  //--------------------------------------------------------------------------------------------------
}
