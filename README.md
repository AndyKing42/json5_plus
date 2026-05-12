# json5_plus

A Dart package for parsing and stringifying JSON5, which is a strict superset of JSON. JSON5 is an extension to the popular JSON file format that aims to be easier to write and maintain by hand (e.g., for config files) by allowing helpful features like unquoted keys, trailing commas, single quotes, and comments.

This package is built with performance in mind, offering parsing speeds that are highly competitive with the default JSON methods found in the standard Dart `dart:convert` library (within about 10% of the performance for 500 character JSON strings using case-sensitive keys, and within 20% of the performance for 64KB JSON strings). Furthermore, it is fully safe for use in Dart web applications, cleanly avoiding the `JSObject` interop issues that can occasionally complicate web-based JSON manipulation.

## Why JSON5 Plus?

- **JSON5 Features:** Supports all standard JSON5 features, including unquoted keys, comments, and trailing commas, making your configuration files and data payloads much more human-friendly.
- **Type-Safe Accessors:** Provides built-in, typed access to values in your JSON payloads, reducing boilerplate and manual type-casting errors. Note that when enums are used as keys the JSON key value will be derived by stripping the enum name and period. Keys can be either case-sensitive or case-insensitive.
- **Opinionated Formatter:** Stringifies Dart objects into beautifully formatted JSON5 strings. It guarantees an almost lossless reproduction of your input structure and comments, though note that the exact output format is somewhat opinionated.
- **Web & Cross-Platform:** 100% Dart native. Safely compiles to the web without triggering JavaScript `JSObject` type mapping errors.
- **"$include" capability with Parameters:** Use a value of "$include" to include another JSON5 file within the current file, including the ability to pass parameters from the enclosing file to the included file.

## Getting started

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  json5_plus: ^0.0.3
```

## Usage

A simple example of how to parse a JSON5 string:

```dart
import 'package:json5_plus/json5_plus.dart';

void main() {
  final json5String = '{ key: "value", /* comment */ }';
  final json = Json5.fromString(json5String);
  print(json.asString('key'));
}
```

An example that uses an enum for the keys:

```dart
import 'package:json5_plus/json5_plus.dart';

enum JsonKey {
  key1,
  key2,
}

void main() { 
  final json5String = '{ key1: 1, key2: "two", }';
  final json = Json5.fromString(json5String);
  print(json.asString(JsonKey.key1)); // "1"
  print(json.asBool(JsonKey.key1)); // true
  print(json.asString(JsonKey.key2)); // "two"
}
```

An example that uses "$include":

```dart
import 'dart:io';
import 'package:json5_plus/json5_plus.dart';

void main() {
  File('logging.json5').writeAsStringSync(r'''
  {
    dir: "${params.logDir}",
    level: "${params.logLevel}",
    prefix: "${params.logPrefix}",
  }
  ''');
  const String json5String = r'''
  {
    appName: "MyApp",
    logSettings: $include("logging.json5", {logDir: "/var/logs", logLevel: "info", logPrefix: "MyApp",}),
  }
  ''';
  final Json5 json = Json5.fromString(json5String);
  print(json.toFormattedString());
  File('logging.json5').deleteSync();
}
```

## Additional information

For more information about the JSON5 specification, please visit [json5.org](https://json5.org/). 

Contributions, bug reports, and feature requests are always welcome!
