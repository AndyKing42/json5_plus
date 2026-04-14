import 'package:meta/meta.dart';

import 'json5.dart';

// TODO(andy): document this!
///
class Json5Parser {
  //--------------------------------------------------------------------------------------------------
  final int _len;
  int _lineNumber;
  // TODO(andy): document this!
  ///
  ///@internal
  int pos;
  // TODO(andy): document this!
  ///
  final String jsonString;
  final bool _useJson5;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  @internal
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
  // TODO(andy): document this!
  ///
  @internal
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
    throw FormatException('$message at line $_lineNumber, pos $pos');
  }

  //--------------------------------------------------------------------------------------------------
  void _fillObject({Json5? json5, Map<String, dynamic>? map}) {
    final Map<String, dynamic> targetMap = json5?.keyToValueMap ?? map!;
    ++pos; // skip '{'
    while (pos < _len) {
      skipWhitespace();
      if (pos >= _len) break;
      if (jsonString.codeUnitAt(pos) == 125) /* '}' */ {
        ++pos;
        break;
      }
      final String key = _parseKey();
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 58) /* ':' */ {
        ++pos;
      }
      targetMap[key] = _parseValue();
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 44) /* ',' */ {
        ++pos;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  @internal
  bool get atEnd => pos >= _len;

  //--------------------------------------------------------------------------------------------------
  List<dynamic> _parseArray() {
    final List<dynamic> list = [];
    ++pos; // skip '['
    while (pos < _len) {
      skipWhitespace();
      if (pos >= _len) break;
      if (jsonString.codeUnitAt(pos) == 93) {
        // ']'
        ++pos;
        break;
      }
      list.add(_parseValue());
      skipWhitespace();
      if (pos < _len && jsonString.codeUnitAt(pos) == 44) {
        // ','
        ++pos;
      }
    }
    return list;
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  void parseInto(Json5 json) {
    skipWhitespace();
    if (pos < _len && jsonString.codeUnitAt(pos) == 123) {
      _fillObject(json5: json);
    } else {
      _error('Source does not start with a JSON5 object');
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
    ++pos;
    final int start = pos;
    while (pos < _len) {
      final int codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit == quote) {
        final String res = jsonString.substring(start, pos);
        ++pos;
        return res;
      }
      if (codeUnit == 92) ++pos; // skip escape char
      ++pos;
    }
    return "";
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseValue() {
    skipWhitespace();
    if (pos >= _len) return null;
    final int codeUnit = jsonString.codeUnitAt(pos);
    switch (codeUnit) {
      case 123: // '{'
        return _parseObject();
      case 91: // '['
        return _parseArray();
      case 34 || 39: // '"' or "'"
        return _parseString(codeUnit);
      // Numbers and Signs
      case 43 || 45 || 46 || 48 || 49 || 50 || 51 || 52 || 53 || 54 || 55 || 56 || 57:
        return _parsePrimitive();
      // Primitives: (t)rue, (f)alse, (n)ull, (I)nfinity, (N)aN
      case 116 || 102 || 110 || 73 || 78:
        return _parsePrimitive();
      // A-Z, a-z, _, $
      case (>= 65 && <= 90) || (>= 97 && <= 122) || 95 || 36:
        return _parsePrimitive();
      default:
        _error('Unexpected character "${String.fromCharCode(codeUnit)}"');
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  @internal
  void skipWhitespace() {
    if (pos >= _len) return;
    int codeUnit = jsonString.codeUnitAt(pos);
    if (codeUnit > 32 && codeUnit != 47) return;
    while (pos < _len) {
      codeUnit = jsonString.codeUnitAt(pos);
      if (codeUnit > 32 && codeUnit != 47) return;
      if (codeUnit <= 32) {
        if (codeUnit == 10) ++_lineNumber;
        ++pos;
      } else if (codeUnit == 47 && pos + 1 < _len) /* '/' */ {
        final int next = jsonString.codeUnitAt(pos + 1);
        if (next == 47) /* '/' + '/' */ {
          while (pos < _len && jsonString.codeUnitAt(pos) != 10) {
            ++pos;
          }
        } else if (next == 42) /* '/' + '*' */ {
          pos += 2;
          while (pos < _len - 1) {
            if (jsonString.codeUnitAt(pos) == 42 &&
                jsonString.codeUnitAt(pos + 1) == 47) /* '*' + '/' */ {
              pos += 2;
              break;
            }
            if (jsonString.codeUnitAt(pos) == 10) ++_lineNumber;
            ++pos;
          }
        } else {
          return;
        }
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
}
