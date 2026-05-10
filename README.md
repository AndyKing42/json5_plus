A Dart package for parsing and stringifying JSON5, which is a strict superset of JSON. JSON5 is an extension to the popular JSON file format that aims to be easier to write and maintain by hand (e.g., for config files) by allowing helpful features like unquoted keys, trailing commas, single quotes, and comments.

This package is built with performance in mind, offering parsing speeds that are highly competitive with the default JSON methods found in the standard Dart `dart:convert` library. Furthermore, it is fully safe for use in Dart web applications, cleanly avoiding the `JSObject` interop issues that can occasionally complicate web-based JSON manipulation.

## Why JSON5 Plus?

- **JSON5 Features:** Supports all standard JSON5 features, making your configuration files and data payloads much more human-friendly.
- **Type-Safe Accessors:** Provides built-in, typed access to values in your JSON payloads, drastically reducing boilerplate and manual type-casting errors. Note that when enums are used as keys the JSON key value will be derived by stripping the enum name and period.
- **Opinionated Formatter:** Stringifies Dart objects into beautifully formatted JSON5 strings. It guarantees an almost lossless reproduction of your input structure and comments, though note that the exact output format is somewhat opinionated.
- **Web & Cross-Platform:** 100% Dart native. Safely compiles to the web without triggering JavaScript `JSObject` type mapping errors.

## Getting started

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  json5_plus: ^1.0.0
```

## Usage

Here is a quick example of how to parse a JSON5 string:

```dart
import 'package:json5_plus/json5_plus.dart';

void main() {
  final json5String = '{ key: "value", /* comment */ }';
  final json = Json5.fromString(json5String);
  print(json.asString('key'));
}
```

## Additional information

For more information about the JSON5 specification, please visit [json5.org](https://json5.org/). 

Contributions, bug reports, and feature requests are always welcome!
