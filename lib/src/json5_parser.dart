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
  int _lineNumber;
  int _pos;
  final bool _readOnly;

  //--------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string.
  static Json5 decode({
    bool caseSensitiveKeys = false,
    required String jsonString,
    bool readOnly = false,
  }) => Json5Parser._(
    caseSensitiveKeys: caseSensitiveKeys,
    jsonString: jsonString,
    readOnly: readOnly,
  )._parse();

  //--------------------------------------------------------------------------------------------------
  /// Parses a string containing multiple JSON5 objects and returns them as a list,
  /// along with any trailing unprocessed text.
  static ({List<Json5> jsonList, String unprocessed}) decodeMultiple({
    required bool caseSensitiveKeys,
    required String jsonString,
    required bool readOnly,
  }) {
    final List<Json5> jsonList = [];
    final Json5Parser parser = Json5Parser._(
      caseSensitiveKeys: caseSensitiveKeys,
      jsonString: jsonString,
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
    required bool readOnly,
  }) : _caseSensitiveKeys = caseSensitiveKeys,
       _commentRegistry = Json5CommentRegistry(),
       _jsonString = jsonString,
       _jsonStringLength = jsonString.length,
       _lineNumber = 1,
       _pos = 0,
       _readOnly = readOnly;

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
    // _currentContainer = parentContainer;
    // _currentIndex = parentIndex;
    return valueList;
  }

  //--------------------------------------------------------------------------------------------------
  String _parseKey() {
    int codeUnit = _jsonString.codeUnitAt(_pos);
    if (codeUnit == 34 || codeUnit == 39) {
      return _parseString(codeUnit);
    }
    final int start = _pos;
    while (_pos < _jsonStringLength) {
      codeUnit = _jsonString.codeUnitAt(_pos);
      // Stop at colon, space, or end of object
      if (codeUnit == 58 || codeUnit <= 32 || codeUnit == 44 || codeUnit == 125) break;
      ++_pos;
    }
    return _jsonString.substring(start, _pos);
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
    // _currentContainer = parentContainer;
    // _currentIndex = parentIndex;
    return result;
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive() {
    final int start = _pos;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == 44 || codeUnit == 125 || codeUnit == 93 || codeUnit <= 32 || codeUnit == 58) {
        break;
      }
      ++_pos;
    }
    final String val = _jsonString.substring(start, _pos);
    switch (val) {
      case "true":
        return true;
      case "false":
        return false;
      case "null":
        return null;
      default:
        return val.startsWith("0x")
            ? int.parse(val.substring(2), radix: 16)
            : num.tryParse(val) ?? val;
    }
  }

  //--------------------------------------------------------------------------------------------------
  String _parseString(int quote) {
    final int start = ++_pos;
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit == quote) {
        final String result = _jsonString.substring(start, _pos);
        ++_pos;
        return result;
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
        if (_pos >= _jsonStringLength) break;
        final int nextCodeUnit = _jsonString.codeUnitAt(_pos);
        switch (nextCodeUnit) {
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
          case 10:
            ++_lineNumber;
            buffer.writeCharCode(10); // Escaped newline
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
    if (_pos >= _jsonStringLength) return null;
    final int codeUnit = _jsonString.codeUnitAt(_pos);
    switch (codeUnit) {
      case 123: // "{"
        return _parseObject();
      case 91: // "["
        return _parseArray();
      case 34 || 39: // '"' or "'"
        return _parseString(codeUnit);
      case 43 || 45 || 46 || (>= 48 && <= 57):
        // Numbers (+, -, ., 0-9)
        return _parsePrimitive();
      case 116 || 102 || 110 || 73 || 78: // t, f, n, I, N
        return _parsePrimitive();
      case (>= 65 && <= 90) || (>= 97 && <= 122) || 95 || 36: // A-Z, a-z, _, $
        return _parsePrimitive();
      default:
        _error('Unexpected character "${String.fromCharCode(codeUnit)}"');
    }
  }

  //--------------------------------------------------------------------------------------------------
  bool _skipWhitespace() {
    while (_pos < _jsonStringLength) {
      final int codeUnit = _jsonString.codeUnitAt(_pos);
      if (codeUnit <= 32) {
        if (codeUnit == 10) ++_lineNumber;
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
    bool newlineFound = false;
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
            commentLocation: newlineFound ? ECommentLocation.standaloneBefore : commentLocation,
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
