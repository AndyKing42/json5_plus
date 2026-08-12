import 'dart:io';
import 'package:json5_plus/json5_plus.dart';
import 'package:test/test.dart';

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
      expect(() => json["key"] = "value", throwsA(isA<AssertionError>()));
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
      final original = Json5();
      original["list"] = [1, 2];
      final nested = Json5();
      nested["a"] = 1;
      original["nested"] = nested;

      final copy = Json5.fromJson5(original);

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
  });
}
