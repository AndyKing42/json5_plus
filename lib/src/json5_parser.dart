import 'package:meta/meta.dart';

import 'json5.dart';

// TODO(andy): document this!
/// Internal parser responsible for converting JSON5 string payloads
/// into strongly typed Dart objects or populating given `Json5` maps.
class Json5Parser {
  //--------------------------------------------------------------------------------------------------
  final int _len;
  int _lineNumber;
  @internal
  //
  // ignore: public_member_api_docs
  int pos;
  // TODO(andy): document this!
  /// The raw JSON5 payload currently being parsed.
  final String jsonString;
  final bool _useJson5;

  //--------------------------------------------------------------------------------------------------
  @internal
  //
  // ignore: public_member_api_docs
  static Json5Parser createJson5Instance(String jsonString) =>
      Json5Parser._(jsonString: jsonString, useJson5: true);

  //--------------------------------------------------------------------------------------------------
  /// Decodes a JSON5 string into standard Dart types.
  ///
  /// Returns a [Map<String, dynamic>] for JSON objects, a [List] for arrays,
  /// or a primitive value (String, num, bool, null).
  ///
  /// To get a wrapped [Json5] object with case-insensitive support,
  /// use the [Json5] constructor instead.
  static dynamic decode(String jsonString) =>
      Json5Parser._(jsonString: jsonString, useJson5: false)._parseValue();

  //--------------------------------------------------------------------------------------------------
  @internal
  //
  // ignore: public_member_api_docs
  static void decodeInternal({required Json5 json5, required String jsonString}) =>
      Json5Parser._(jsonString: jsonString, useJson5: true).parseInto(json5);

  //--------------------------------------------------------------------------------------------------
  Json5Parser._({required this.jsonString, required bool useJson5})
    : _len = jsonString.length,
      _lineNumber = 1,
      pos = 0,
      _useJson5 = useJson5;

  //--------------------------------------------------------------------------------------------------
  Never _error(String message) {
    throw FormatException("$message at line $_lineNumber, pos $pos");
  }

  //--------------------------------------------------------------------------------------------------
  void _fillObject({Json5? json5, Map<String, dynamic>? map}) {
    final Map<String, dynamic> targetMap = json5?.keyToValueMap ?? map!;
    ++pos; // skip "{"
    skipWhitespace();
    while (pos < _len) {
      if (jsonString.codeUnitAt(pos) == 125) /* "}" */ {
        ++pos;
        break;
      }
      final String key = _parseKey();
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 58) ++pos; /* ":" */
      targetMap[key] = _parseValue();
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 44) {
        ++pos;
        skipWhitespace();
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  @internal
  //
  // ignore: public_member_api_docs
  bool get atEnd => pos >= _len;

  //--------------------------------------------------------------------------------------------------
  List<dynamic> _parseArray() {
    final List<dynamic> list = [];
    ++pos; // skip "["
    skipWhitespace();
    while (pos < _len) {
      if (jsonString.codeUnitAt(pos) == 93) /* "]" */ {
        ++pos;
        break;
      }
      list.add(_parseValue());
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 44) {
        ++pos;
        skipWhitespace();
      }
    }
    return list;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Consumes the input [jsonString] into the provided [json] target,
  /// appending or updating its state. Throws a [FormatException] if the root
  /// level of the target does not define a JSON object or parsing fails.
  void parseInto(Json5 json) {
    skipWhitespace();
    if (pos < _len && jsonString.codeUnitAt(pos) == 123) {
      _fillObject(json5: json);
    } else {
      _error("Source does not start with a JSON5 object");
    }
  }

  //--------------------------------------------------------------------------------------------------
  String _parseKey() {
    int codeUnit = jsonString.codeUnitAt(pos);
    if (codeUnit == 34 || codeUnit == 39) return _parseString(codeUnit);
    final int start = pos;
    while (pos < _len) {
      codeUnit = jsonString.codeUnitAt(pos);
      // Stop at colon, space, or end of object
      if (codeUnit == 58 || codeUnit <= 32 || codeUnit == 44 || codeUnit == 125) break;
      ++pos;
    }
    return jsonString.substring(start, pos);
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseObject() {
    if (_useJson5) {
      final Json5 json = Json5();
      _fillObject(json5: json);
      return json;
    }
    final Map<String, dynamic> map = {};
    _fillObject(map: map);
    return map;
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive() {
    final int start = pos;
    while (pos < _len) {
      final int codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit == 44 || codeUnit == 125 || codeUnit == 93 || codeUnit <= 32 || codeUnit == 58) {
        break;
      }
      ++pos;
    }
    final String val = jsonString.substring(start, pos);
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
    final int start = ++pos;
    while (pos < _len) {
      final int codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit == quote) {
        return jsonString.substring(start, pos++);
      }
      if (codeUnit == 92 || codeUnit == 10) {
        pos = start;
        return _parseStringWithEscapes(quote);
      }
      ++pos;
    }
    _error("Unterminated string");
  }

  //--------------------------------------------------------------------------------------------------
  String _parseStringWithEscapes(int quote) {
    final StringBuffer buffer = StringBuffer();
    while (pos < _len) {
      final int codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit == quote) {
        ++pos;
        return buffer.toString();
      }
      if (codeUnit == 92) /* "\" */ {
        ++pos;
        if (pos >= _len) break;
        final int nextCodeUnit = jsonString.codeUnitAt(pos);
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
      ++pos;
    }
    return buffer.toString();
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseValue() {
    skipWhitespace();
    if (pos >= _len) return null;
    final int codeUnit = jsonString.codeUnitAt(pos);
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
  @internal
  //
  // ignore: public_member_api_docs
  void skipWhitespace() {
    while (pos < _len) {
      final int codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit > 32) {
        if (codeUnit != 47) {
          return;
        }
        if (pos + 1 >= _len) {
          return;
        }
        final int next = jsonString.codeUnitAt(pos + 1);
        if (next == 47) /* "//" */ {
          pos += 2;
          while (pos < _len && jsonString.codeUnitAt(pos) != 10) {
            ++pos;
          }
          continue;
        } else if (next == 42) /* start of block comment */ {
          pos += 2;
          bool closed = false;
          while (pos < _len - 1) {
            if (jsonString.codeUnitAt(pos) == 42 && jsonString.codeUnitAt(pos + 1) == 47) {
              pos += 2;
              closed = true;
              break;
            }
            if (jsonString.codeUnitAt(pos) == 10) ++_lineNumber;
            ++pos;
          }
          if (!closed) _error("Unterminated block comment");
          continue;
        }
        return;
      }
      if (codeUnit == 10) ++_lineNumber;
      ++pos;
    }
  }

  //--------------------------------------------------------------------------------------------------
}
