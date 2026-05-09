import "package:json5_plus/json5_plus.dart";
import "package:test/test.dart";

void main() {
  group("Json5 Parser and Stringifier Black-Box Tests", () {
    test("Standard JSON works correctly", () {
      const jsonString = '{"key": "value", "list": [1, 2, 3], "obj": {"nested": true}}';
      final json = Json5.fromString(jsonString);

      expect(json["key"], "value");
      expect(json.asDynamicList("list"), [1, 2, 3]);
      expect(json.asJson("obj")["nested"], true);

      // Verify strict JSON output
      expect(
        json.toJsonString(json5: false),
        '{"key":"value","list":[1,2,3],"obj":{"nested":true}}',
      );
    });

    test("Full JSON5 features work in the parser", () {
      const json5String = r"""
        {
          // single line comment
          unquotedKey: "single quoted string",
          /* multi-line
             comment */
          trailingCommaObj: { a: 1, },
          trailingCommaArr: [1, 2,],
          hexNumber: 0x1A,
          positiveSign: +5,
          negativeSign: -5,
          leadingDecimal: .5,
          trailingDecimal: 5.,
          multiLineString: "line1\
line2",
        }
      """;

      final json = Json5.fromString(json5String);

      expect(json["unquotedKey"], "single quoted string");
      expect(json.asJson("trailingCommaObj")["a"], 1);
      expect(json.asDynamicList("trailingCommaArr"), [1, 2]);
      expect(json["hexNumber"], 26);
      expect(json["positiveSign"], 5);
      expect(json["negativeSign"], -5);
      expect(json["leadingDecimal"], 0.5);
      expect(json["trailingDecimal"], 5.0);
      expect(json["multiLineString"], "line1\nline2");
    });

    test("Output of both JSON and JSON5 strings works correctly", () {
      final json = Json5();
      json["key"] = "value";
      json["number"] = 123;

      final String json5Out = json.toJsonString();
      expect(json5Out, '{key:"value",number:123,}');

      final String jsonOut = json.toJsonString(json5: false);
      expect(jsonOut, '{"key":"value","number":123}');
    });

    test("Pretty-printed output works correctly", () {
      final json = Json5();
      json["key"] = "value";
      final nested = Json5();
      nested["nestedKey"] = 1;
      json["obj"] = nested;
      json["arr"] = [1, 2];

      final String prettyJson5 = json.toFormattedString(includeComments: false);
      expect(prettyJson5, """
{
  key: "value",
  obj: {
    nestedKey: 1,
  },
  arr: [
    1,
    2,
  ],
}""");

      final String prettyJson = json.toFormattedString(json5: false, includeComments: false);
      expect(prettyJson, """
{
  "key": "value",
  "obj": {
    "nestedKey": 1
  },
  "arr": [
    1,
    2
  ]
}""");
    });

    test("Comments in JSON5 are handled correctly during pretty-printing", () {
      const json5String = """
{
  // comment before key
  key1: "value1",
  key2: /* comment after colon */ "value2",
  key3: "value3", // comment after comma
}
""";

      final json = Json5.fromString(json5String);
      final String prettyJson5 = json.toFormattedString();

      // Verify that comments are retained in the formatted output
      expect(prettyJson5, contains("// comment before key"));
      expect(prettyJson5, contains("/* comment after colon */"));
      expect(prettyJson5, contains("// comment after comma"));

      // Re-parse to ensure the output is still valid JSON5
      final reparsed = Json5.fromString(prettyJson5);
      expect(reparsed["key1"], "value1");
      expect(reparsed["key2"], "value2");
      expect(reparsed["key3"], "value3");
    });

    test("Parser throws FormatException for invalid JSON", () {
      final List<String> invalidCases = [
        "{", // Unclosed object
        '{"key": "value"', // Unclosed object with content
        '{"key": }', // Missing value
        '{"key": "value" ]', // Mismatched braces/brackets
        '["value1", "value2"', // Unclosed array
        r'{"keyr": \"value"}', // Invalid escape or token
        "{key: unquoted value}", // Invalid token containing spaces
      ];

      for (final invalidCase in invalidCases) {
        expect(
          () => Json5.fromString(invalidCase),
          throwsA(isA<FormatException>()),
          reason: "Expected FormatException for: $invalidCase",
        );
      }
    });
  });

  group("Json5 Accessor Tests", () {
    late Json5 json;

    setUp(() {
      json = Json5();
      json["boolTrue"] = true;
      json["boolFalse"] = false;
      json["boolStr"] = "true";
      json["intVal"] = 42;
      json["intStr"] = "42";
      json["doubleVal"] = 3.14;
      json["doubleStr"] = "3.14";
      json["stringVal"] = "hello";
      json["dateStr"] = "2023-01-01T12:00:00Z";

      // Use DateTime for object setting
      final dt = DateTime.utc(2023, 1, 1, 12);
      json["dateObj"] = dt;
      json["dateNum"] = dt.millisecondsSinceEpoch;

      final nested = Json5();
      nested["inner"] = "value";
      json["obj"] = nested;

      json["intList"] = [1, 2, 3];
      json["doubleList"] = [1.1, 2.2];
      json["stringList"] = ["a", "b"];
      json["dynamicList"] = [1, "two", true];
      json["jsonList"] = [nested];
    });

    test("Primitive accessors cast and fallback correctly", () {
      // Booleans
      expect(json.asBool("boolTrue"), isTrue);
      expect(json.asBool("boolFalse"), isFalse);
      expect(json.asBool("boolStr"), isTrue);
      expect(json.asBool("intVal"), isTrue); // non-zero num is true
      expect(json.asBool("missing", defaultValue: true), isTrue);

      // Integers
      expect(json.asInt("intVal"), 42);
      expect(json.asInt("intStr"), 42);
      expect(json.asInt("doubleVal"), 3); // 3.14.toInt()
      expect(json.asInt("missing", defaultValue: 99), 99);

      // Doubles
      expect(json.asDouble("doubleVal"), 3.14);
      expect(json.asDouble("doubleStr"), 3.14);
      expect(json.asDouble("intVal"), 42.0);
      expect(json.asDouble("missing", defaultValue: 1.5), 1.5);

      // Strings
      expect(json.asString("stringVal"), "hello");
      expect(json.asString("intVal"), "42");
      expect(json.asString("boolTrue"), "true");
      expect(json.asString("missing", defaultValue: "default"), "default");
    });

    test("Date time accessors convert various formats correctly", () {
      final expectedDate = DateTime.utc(2023, 1, 1, 12);

      expect(json.asDateTime("dateStr").toUtc(), expectedDate);
      expect(json.asDateTime("dateObj").toUtc(), expectedDate);
      expect(json.asDateTime("dateNum").toUtc(), expectedDate);

      // UTC specific check
      expect(json.asDateTimeUtc("dateStr"), expectedDate);
    });

    test("Presence and null checks evaluate correctly", () {
      expect(json.containsKey("intVal"), isTrue);
      expect(json.containsKey("missing"), isFalse);

      expect(json.isNotNull("intVal"), isTrue);
      expect(json.isNotNull("missing"), isFalse);

      expect(json.isNull("intVal"), isFalse);
      expect(json.isNull("missing"), isTrue);
    });

    test("List accessors return lists with proper types", () {
      expect(json.asIntList("intList"), [1, 2, 3]);
      expect(json.asDoubleList("doubleList"), [1.1, 2.2]);
      expect(json.asStringList("stringList"), ["a", "b"]);
      expect(json.asDynamicList("dynamicList"), [1, "two", true]);

      final List<Json5> jsonList = json.asJsonList("jsonList");
      expect(jsonList.length, 1);
      expect(jsonList.first["inner"], "value");

      // Defaults to empty lists
      expect(json.asIntList("missing"), isEmpty);
    });

    test("Json accessor returns nested object or empty Json5", () {
      final Json5 nested = json.asJson("obj");
      expect(nested.isNotEmpty, isTrue);
      expect(nested["inner"], "value");

      final Json5 missing = json.asJson("missing");
      expect(missing.isEmpty, isTrue);
    });

    test("joinStrings utility works correctly", () {
      final String joined = json.joinStrings(["stringVal", "intVal", "missing"], "-");
      expect(joined, "hello-42"); // "missing" should be skipped because it defaults to ""
    });
  });
}
