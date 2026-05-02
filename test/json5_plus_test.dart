import 'package:json5_plus/json5_plus.dart';
import 'package:test/test.dart';

void main() {
  group("Json5 Parsing and Core functionality", () {
    test("Basic JSON parsing", () {
      final json = Json5(jsonString: '{"name": "test", "value": 42}');
      expect(json["name"], "test");
      expect(json["value"], 42);
    });

    test("JSON5 specific features (unquoted keys, trailing commas)", () {
      const json5Str = '''
        {
          name: "test",
          value: 42,
          list: [1, 2, 3,],
        }
      ''';
      final json = Json5(jsonString: json5Str);
      expect(json["name"], "test");
      expect(json["value"], 42);
      expect(json["list"], equals([1, 2, 3]));
    });

    test("Case-insensitive keys (using caseSensitiveKeys: false)", () {
      final json = Json5(jsonString: '{"MyKey": "TestValue"}', caseSensitiveKeys: false);
      expect(json["mykey"], "TestValue");
      expect(json["MYKEY"], "TestValue");
    });

    test("Comments in JSON5", () {
      const json5Str = '''
        {
          // Single line comment
          name: "test", /* Multi-line comment */
          value: 42
        }
      ''';
      final json = Json5(jsonString: json5Str);
      expect(json["name"], "test");
      expect(json["value"], 42);
    });

    test("Json5 hex, NaN, Infinity", () {
      const jsonString =
          '{ "hex": 0x1A, "nan": NaN, "inf": Infinity, "negInf": -Infinity, "posInf": +Infinity }';
      final json = Json5(jsonString: jsonString);
      expect(json["hex"], 26);
      expect((json["nan"] as num).isNaN, isTrue);
      expect(json["inf"], double.infinity);
      expect(json["negInf"], double.negativeInfinity);
      expect(json["posInf"], double.infinity);
    });

    test("Json5 escaped string characters", () {
      const jsonString = r'{"esc": "line\nbreak\"quoted\"\\"}';
      final json = Json5(jsonString: jsonString);
      expect(json["esc"], 'line\nbreak"quoted"\\');
    });

    test("Lists and typed accessors", () {
      const jsonString =
          '{ "doubles": [1, 2.5, "3.14"], "ints": [1, "2", 3.0], "strings": ["a", 2, true], "jsons": [{"a": 1}, {"b": 2}] }';
      final json = Json5(jsonString: jsonString);

      expect(json.asDoubleList("doubles"), [1.0, 2.5, 3.14]);
      expect(json.asIntList("ints"), [1, 2, 3]);
      expect(json.asStringList("strings"), ["a", "2", "true"]);

      final List<Json5> jsonsList = json.asJsonList("jsons");
      expect(jsonsList.length, 2);
      expect(jsonsList[0]["a"], 1);
      expect(jsonsList[1]["b"], 2);
    });

    test("Singular typed accessors (Json5Accessor)", () {
      final json = Json5(
        map: {
          "boolKey": "true",
          "intKey": 42.0,
          "doubleKey": "3.14",
          "dateKey": "2026-05-01T12:00:00",
          "strKey": 123,
        },
      );

      expect(json.asBool("boolKey"), isTrue);
      expect(json.asInt("intKey"), 42);
      expect(json.asDouble("doubleKey"), 3.14);
      expect(json.asDateTime("dateKey").year, 2026);
      expect(json.asDateTimeUtc("dateKey").isUtc, isTrue);
      expect(json.asString("strKey"), "123");

      expect(json.containsKey("intKey"), isTrue);
      expect(json.isNotNull("intKey"), isTrue);
      expect(json.isNull("missingKey"), isTrue);

      expect(json.joinStrings(["boolKey", "strKey"], "-"), "true-123");
    });

    test("Json5.decode", () {
      dynamic result = Json5.decode('{"a": 1}');
      expect(result, isA<Map<dynamic, dynamic>>());
      expect((result as Map)["a"], 1);
    });

    test("loadMultiple functionality", () {
      const jsons = '{"a": 1} {"b": 2} remaining_text';
      final ({List<Json5> jsonList, String unprocessed}) result = Json5.loadMultiple(jsons: jsons);
      expect(result.jsonList.length, 2);
      expect(result.jsonList[0]["a"], 1);
      expect(result.jsonList[1]["b"], 2);
      expect(result.unprocessed.trim(), "remaining_text");
    });

    test("Json5.fromDiffs", () {
      final json1 = Json5(map: {"a": 1, "b": 2});
      final json2 = Json5(map: {"a": 1, "b": 3, "c": 4});
      final diff = Json5.fromDiffs(json1, json2);

      expect(diff.keyToValueMap.containsKey("a"), isFalse);
      expect(diff["b"], 3);
      expect(diff["c"], 4);
    });
  });

  group("Json5 Mutation and Utility Methods", () {
    test("escapeString", () {
      final String escaped = Json5.escapeString('test\n"quotes"\\');
      expect(escaped.contains(r"\n"), isTrue);
      expect(escaped.contains(r'\"'), isTrue);
      expect(escaped.contains(r"\\"), isTrue);
    });

    test("toFormattedString and toString", () {
      final json = Json5(
        map: {
          "a": 1,
          "b": {"c": 2},
        },
      );
      final String formatted = json.toFormattedString();
      expect(formatted.contains("{\n"), isTrue);

      final str = json.toString();
      expect(str.startsWith("{"), isTrue);
      expect(str.contains("1"), isTrue);
    });

    test("operator []= and addAll", () {
      final json = Json5();
      json["key1"] = "val1";
      expect(json["key1"], "val1");

      json.addAll({"key2": "val2", "key3": 3});
      expect(json["key2"], "val2");
      expect(json["key3"], 3);
    });

    test("Mutation set methods (set, setFromJson, setFromMap)", () {
      final json = Json5()..set("a", 1);
      expect(json["a"], 1);

      json.setFromJson(Json5(map: {"b": 2}));
      expect(json["b"], 2);

      json.setFromMap({"c": 3});
      expect(json["c"], 3);

      final oldJson = Json5(map: {"old": 99});
      json.setIfChanged("old", oldJson, 100);
      expect(json["old"], 100);
    });

    test("setFromkeyAndValueLists formats", () {
      final json = Json5()..setFromkeyAndValueLists(["k1", "k2"], [1, 2]);
      expect(json["k1"], 1);
      expect(json["k2"], 2);

      json.setFromkeyToIndexAndValueList({"k3": 0, "k4": 1}, [3, 4]);
      expect(json["k3"], 3);
      expect(json["k4"], 4);
    });
  });

  group("Json5 String and DateTime Extensions", () {
    test("String toBool", () {
      expect("true".toBool(), isTrue);
      expect("Y".toBool(), isTrue);
      expect("1".toBool(), isTrue);
      expect("false".toBool(), isFalse);
      expect("no".toBool(), isFalse);
    });

    test("String isBlank and isNotBlank", () {
      expect("".isBlank, isTrue);
      expect("   ".isBlank, isTrue);
      expect("test".isBlank, isFalse);
      expect("test".isNotBlank, isTrue);
    });

    test("String toDouble and toInt", () {
      expect("3.14".toDouble(), 3.14);
      expect("error".toDouble(9.9), 9.9);
      expect("42".toInt(), 42);
      expect("error".toInt(99), 99);
    });

    test("String toDateTime and DateTime formatIso8601", () {
      // 2026-05-01 12:30:00
      final DateTime? dt = "2026-05-01T12:30:00".toDateTime();
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 5);

      final DateTime? dtUtc = "20260501123000".toDateTimeUtc(); // yyyymmddhhmmss
      expect(dtUtc, isNotNull);
      expect(dtUtc!.month, 5);
      expect(dtUtc.hour, 12);
      expect(dtUtc.isUtc, isTrue);

      final String formatted = dtUtc.formatIso8601();
      expect(formatted, "2026-05-01T12:30:00Z");
    });

    test("String compareToIgnoreCase", () {
      expect("Apple".compareToIgnoreCase("apple"), 0);
      expect("Apple".compareToIgnoreCase("Banana") < 0, isTrue);
    });
  });
}
