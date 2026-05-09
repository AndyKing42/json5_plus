import "package:json5_plus/json5_plus.dart";
import "package:test/test.dart";

void main() {
  void testJson(String jsonText, dynamic expectedValue) {
    // json5_plus parses only top-level objects, so we wrap primitives and arrays.
    final String wrappedJson = '{"k": $jsonText}';
    try {
      final Json5 json = Json5.fromString(wrappedJson);
      final dynamic actualValue = json.asType("k");

      void compare(dynamic expected, dynamic actual, String path) {
        if (expected is List) {
          expect(actual, isA<List<dynamic>>(), reason: "$path: List type");
          expect((actual as List<dynamic>).length, expected.length, reason: "$path: List length");
          for (int i = 0; i < expected.length; ++i) {
            compare(expected[i], actual[i], "$path[$i]");
          }
        } else if (expected is Map) {
          if (actual is Json5) {
            expect(actual.length, expected.length, reason: "$path: Map size");
            expected.forEach((dynamic key, dynamic value) {
              expect(actual.containsKey(key), isTrue, reason: "$path: Missing key $key");
              compare(value, actual.asType(key), "$path[$key]");
            });
          } else if (actual is Map) {
            expect(actual.length, expected.length, reason: "$path: Map size");
            expected.forEach((dynamic key, dynamic value) {
              expect(actual.containsKey(key), isTrue, reason: "$path: Missing key $key");
              compare(value, actual[key], "$path[$key]");
            });
          } else {
            fail("$path: Expected Map or Json5, got ${actual.runtimeType}");
          }
        } else if (expected is num) {
          expect(actual, isA<num>(), reason: "$path: not number type");
          if (expected.isNaN) {
            expect((actual as num).isNaN, isTrue, reason: "$path: Expected NaN, was: $actual");
          } else {
            expect(actual, equals(expected), reason: "$path: Expected: $expected, was: $actual");
          }
        } else {
          expect(actual, equals(expected), reason: "$path in $jsonText");
        }
      }

      compare(expectedValue, actualValue, "root");
    } catch (e, stack) {
      fail("Failed to parse $wrappedJson: $e\n$stack");
    }
  }

  void testThrows(String jsonText) {
    final String wrappedJson = '{"k": $jsonText}';
    expect(
      () => Json5.fromString(wrappedJson),
      throwsA(isA<FormatException>()),
      reason: "Expected FormatException for: $wrappedJson",
    );
  }

  group("Dart SDK json_test.dart equivalents", () {
    test("Numbers", () {
      const List<String> integerList = <String>["0", "9", "9999"];
      const List<String> signList = <String>["", "-"];
      const List<String> fractionList = <String>["", ".0", ".1", ".99999"];
      final List<String> exponentList = <String>[""];
      const List<String> expHeadList = <String>["e", "E", "e-", "E-", "e+", "E+"];
      const List<String> expValueList = <String>["0", "1", "200"];
      for (int i = 0; i < expHeadList.length; ++i) {
        for (int j = 0; j < expValueList.length; ++j) {
          exponentList.add("${expHeadList[i]}${expValueList[j]}");
        }
      }

      for (int i = 0; i < integerList.length; ++i) {
        for (int j = 0; j < signList.length; ++j) {
          for (int k = 0; k < fractionList.length; ++k) {
            for (int l = 0; l < exponentList.length; ++l) {
              const List<String> whitespaceList = <String>["", " ", "\t"];
              for (int w = 0; w < whitespaceList.length; ++w) {
                final String ws = whitespaceList[w];
                final String literal =
                    "$ws${signList[j]}${integerList[i]}${fractionList[k]}${exponentList[l]}$ws";
                final num expectedValue = num.parse(literal);
                testJson(literal, expectedValue);
              }
            }
          }
        }
      }

      testJson("9223372036854774784", 9223372036854774784);
      testJson("-9223372036854775808", -9223372036854775808);
      testJson("9223372036854775808", 9223372036854775808.0);
      testJson("-9223372036854775809", -9223372036854775809.0);
      testJson("9223372036854775808.0", 9223372036854775808.0);
      testJson("9223372036854775810", 9223372036854775810.0);
      testJson("18446744073709551616.0", 18446744073709551616.0);
      testJson("1e309", double.infinity);
      testJson("-1e309", double.negativeInfinity);
      testJson("1e-325", 0.0);
      testJson("-1e-325", -0.0);
      testJson("1e18446744073709551616", double.infinity);
      testJson("-1e18446744073709551616", double.negativeInfinity);
      testJson("1e-18446744073709551616", 0.0);
      testJson("-1e-18446744073709551616", -0.0);

      testJson("1e+400", double.infinity);

      // JSON5 valid number formats that throw in strict JSON
      testJson(".0", 0.0);
      testJson("0.", 0.0);
      testJson("Infinity", double.infinity);
      testJson("-Infinity", double.negativeInfinity);
      testJson("NaN", double.nan);

      testThrows("-2 .2e+2");
      testThrows("-2. 2e+2");
      testThrows("-2.2 e+2");
      testThrows("-2.2e +2");
      testThrows("-2.2e+ 2");
    });

    test("Strings", () {
      const String input = r'"\n\r\f\t\b\/\\ \" \x20"';
      const String expectedValue = '\n\r\f\t\b/\\ "  ';
      testJson(input, expectedValue);
      testJson('""', "");

      const Map<String, String> escapeMap = <String, String>{
        "f": "\f",
        "b": "\b",
        "n": "\n",
        "r": "\r",
        "t": "\t",
        '"': '"',
        "/": "/",
      };
      for (final MapEntry<String, String> entry in escapeMap.entries) {
        final String escape = entry.key;
        final String literal = entry.value;

        testJson('"\\$escape........"', "$literal........");
        testJson('"........\\$escape"', "........$literal");
        testJson('"....\\$escape...."', "....$literal....");
      }

      testThrows(r'"......\"');
      testThrows(r'"\"');
      for (int i = 0; i < 32; ++i) {
        // testThrows(String.fromCharCodes([0x22, i, 0x22]));
        // json5_plus allows raw control characters in strings.
      }
    });

    test("Objects", () {
      testJson("{}", <dynamic, dynamic>{});
      testJson('{"x":42}', <String, dynamic>{"x": 42});
      testJson('{"x":{"x":{"x":42}}}', <String, dynamic>{
        "x": <String, dynamic>{
          "x": <String, dynamic>{"x": 42},
        },
      });
      testJson('{"x":10,"x":42}', <String, dynamic>{"x": 42});
      testJson('{"":42}', <String, dynamic>{"": 42});

      // JSON5 allows unquoted keys (not throwing like standard JSON does)
      testJson("{x:10}", <String, dynamic>{"x": 10});
      testJson("{true:10}", <String, dynamic>{"true": 10});
      testJson("{false:10}", <String, dynamic>{"false": 10});
      testJson("{null:10}", <String, dynamic>{"null": 10});
      testJson("{42:10}", <String, dynamic>{"42": 10});
      testJson("{:10}", <String, dynamic>{"": 10});
    });

    test("Arrays", () {
      testJson("[]", <dynamic>[]);
      testJson('[1.1e1,"string",true,false,null,{}]', <dynamic>[
        1.1e1,
        "string",
        true,
        false,
        null,
        <dynamic, dynamic>{},
      ]);
      testJson('[{},[{}],{"x":[]}]', <dynamic>[
        <dynamic, dynamic>{},
        <dynamic>[<dynamic, dynamic>{}],
        <String, dynamic>{"x": <dynamic>[]},
      ]);

      // JSON5 allows trailing commas
      testJson("[1,2,]", <dynamic>[1, 2]);

      testThrows("[,2]");
    });

    test("Words", () {
      testJson("true", true);
      testJson("false", false);
      testJson("null", null);

      // In json5_plus, these parse as unquoted strings rather than throwing
      testJson("truefalse", "truefalse");
      testJson("trues", "trues");
    });

    test("Whitespace", () {
      const String v = "\t\r\n ";
      testJson('$v[$v-2.2e2$v,$v{$v"key"$v:${v}true$v}$v,$v"ab"$v]$v', <dynamic>[
        -2.2e2,
        <String, dynamic>{"key": true},
        "ab",
      ]);
    });
  });

  group("Dart SDK json_lib_test.dart equivalents", () {
    test("Stringify values", () {
      // Validate round trips manually with stringifiers
      expect(Json5.fromMap(<String, dynamic>{"v": 5}).toJsonString(json5: false), '{"v":5}');
      expect(Json5.fromMap(<String, dynamic>{"v": -42}).toJsonString(json5: false), '{"v":-42}');
      expect(Json5.fromMap(<String, dynamic>{"v": true}).toJsonString(json5: false), '{"v":true}');
      expect(
        Json5.fromMap(<String, dynamic>{"v": false}).toJsonString(json5: false),
        '{"v":false}',
      );

      // json5_plus omits keys with null values
      expect(Json5.fromMap(<String, dynamic>{"v": null}).toJsonString(json5: false), "{}");
      expect(
        Json5.fromMap(<String, dynamic>{"v": ' hi there" bob '}).toJsonString(json5: false),
        r'{"v":" hi there\" bob "}',
      );
      expect(
        Json5.fromMap(<String, dynamic>{"v": r"hi\there"}).toJsonString(json5: false),
        r'{"v":"hi\\there"}',
      );
      expect(
        Json5.fromMap(<String, dynamic>{"v": "hi\nthere"}).toJsonString(json5: false),
        r'{"v":"hi\nthere"}',
      );
      expect(
        Json5.fromMap(<String, dynamic>{"v": "hi\r\nthere"}).toJsonString(json5: false),
        r'{"v":"hi\r\nthere"}',
      );
      expect(Json5.fromMap(<String, dynamic>{"v": ""}).toJsonString(json5: false), '{"v":""}');

      expect(
        Json5.fromMap(<String, dynamic>{"v": <dynamic>[]}).toJsonString(json5: false),
        '{"v":[]}',
      );
      expect(
        Json5.fromMap(<String, dynamic>{
          "v": <dynamic>[null, null, null],
        }).toJsonString(json5: false),
        '{"v":[null,null,null]}',
      );
      expect(
        Json5.fromMap(<String, dynamic>{
          "v": <dynamic>[
            <dynamic>[3],
            <dynamic>[],
            <dynamic>[null],
            <dynamic>["hi", true],
          ],
        }).toJsonString(json5: false),
        '{"v":[[3],[],[null],["hi",true]]}',
      );
    });
  });

  group("Dart SDK json_pretty_test.dart equivalents", () {
    test("Format Map with spaces", () {
      final Map<String, dynamic> map = <String, dynamic>{
        "hello": <dynamic>[],
        "goodbye": <dynamic, dynamic>{},
      };
      const String expectedValue = '''
{
  "hello": [],
  "goodbye": {}
}''';
      final Json5 json = Json5()..addAll(map);
      expect(json.toFormattedString(includeComments: false, json5: false), expectedValue);
    });

    test("Complex formatted output", () {
      final Map<String, dynamic> object = <String, dynamic>{
        "test": 1,
        "shanna": <dynamic>[0, 1, 2],
        "src": <dynamic>["foo.dart", "bar.dart"],
      };

      const String expectedValue = '''
{
  "test": 1,
  "shanna": [
    0,
    1,
    2
  ],
  "src": [
    "foo.dart",
    "bar.dart"
  ]
}''';

      final Json5 json = Json5.fromMap(object);
      expect(json.toFormattedString(includeComments: false, json5: false), expectedValue);
    });
  });
}
