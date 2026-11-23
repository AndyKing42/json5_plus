import 'dart:io';
import 'package:json5_plus/json5_plus.dart';
import 'package:test/test.dart';

enum _ETestKey { alpha, beta }

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
      final Json5 crlfJson = Json5.fromString('{ multiLineString: "line1\\\r\nline2" }');
      expect(crlfJson["multiLineString"], "line1\nline2");
    });

    test("Output of both JSON and JSON5 strings works correctly", () {
      final json = Json5();
      json["key"] = "value";
      json["number"] = 123;

      final String json5Out = json.toJsonString();
      expect(json5Out, '{key:"value",number:123}');

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
        '{"key": "unterminated string ', // Unterminated string
        '{"key": "value"} /* unterminated block', // Unterminated block comment
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

    test("Typed remove methods return converted value and delete key", () {
      final Json5 removeTestJson = Json5.fromString("""
      {
        boolVal: "true",
        intVal: "100",
        doubleVal: "3.14",
        stringVal: 50,
        dateStr: "2023-01-01T12:00:00.000Z"
      }
      """);

      expect(removeTestJson.removeBool("boolVal"), isTrue);
      expect(removeTestJson.containsKey("boolVal"), isFalse);

      expect(removeTestJson.removeInt("intVal"), 100);
      expect(removeTestJson.containsKey("intVal"), isFalse);

      expect(removeTestJson.removeDouble("doubleVal"), 3.14);
      expect(removeTestJson.containsKey("doubleVal"), isFalse);

      expect(removeTestJson.removeString("stringVal"), "50");
      expect(removeTestJson.containsKey("stringVal"), isFalse);

      expect(removeTestJson.removeDateTimeUtc("dateStr"), DateTime.utc(2023, 1, 1, 12));
      expect(removeTestJson.containsKey("dateStr"), isFalse);

      expect(removeTestJson.removeBool("missingKey", defaultValue: true), isTrue);
    });

    test("Collection remove methods return detached collection and delete key", () {
      final Json5 removeCollJson = Json5.fromString("""
      {
        intList: [1, 2, 3],
        stringSet: ["a", "b"],
        jsonList: [{ a: 1 }, { b: 2 }]
      }
      """);

      final List<int> removedInts = removeCollJson.removeIntList("intList");
      expect(removedInts, [1, 2, 3]);
      expect(removeCollJson.containsKey("intList"), isFalse);

      final Set<String> removedStrings = removeCollJson.removeStringSet("stringSet");
      expect(removedStrings, {"a", "b"});
      expect(removeCollJson.containsKey("stringSet"), isFalse);

      final List<Json5> removedJsons = removeCollJson.removeJsonList("jsonList");
      expect(removedJsons.length, 2);
      expect(removedJsons[0].asInt("a"), 1);
      expect(removeCollJson.containsKey("jsonList"), isFalse);

      // Verify returned list is detached (mutating it does not re-add key to JSON)
      removedInts.add(4);
      expect(removeCollJson.containsKey("intList"), isFalse);

      // Missing key returns empty detached collection
      expect(removeCollJson.removeStringList("missingKey"), isEmpty);
    });

    test("OrNull accessors and remove methods return null for missing keys", () {
      final Json5 testJson = Json5.fromString("""
      {
        boolVal: true,
        intVal: 42,
        stringVal: "hello",
        intList: [1, 2, 3]
      }
      """);

      // as...OrNull
      expect(testJson.asBoolOrNull("boolVal"), isTrue);
      expect(testJson.asBoolOrNull("missing"), isNull);

      expect(testJson.asIntOrNull("intVal"), 42);
      expect(testJson.asIntOrNull("missing"), isNull);

      expect(testJson.asStringOrNull("stringVal"), "hello");
      expect(testJson.asStringOrNull("missing"), isNull);

      expect(testJson.asIntListOrNull("intList"), [1, 2, 3]);
      expect(testJson.asIntListOrNull("missing"), isNull);

      // remove...OrNull
      expect(testJson.removeIntOrNull("intVal"), 42);
      expect(testJson.containsKey("intVal"), isFalse);
      expect(testJson.removeIntOrNull("intVal"), isNull);

      expect(testJson.removeIntListOrNull("intList"), [1, 2, 3]);
      expect(testJson.containsKey("intList"), isFalse);
      expect(testJson.removeIntListOrNull("intList"), isNull);
    });

    test("Date time accessors convert various formats correctly", () {
      final expectedDate = DateTime.utc(2023, 1, 1, 12);

      expect(json.asDateTime("dateStr").toUtc(), expectedDate);
      expect(json.asDateTime("dateObj").toUtc(), expectedDate);
      expect(json.asDateTime("dateNum").toUtc(), expectedDate);

      // UTC specific check
      expect(json.asDateTimeUtc("dateStr"), expectedDate);
      expect(json.asDateTimeUtc("dateObj"), expectedDate);
      expect(json.asDateTimeUtc("dateNum"), expectedDate);
      expect(json.asDateTimeUtc("missing", defaultValue: expectedDate), expectedDate);
      expect(json.asDateTimeUtcOrNull("dateNum"), expectedDate);
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

    test("Set accessors return sets with proper types and unique values", () {
      json["intDupList"] = [1, 2, 2, 3];
      json["stringDupList"] = ["a", "b", "a"];

      expect(json.asIntSet("intDupList"), {1, 2, 3});
      expect(json.asStringSet("stringDupList"), {"a", "b"});

      // Defaults to empty sets
      expect(json.asIntSet("missing"), isEmpty);
    });

    test("Collection accessors gracefully wrap single scalar values", () {
      expect(json.asIntList("intVal"), [42]);
      expect(json.asStringSet("stringVal"), {"hello"});

      // Verify the JSON object was updated to hold the wrapped collection
      expect(json.toJsonString(json5: false), contains('"intVal":[42]'));
    });

    test("Collection accessors return live ephemeral collections for missing keys", () {
      final localJson = Json5();

      final List<int> missingList = localJson.asIntList("ephemeralList");
      expect(localJson.isEmpty, isTrue);
      expect(localJson.keys.contains("ephemeralList"), isFalse);
      expect(localJson.toJsonString(), "{}");
      expect(localJson.toMap().containsKey("ephemeralList"), isFalse);

      missingList.add(100);

      expect(localJson.isEmpty, isFalse);
      expect(localJson.keys.contains("ephemeralList"), isTrue);
      expect(localJson.toJsonString(), '{ephemeralList:[100]}');
      expect(localJson.toMap().containsKey("ephemeralList"), isTrue);

      final Set<String> missingSet = localJson.asStringSet("ephemeralSet");
      expect(localJson.length, 1);
      missingSet.add("test");
      expect(localJson.length, 2);
      expect(localJson.asStringSet("ephemeralSet"), {"test"});
    });

    test("Json accessor returns nested object or empty Json5", () {
      final Json5 nested = json.asJson("obj");
      expect(nested.isNotEmpty, isTrue);
      expect(nested["inner"], "value");

      final Json5 missing = json.asJson("missing");
      expect(missing.isEmpty, isTrue);
    });

    test("joinStrings utility works correctly", () {
      final String joined = json.joinStrings(["stringVal", "intVal", "missing"], separator: "-");
      expect(joined, "hello-42"); // "missing" should be skipped because it defaults to ""
      json["blankVal"] = "   ";
      expect(
        json.joinStrings(["stringVal", "blankVal", "intVal"], separator: "-"),
        "hello-42",
      );
      expect(
        json.joinStrings(
          ["stringVal", "blankVal", "missing", "intVal"],
          includeBlankValues: true,
          separator: "-",
        ),
        "hello-   --42",
      );
    });
  });

  group("Json5 Additional Feature Tests", () {
    test("Multiple Document Parsing (decodeMultiple)", () {
      const jsonString = '{a: 1} {b: 2} trailing text';
      final ({List<Json5> jsonList, String unprocessed}) result = Json5.decodeMultiple(
        jsonString: jsonString,
      );
      expect(result.jsonList.length, 2);
      expect(result.jsonList[0]["a"], 1);
      expect(result.jsonList[1]["b"], 2);
      expect(result.unprocessed.trim(), "trailing text");
    });

    test("Case Sensitivity (caseSensitiveKeys)", () {
      final jsonInsensitive = Json5();
      jsonInsensitive["Key"] = "value";
      expect(jsonInsensitive["KEY"], "value");

      final jsonSensitive = Json5(caseSensitiveKeys: true);
      jsonSensitive["Key"] = "value";
      expect(jsonSensitive["KEY"], null);
      expect(jsonSensitive["Key"], "value");
    });

    test("Sorted Keys (sortedKeys)", () {
      final jsonUnsorted = Json5.fromString("{ zebra: 1, Apple: 2, banana: 3 }");
      expect(jsonUnsorted.keys.toList(), ["zebra", "Apple", "banana"]);

      final jsonSorted = Json5.fromString("{ zebra: 1, Apple: 2, banana: 3 }", sortedKeys: true);
      expect(jsonSorted.keys.toList(), ["Apple", "banana", "zebra"]);

      // Case-insensitive key lookup still works on sorted object
      expect(jsonSorted["APPLE"], 2);

      // Dynamically added keys are inserted in sorted order
      jsonSorted["cherry"] = 4;
      jsonSorted["aardvark"] = 5;
      expect(jsonSorted.keys.toList(), ["aardvark", "Apple", "banana", "cherry", "zebra"]);
    });

    test("Global Configuration (defaultSortedKeys & defaultJson5Format)", () {
      // Test defaultSortedKeys
      try {
        Json5.defaultUseSortedKeys = true;
        final jsonDefaultSorted = Json5.fromString("{ zebra: 1, apple: 2 }");
        expect(jsonDefaultSorted.keys.toList(), ["apple", "zebra"]);
      } finally {
        Json5.defaultUseSortedKeys = false;
      }

      // Test defaultJson5Format
      final testObj = Json5.fromString("{ name: 'Alice' }");
      expect(testObj.toJsonString(), '{name:"Alice"}'); // default is JSON5 (unquoted keys)

      try {
        Json5.defaultUseJson5ForToString = false;
        expect(testObj.toJsonString(), '{"name":"Alice"}'); // standard JSON (quoted keys)
        expect(testObj.toString(), '{"name":"Alice"}');
        // Explicit override still works when default is false
        expect(testObj.toJsonString(json5: true), '{name:"Alice"}');
      } finally {
        Json5.defaultUseJson5ForToString = true;
      }
    });

    test("String Escaping (Json5.escapeString)", () {
      expect(Json5.escapeString('hello "world"'), r'hello \"world\"');
      expect(Json5.escapeString("line1\nline2"), r"line1\nline2");
      expect(Json5.escapeString("tab\tseparated"), r"tab\tseparated");
      expect(Json5.escapeString(String.fromCharCode(7)), r"\u0007");
    });

    test("Allow Blank String (allowBlankString & defaultAllowBlankString)", () {
      // Default behavior (false): blank string throws FormatException
      expect(() => Json5.fromString(""), throwsA(isA<FormatException>()));
      expect(() => Json5.fromString("   "), throwsA(isA<FormatException>()));

      // Explicit per-call override (allowBlankString: true)
      final jsonBlank = Json5.fromString("", allowBlankString: true);
      expect(jsonBlank.isEmpty, isTrue);

      final jsonSpaces = Json5.fromString("   \n\t ", allowBlankString: true);
      expect(jsonSpaces.isEmpty, isTrue);

      // Global configuration static field override
      try {
        Json5.defaultAllowBlankString = true;
        final jsonGlobalBlank = Json5.fromString("");
        expect(jsonGlobalBlank.isEmpty, isTrue);
      } finally {
        Json5.defaultAllowBlankString = false;
      }
    });

    test("DateTime Format (EDateTimeFormat & defaultDateTimeFormat)", () {
      final dt = DateTime.utc(2026, 8, 12, 15, 48, 31);
      final jsonIso = Json5();
      jsonIso["time"] = dt;
      expect(jsonIso.toJsonString(), '{time:"2026-08-12T15:48:31Z"}');

      final jsonYyyy = Json5(dateTimeFormat: EDateTimeFormat.yyyymmddhhmmss);
      jsonYyyy["time"] = dt;
      expect(jsonYyyy.toJsonString(), '{time:"20260812154831"}');

      // Global default static field override
      try {
        Json5.defaultDateTimeFormat = EDateTimeFormat.yyyymmddhhmmss;
        final jsonGlobal = Json5();
        jsonGlobal["time"] = dt;
        expect(jsonGlobal.toJsonString(), '{time:"20260812154831"}');
      } finally {
        Json5.defaultDateTimeFormat = EDateTimeFormat.iso8601;
      }
    });

    test("Read-Only Mode (readOnly)", () {
      final json = Json5(readOnly: true);
      expect(() => json["key"] = "value", throwsA(isA<UnsupportedError>()));
      expect(() => Json5.emptyJson["key"] = "value", throwsA(isA<UnsupportedError>()));
      final Json5 parsedReadOnly = Json5.fromString(
        "{ a: 1, nested: { b: 2 }, list: [1, { c: 3 }] }",
        readOnly: true,
      );
      expect(parsedReadOnly["a"], 1);
      expect(() => parsedReadOnly["a"] = 2, throwsA(isA<UnsupportedError>()));
      expect(() => parsedReadOnly.asJson("nested")["b"] = 3, throwsA(isA<UnsupportedError>()));
      expect(() => (parsedReadOnly["list"] as List<dynamic>).add(9), throwsA(isA<UnsupportedError>()));
      final Json5 mapReadOnly = Json5.fromMap(
        {
          "nested": {"x": 1},
          "items": [
            {"y": 2},
          ],
        },
        readOnly: true,
      );
      expect(() => mapReadOnly.asJson("nested")["x"] = 2, throwsA(isA<UnsupportedError>()));
      expect(
        () => mapReadOnly.asJsonList("items").first["y"] = 3,
        throwsA(isA<UnsupportedError>()),
      );
      final Json5 copiedReadOnly = Json5.fromJson5(
        Json5.fromString("{ a: 1, nested: { b: 2 } }"),
        readOnly: true,
      );
      expect(() => copiedReadOnly["a"] = 2, throwsA(isA<UnsupportedError>()));
      expect(() => copiedReadOnly.asJson("nested")["b"] = 3, throwsA(isA<UnsupportedError>()));
    });

    test("Conditional Setters", () {
      final json = Json5();

      // setIfChanged
      final oldJson = Json5();
      oldJson["key"] = "oldValue";
      json.setIfChanged("key", oldJson, "newValue");
      expect(json["key"], "newValue");

      json.setIfChanged("key", oldJson, "oldValue"); // should not update
      expect(json["key"], "newValue");

      // setIfNotEqual
      json.setIfNotEqual("map", newValue: {"a": 1}, oldValue: {"a": 2});
      expect(json.asJson("map")["a"], 1);

      // setIfNewValueIsNotEmpty
      json.setIfNewValueIsNotEmpty("emptyStr", "");
      expect(json.containsKey("emptyStr"), isFalse);

      json.setIfNewValueIsNotEmpty("emptyList", <dynamic>[]);
      expect(json.containsKey("emptyList"), isFalse);

      json.setIfNewValueIsNotEmpty("validStr", "hello");
      expect(json["validStr"], "hello");

      // setIfNewValueIsNotNull
      json.setIfNewValueIsNotNull("nullKey", null);
      expect(json.containsKey("nullKey"), isFalse);

      json.setIfNewValueIsNotNull("validKey", 123);
      expect(json["validKey"], 123);
    });

    test("Alternative Factory Constructors", () {
      final json1 = Json5.fromKeyAndValueLists(keyList: ["a", "b"], valueList: [1, 2]);
      expect(json1["a"], 1);
      expect(json1["b"], 2);

      expect(
        () => Json5.fromKeyAndValueLists(keyList: ["a"], valueList: [1, 2]),
        throwsException, // Mismatched lengths
      );

      final json2 = Json5.fromKeyToIndexMapAndValueList(
        keyToIndexMap: {"a": 0, "b": 1},
        valueList: [1, 2],
      );
      expect(json2["a"], 1);
      expect(json2["b"], 2);

      // Json5.fromDiffs
      final jsonA = Json5.fromMap({"a": 1, "b": 2, "c": 3});
      final jsonB = Json5.fromMap({"a": 1, "b": 99, "d": 4});
      final diffJson = Json5.fromDiffs(jsonA, jsonB);

      expect(diffJson.containsKey("a"), isFalse); // matching value (1 == 1) omitted
      expect(diffJson["b"], 99); // modified value included
      expect(diffJson["d"], 4); // new key in json2 included
      expect(diffJson.containsKey("c"), isFalse); // key only in json1 omitted
    });

    test("Deep Copy Isolation (fromJson5 and setFromJson)", () {
      final original = Json5(caseSensitiveKeys: true);
      original["list"] = [1, 2];
      final nested = Json5();
      nested["a"] = 1;
      original["nested"] = nested;

      final copy = Json5.fromJson5(original);
      expect(copy.caseSensitiveKeys, isTrue); // verifies caseSensitiveKeys is inherited

      // Modify copy
      copy.asDynamicList("list").add(3);
      copy.asJson("nested")["a"] = 2;

      // Ensure original is unchanged
      expect(original.asDynamicList("list"), [1, 2]);
      expect(original.asJson("nested")["a"], 1);
    });

    test("File I/O (Json5.fromFile)", () {
      final file = File("test_temp.json5")..writeAsStringSync('{a: 1}');
      try {
        final json = Json5.fromFile("test_temp.json5");
        expect(json["a"], 1);
      } finally {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {} // Ignore file locking/deletion errors on Windows
      }
    });

    test("File I/O (Json5.toFile)", () {
      final file = File("test_temp_out.json5");
      try {
        Json5()
          ..set("outKey", 123)
          ..toFile("test_temp_out.json5");

        expect(file.existsSync(), isTrue);
        final String content = file.readAsStringSync();
        expect(content, contains("outKey: 123"));
      } finally {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
    });

    test(r"$include and parameter substitution works", () {
      final file = File("test_include.json5")
        ..writeAsStringSync(r'''
{
  // Nested comment
  logPath: "${params.logDir}/${params.logPrefix}_app.log",
  level: "${params.logLevel}",
  nestedTest: "${params.nested.target}",
  missingTest: "${params.missingValue}",
}
''');
      try {
        const includeJson5String = r'''
{
  appName: "MyApp",
  // Pick up the log settings:
  logSettings: $include("test_include.json5", {
    logDir: "/var/logs", 
    logLevel: "info", 
    logPrefix: "MyApp",
    nested: {target: "success"}
  }),
}
''';
        final json = Json5.fromString(includeJson5String);

        final Json5 logSettings = json.asJson("logSettings");
        expect(logSettings["logPath"], "/var/logs/MyApp_app.log");
        expect(logSettings["level"], "info");
        expect(logSettings["nestedTest"], "success");
        expect(logSettings["missingTest"], r"${params.missingValue}");

        final String formatted = json.toFormattedString();

        // Assert the order of the multi-line injected comments
        final int pickUpIndex = formatted.indexOf("// Pick up the log settings:");
        final int includeIndex = formatted.indexOf(
          r'// logSettings: $include("test_include.json5"',
        );
        final int logSettingsIndex = formatted.indexOf("logSettings: {");

        expect(pickUpIndex != -1, isTrue);
        expect(includeIndex != -1, isTrue);
        expect(logSettingsIndex != -1, isTrue);
        expect(pickUpIndex < includeIndex, isTrue);
        expect(includeIndex < logSettingsIndex, isTrue);
      } finally {
        try {
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
    });

    test("Quoted and escaped characters in keys (JSON and JSON5 modes)", () {
      final json = Json5();
      json['key"with"quotes'] = 1;
      json[r"key\with\backslashes"] = 2;
      json["key\nwith\nnewlines"] = 3;
      json["key\twith\ttabs"] = 4;
      json["key with spaces"] = 5;
      json["key:with:colons"] = 6;
      json["valid_identifier_123"] = 7;
      json[r"$dollar_key"] = 8;
      json["_underscore_key"] = 9;
      json["123_starts_with_digit"] = 10;

      // 1. Test JSON mode serialization
      final String jsonOut = json.toJsonString(json5: false);
      expect(jsonOut, contains(r'"key\"with\"quotes":1'));
      expect(jsonOut, contains(r'"key\\with\\backslashes":2'));
      expect(jsonOut, contains(r'"key\nwith\nnewlines":3'));
      expect(jsonOut, contains(r'"key\twith\ttabs":4'));
      expect(jsonOut, contains('"key with spaces":5'));
      expect(jsonOut, contains('"key:with:colons":6'));
      expect(jsonOut, contains('"valid_identifier_123":7'));
      expect(jsonOut, contains(r'"$dollar_key":8'));
      expect(jsonOut, contains('"_underscore_key":9'));
      expect(jsonOut, contains('"123_starts_with_digit":10'));

      // Re-parse from JSON output and verify values match
      final reparsedFromJson = Json5.fromString(jsonOut);
      expect(reparsedFromJson['key"with"quotes'], 1);
      expect(reparsedFromJson[r"key\with\backslashes"], 2);
      expect(reparsedFromJson["key\nwith\nnewlines"], 3);
      expect(reparsedFromJson["key\twith\ttabs"], 4);
      expect(reparsedFromJson["key with spaces"], 5);
      expect(reparsedFromJson["key:with:colons"], 6);
      expect(reparsedFromJson["valid_identifier_123"], 7);
      expect(reparsedFromJson[r"$dollar_key"], 8);
      expect(reparsedFromJson["_underscore_key"], 9);
      expect(reparsedFromJson["123_starts_with_digit"], 10);

      // 2. Test JSON5 mode serialization (identifiers unquoted, non-identifiers quoted & escaped)
      final String json5Out = json.toJsonString();
      expect(json5Out, contains(r'"key\"with\"quotes":1'));
      expect(json5Out, contains(r'"key\\with\\backslashes":2'));
      expect(json5Out, contains(r'"key\nwith\nnewlines":3'));
      expect(json5Out, contains(r'"key\twith\ttabs":4'));
      expect(json5Out, contains('"key with spaces":5'));
      expect(json5Out, contains('"key:with:colons":6'));
      expect(json5Out, contains("valid_identifier_123:7"));
      expect(json5Out, contains(r"$dollar_key:8"));
      expect(json5Out, contains("_underscore_key:9"));
      expect(json5Out, contains('"123_starts_with_digit":10'));

      // Re-parse from JSON5 output and verify round-trip
      final reparsedFromJson5 = Json5.fromString(json5Out);
      expect(reparsedFromJson5['key"with"quotes'], 1);
      expect(reparsedFromJson5[r"key\with\backslashes"], 2);
      expect(reparsedFromJson5["key\nwith\nnewlines"], 3);
      expect(reparsedFromJson5["key\twith\ttabs"], 4);
      expect(reparsedFromJson5["key with spaces"], 5);
      expect(reparsedFromJson5["key:with:colons"], 6);
      expect(reparsedFromJson5["valid_identifier_123"], 7);
      expect(reparsedFromJson5[r"$dollar_key"], 8);
      expect(reparsedFromJson5["_underscore_key"], 9);
      expect(reparsedFromJson5["123_starts_with_digit"], 10);

      // 3. Test pretty-printed formatted output round-trip
      final String prettyJson5 = json.toFormattedString();
      final reparsedFromPrettyJson5 = Json5.fromString(prettyJson5);
      expect(reparsedFromPrettyJson5['key"with"quotes'], 1);
      expect(reparsedFromPrettyJson5[r"key\with\backslashes"], 2);
      expect(reparsedFromPrettyJson5["key\nwith\nnewlines"], 3);

      final String prettyJson = json.toFormattedString(json5: false);
      final reparsedFromPrettyJson = Json5.fromString(prettyJson);
      expect(reparsedFromPrettyJson['key"with"quotes'], 1);
      expect(reparsedFromPrettyJson[r"key\with\backslashes"], 2);
      expect(reparsedFromPrettyJson["key\nwith\nnewlines"], 3);
    });

    test("Parser decodes extended escape sequences in keys", () {
      const String input = r"""
      {
        'single\'quote\'key': 1,
        "vertical\vtab\vkey": 2,
        "null\0char\0key": 3,
        "hex\x41\x42key": 4,
        "unicode\u0043\u0044key": 5,
      }
      """;
      final json = Json5.fromString(input);
      expect(json["single'quote'key"], 1);
      expect(json["vertical\x0btab\x0bkey"], 2);
      expect(json["null\x00char\x00key"], 3);
      expect(json["hexABkey"], 4);
      expect(json["unicodeCDkey"], 5);
    });

    test("Parser rejects stray slash without hanging", () {
      expect(() => Json5.fromString("{ a: 1 / }"), throwsA(isA<FormatException>()));
      expect(() => Json5.fromString("/ { a: 1 }"), throwsA(isA<FormatException>()));
    });

    test("decodeMultiple preserves partial trailing object in unprocessed", () {
      const String input = "{a: 1} {b: 2";
      final ({List<Json5> jsonList, String unprocessed}) result = Json5.decodeMultiple(
        jsonString: input,
      );
      expect(result.jsonList.length, 1);
      expect(result.jsonList[0]["a"], 1);
      expect(result.unprocessed.trim(), "{b: 2");
    });

    test("Ephemeral keys respect case-insensitivity and do not leak", () {
      final Json5 localJson = Json5();
      final List<int> missingList = localJson.asIntList("myList");
      expect(localJson.containsKey("MYLIST"), isFalse);
      expect(localJson.isNull("MYLIST"), isTrue);
      expect(localJson.isNotNull("MYLIST"), isFalse);
      expect(localJson["MYLIST"], isNull);
      expect(localJson.asIntListOrNull("MYLIST"), isNull);
      missingList.add(7);
      expect(localJson.containsKey("MYLIST"), isTrue);
      expect(localJson.asIntListOrNull("MYLIST"), [7]);
      localJson.set("MYLIST", [9]);
      expect(localJson.asIntList("myList"), [9]);
      localJson.asIntList("myList").clear();
      expect(localJson.containsKey("myList"), isTrue);
    });

    test("set converts nested Maps inside Iterables to Json5", () {
      final Json5 localJson = Json5()
        ..set("items", [
          {"a": 1},
          {"b": 2},
        ]);
      final List<Json5> itemList = localJson.asJsonList("items");
      expect(itemList.length, 2);
      expect(itemList[0]["a"], 1);
      expect(itemList[1]["b"], 2);
      expect(localJson.toJsonString(), "{items:[{a:1},{b:2}]}");
      localJson.set("constItems", const [
        {"c": 3},
      ]);
      expect(localJson.asJsonList("constItems").first["c"], 3);
    });

    test("Enum keys and values serialize and lookup accurately", () {
      final Json5 localJson = Json5()..set(_ETestKey.alpha, _ETestKey.beta);
      expect(localJson[_ETestKey.alpha], _ETestKey.beta);
      expect(localJson["alpha"], _ETestKey.beta);
      expect(localJson.toJsonString(), '{alpha:"beta"}');
    });

    test("Parser supports uppercase 0X hex and rejects invalid hex signs", () {
      final Json5 hexJson = Json5.fromString("{ a: 0X1A, b: -0X10, c: +0X0F }");
      expect(hexJson["a"], 26);
      expect(hexJson["b"], -16);
      expect(hexJson["c"], 15);
      expect(() => Json5.fromString("{ bad: 0x-1 }"), throwsA(isA<FormatException>()));
      expect(() => Json5.fromString("{ bad: 0X+1 }"), throwsA(isA<FormatException>()));
    });

    test("Parser matches IEEE-754 double precision for floating-point values", () {
      final Json5 floatJson = Json5.fromString(
        "{ a: 1.23456789012345, b: 0.0000001, c: .5, d: 5., e: -0.3 }",
      );
      expect(floatJson["a"], double.parse("1.23456789012345"));
      expect(floatJson["b"], double.parse("0.0000001"));
      expect(floatJson["c"], 0.5);
      expect(floatJson["d"], 5.0);
      expect(floatJson["e"], -0.3);
    });

    test("Parser handles UTF-8 BOM and NBSP as whitespace", () {
      final Json5 bomJson = Json5.fromString("\uFEFF{ \u00A0key: \u00A042\u00A0 }\uFEFF");
      expect(bomJson["key"], 42);
    });

    test("Standalone params placeholder preserves native types", () {
      final Json5 templated = Json5.fromString(
        r'''
        {
          port: "${params.port}",
          enabled: "${params.enabled}",
          nested: "${params.nested}",
          listWithObj: ["${params.nested}"],
          interpolated: "http://localhost:${params.port}",
        }
        ''',
        params: {
          "port": 8080,
          "enabled": true,
          "nested": {"host": "127.0.0.1"},
        },
      );
      expect(templated["port"], 8080);
      expect(templated["enabled"], isTrue);
      expect(templated.asJson("nested")["host"], "127.0.0.1");
      expect(templated.asJsonList("listWithObj").first["host"], "127.0.0.1");
      expect(templated["interpolated"], "http://localhost:8080");
    });

    test("Strict JSON mode serializes non-finite doubles as null", () {
      final Json5 numJson = Json5()
        ..set("nan", double.nan)
        ..set("inf", double.infinity)
        ..set("negInf", double.negativeInfinity)
        ..set("arr", [double.nan, 1.5]);
      expect(numJson.toJsonString(), "{nan:NaN,inf:Infinity,negInf:-Infinity,arr:[NaN,1.5]}");
      expect(
        numJson.toJsonString(json5: false),
        '{"nan":null,"inf":null,"negInf":null,"arr":[null,1.5]}',
      );
      expect(
        numJson.toFormattedString(json5: false, includeComments: false),
        contains('"nan": null'),
      );
    });

    test(r"$include resolves relative to parent file, forwards options, and detects cycles", () {
      final Directory tempDir = Directory.systemTemp.createTempSync("json5_include_test_");
      try {
        final Directory subDir = Directory("${tempDir.path}/sub")..createSync();
        File("${subDir.path}/leaf.json5").writeAsStringSync("{ z: 1, a: 2 }");
        File("${tempDir.path}/main.json5").writeAsStringSync(
          r'{ included: $include("sub/leaf.json5"), local: true }',
        );
        final Json5 loaded = Json5.fromFile(
          "${tempDir.path}/main.json5",
          readOnly: true,
          sortedKeys: true,
        );
        expect(loaded.keys.toList(), ["included", "local"]);
        expect(loaded.asJson("included").keys.toList(), ["a", "z"]);
        expect(() => loaded.asJson("included")["a"] = 99, throwsA(isA<UnsupportedError>()));

        File("${tempDir.path}/cycA.json5").writeAsStringSync(r'{ b: $include("cycB.json5") }');
        File("${tempDir.path}/cycB.json5").writeAsStringSync(r'{ a: $include("cycA.json5") }');
        expect(
          () => Json5.fromFile("${tempDir.path}/cycA.json5"),
          throwsA(isA<FormatException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test("Deep equality in deepEquals, fromDiffs, and setIfChanged", () {
      final Json5 a = Json5.fromString("{ nested: { x: 1, list: [1, 2] }, same: 'ok' }");
      final Json5 b = Json5.fromString("{ nested: { x: 1, list: [1, 2] }, same: 'ok' }");
      expect(a.deepEquals(b), isTrue);
      expect(Json5.fromDiffs(a, b).isEmpty, isTrue);

      final Json5 target = Json5()
        ..setIfChanged("nested", a, Json5.fromString("{ x: 1, list: [1, 2] }"));
      expect(target.containsKey("nested"), isFalse);

      b.asJson("nested")["x"] = 2;
      expect(a.deepEquals(b), isFalse);
      final Json5 diffs = Json5.fromDiffs(a, b);
      expect(diffs.containsKey("nested"), isTrue);
      expect(diffs.containsKey("same"), isFalse);
    });

    test("Key-bound comments stay attached when sortedKeys reorders properties", () {
      const String input = """
{
  // comment for zebra
  zebra: 1, // inline zebra
  // comment for apple
  apple: 2,
}
""";
      final Json5 sorted = Json5.fromString(input, sortedKeys: true);
      final String formatted = sorted.toFormattedString();
      final int appleCommentIndex = formatted.indexOf("// comment for apple");
      final int appleKeyIndex = formatted.indexOf("apple: 2");
      final int zebraCommentIndex = formatted.indexOf("// comment for zebra");
      final int zebraKeyIndex = formatted.indexOf("zebra: 1, // inline zebra");
      expect(appleCommentIndex != -1, isTrue);
      expect(appleCommentIndex < appleKeyIndex, isTrue);
      expect(appleKeyIndex < zebraCommentIndex, isTrue);
      expect(zebraCommentIndex < zebraKeyIndex, isTrue);

      final Json5 cloned = Json5.fromJson5(sorted);
      expect(cloned.toFormattedString(), formatted);
    });
  });
}
