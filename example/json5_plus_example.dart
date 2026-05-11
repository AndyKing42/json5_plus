//
// ignore_for_file: avoid_print

import 'package:json5_plus/json5_plus.dart';

enum EConfigKeys { host, port }

void main() {
  print('=== json5_plus Example ===\n');
  const json5String = '''
  {
    // A comment explaining the purpose of this object
    unquotedKey: "value",
    number: 42,
    boolean: true,
    list: [
      1,
      2, // trailing comma in array
    ],
  }
  ''';
  print('--- 1. Parsing JSON5 ---');
  final json = Json5.fromString(json5String);
  print('Parsed unquotedKey: ${json['unquotedKey']}');
  print('Parsed number (as int): ${json.asInt('number')}');
  print('Parsed list: ${json.asIntList('list')}');
  // 2. Modifying the JSON object
  print('\n--- 2. Modifying JSON5 ---');
  json['newKey'] = 'newValue';
  json['number'] = 43; // Update existing
  print('Added "newKey" and updated "number".');
  // 3. Nested objects
  print('\n--- 3. Nested Objects ---');
  final nestedJson = Json5();
  nestedJson['nestedString'] = 'nestedValue';
  nestedJson['nestedNumber'] = 100;
  json['nestedObject'] = nestedJson;
  print('Added a nested object.');
  // 4. Outputting the result
  print('\n--- 4. Output Formatting ---');
  // Format back to a pretty JSON5 string (default)
  print('Formatted JSON5:');
  print(json.toFormattedString());
  // Or format as strict JSON
  print('\nStrict JSON:');
  print(json.toJsonString(json5: false));
  // 5. Includes and Parameters
  print("\n--- 5. Includes and Parameter Substitution ---");
  const String includeJson5String = r'''
  {
    appName: "MyApp",
    // Pick up the log settings:
    logSettings: $include("log_settings.json5", {logDir: "/var/logs", logLevel: "info", logPrefix: "MyApp",}),
  }
  ''';
  try {
    final Json5 configWithInclude = Json5.fromString(includeJson5String);
    print(
      'Parsed included logPath: ${configWithInclude.asJson("logSettings").asString("logPath")}',
    );
    print('Parsed included level: ${configWithInclude.asJson("logSettings").asString("level")}');
    print('\nFormatted config with includes:');
    print(configWithInclude.toFormattedString());
  } catch (e) {
    print(
      "Note: Ensure your working directory is the package root to run the include example.\n$e",
    );
  }

  // 6. Using Enums as Keys
  print('\n--- 6. Using Enums as Keys ---');
  final enumJson = Json5();
  enumJson[EConfigKeys.host] = '127.0.0.1';
  enumJson.set(EConfigKeys.port, 8080);
  print('Host: ${enumJson.asString(EConfigKeys.host)}');
  print('Port: ${enumJson.asInt(EConfigKeys.port)}');
}
