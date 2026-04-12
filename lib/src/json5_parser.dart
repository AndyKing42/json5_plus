part of '../json5_plus.dart';

class _Json5Parser {
  //--------------------------------------------------------------------------------------------------
  final int _len;
  int _lineNumber;
  int _pos;
  final String _source;

  //--------------------------------------------------------------------------------------------------
  _Json5Parser(this._source) : _len = _source.length, _lineNumber = 1, _pos = 0;

  //--------------------------------------------------------------------------------------------------
  Never _error(String message) {
    throw FormatException('$message at line $_lineNumber, pos $_pos');
  }

  //--------------------------------------------------------------------------------------------------
  List<dynamic> _parseArray() {
    final List<dynamic> list = [];
    ++_pos; // skip '['
    while (_pos < _len) {
      _skipWhitespace();
      if (_pos >= _len) break;
      if (_source.codeUnitAt(_pos) == 93) {
        // ']'
        ++_pos;
        break;
      }
      list.add(_parseValue());
      _skipWhitespace();
      if (_pos < _len && _source.codeUnitAt(_pos) == 44) {
        // ','
        ++_pos;
      }
    }
    return list;
  }

  //--------------------------------------------------------------------------------------------------
  void parseInto(Json5 target) {
    _skipWhitespace();
    if (_pos < _len && _source.codeUnitAt(_pos) == 123) {
      _fillObject(target);
    } else {
      _error('Source does not start with a JSON5 object');
    }
  }

  //--------------------------------------------------------------------------------------------------
  String _parseKey() {
    int codeUnit = _source.codeUnitAt(_pos);
    if (codeUnit == 34 || codeUnit == 39) return _parseString(codeUnit);
    final int start = _pos;
    while (_pos < _len) {
      codeUnit = _source.codeUnitAt(_pos);
      // Stop at colon, space, or end of object
      if (codeUnit == 58 || codeUnit <= 32 || codeUnit == 44 || codeUnit == 125) break;
      ++_pos;
    }
    return _source.substring(start, _pos);
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseObject() {
    final Json5 json = Json5();
    _fillObject(json);
    return json;
  }

  //--------------------------------------------------------------------------------------------------
  void _fillObject(Json5 target) {
    ++_pos; // skip '{'
    while (_pos < _len) {
      _skipWhitespace();
      if (_pos >= _len) break;
      if (_source.codeUnitAt(_pos) == 125) {
        // '}'
        ++_pos;
        break;
      }
      final String key = _parseKey();
      _skipWhitespace();
      if (_pos < _len && _source.codeUnitAt(_pos) == 58) {
        // ':'
        ++_pos;
      }
      // Set directly into the target map
      target._keyToValueMap[key] = _parseValue();
      _skipWhitespace();
      if (_pos < _len && _source.codeUnitAt(_pos) == 44) {
        // ','
        ++_pos;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parsePrimitive() {
    final int start = _pos;
    while (_pos < _len) {
      final int codeUnit = _source.codeUnitAt(_pos);
      if (codeUnit == 44 || codeUnit == 125 || codeUnit == 93 || codeUnit <= 32 || codeUnit == 58) {
        break;
      }
      ++_pos;
    }
    final String val = _source.substring(start, _pos);
    if (val == "true") return true;
    if (val == "false") return false;
    if (val == "null") return null;
    if (val.startsWith("0x")) {
      return int.parse(val.substring(2), radix: 16);
    }
    return num.tryParse(val) ?? val;
  }

  //--------------------------------------------------------------------------------------------------
  String _parseString(int quote) {
    ++_pos; // skip opening quote
    final int start = _pos;
    while (_pos < _len) {
      final int codeUnit = _source.codeUnitAt(_pos);
      if (codeUnit == quote) {
        final String res = _source.substring(start, _pos);
        ++_pos;
        return res;
      }
      if (codeUnit == 92) ++_pos; // skip escape char
      ++_pos;
    }
    return "";
  }

  //--------------------------------------------------------------------------------------------------
  dynamic _parseValue() {
    _skipWhitespace();
    if (_pos >= _len) return null;
    final int codeUnit = _source.codeUnitAt(_pos);
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
  void _skipWhitespace() {
    if (_pos >= _len) return;
    int codeUnit = _source.codeUnitAt(_pos);
    if (codeUnit > 32 && codeUnit != 47) return;
    while (_pos < _len) {
      codeUnit = _source.codeUnitAt(_pos);
      if (codeUnit <= 32) {
        if (codeUnit == 10) ++_lineNumber;
        ++_pos;
      } else if (codeUnit == 47 && _pos + 1 < _len) {
        // '/'
        final int next = _source.codeUnitAt(_pos + 1);
        if (next == 47) {
          // '//'
          while (_pos < _len && _source.codeUnitAt(_pos) != 10) {
            ++_pos;
          }
        } else if (next == 42) {
          // '/*'
          _pos += 2;
          while (_pos < _len - 1) {
            if (_source.codeUnitAt(_pos) == 42 && _source.codeUnitAt(_pos + 1) == 47) {
              _pos += 2;
              break;
            }
            if (_source.codeUnitAt(_pos) == 10) ++_lineNumber;
            ++_pos;
          }
        } else {
          break;
        }
      } else {
        break;
      }
    }
  }

  //--------------------------------------------------------------------------------------------------
}
