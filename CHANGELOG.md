## 0.2.1
 * Lazily allocated `_ephemeralKeys` in `Json5` only when an ephemeral list or set is created, eliminating an extra `Set`/`LinkedHashSet` allocation and empty-set hash lookup per parsed object.
 * Added a dedicated fast path in `Json5.setParsedEntry` to avoid redundant `_getKey` lookups and `_convertIterable` re-scans on arrays already parsed by `Json5Parser`.
 * Added `Json5.isBlankString` to avoid `trim()` string allocations when validating non-blank inputs in `Json5.fromString` and `Json5.fromFile`.
 * Optimized `_isWhitespace` with an ASCII fast path and routed simple floating-point literals directly to `double.tryParse` in `Json5Parser._parsePrimitive`.
 * Fixed a missing opening quote typo in `json5Input` inside `benchmark/json5_benchmark.dart`.

## 0.2.0
 * **Breaking:** Enforced `readOnly: true` at runtime by throwing `UnsupportedError` instead of debug-only `AssertionError` across all mutating methods and `Json5.emptyJson`, and fixed `fromString`, `fromMap`, `fromJson5`, `fromDiffs`, `fromKeyAndValueLists`, `fromKeyToIndexMapAndValueList`, and `Json5Parser` to construct `readOnly: true` objects (including nested objects and collections) without throwing during initialization.
 * **Breaking:** Updated `asDateTimeUtc` and `removeDateTimeUtc` to take a named `{DateTime? defaultValue}` parameter (matching `asDateTime` / `removeDateTime`), and fixed `asDateTimeUtc` / `asDateTimeUtcOrNull` to handle `DateTime` and numeric epoch millisecond values directly.
 * **Breaking:** Serialized non-finite `double` values (`NaN`, `Infinity`, `-Infinity`) as `null` when formatting in strict JSON mode (`json5: false`).
 * **Breaking:** Enhanced `$include` to resolve relative paths relative to the enclosing file's directory (when loaded via `Json5.fromFile`), forward `caseSensitiveKeys`, `dateTimeFormat`, `readOnly`, and `sortedKeys` options, and detect circular `$include` chains.
 * Fixed `${params.*}` standalone placeholder extraction off-by-one bug so native non-`String` parameter values (`int`, `bool`, `Map`, `List`) preserve their types.
 * Fixed `TypedAccessorMixin.joinStrings` to honor the `includeBlankValues` parameter.
 * Eliminated string allocations in case-insensitive `SplayTreeMap` comparisons and hoisted static map comparator/equality/hashCode helpers.
 * Added `Json5.deepEquals`, updated `Json5.fromDiffs` and `Json5.setIfChanged` to use recursive deep equality, and bound object property comments in `Json5CommentRegistry` to property keys so comments move with their keys under `sortedKeys: true` and are preserved by `Json5.fromJson5`.

## 0.1.9
 * Normalized escaped `CR` and `CRLF` line endings in multi-line JSON5 strings to `\n`.
 * Fixed an infinite loop when a stray `/` appears in whitespace or comment positions.
 * Fixed `Json5.decodeMultiple` so incomplete trailing objects are preserved in `unprocessed`.
 * Fixed ephemeral keys to respect `caseSensitiveKeys: false` and prevented ephemeral entries from leaking into `containsKey`, `isNull`, `isNotNull`, `operator []`, `fromDiffs`, `setFromJson`, `setIfChanged`, `setIfNewValueIsNotEmpty`, and `setIfNotEqual`.
 * Fixed `Json5.set` to recursively convert nested `Map`s inside `Iterable`s (including typed lists and `const` lists) into `Json5` objects.
 * Optimized enum key/value handling via `Enum.name` and `is Enum`.
 * Optimized `toJsonString` to write directly into a single shared `StringBuffer`, and optimized `escapeString` and `_parseStringWithEscapes` to copy unescaped slices with fewer allocations.
 * Eliminated redundant lookups in `remove*ListOrNull` / `remove*SetOrNull` and pre-compiled the date separator `RegExp`.
 * Added support for uppercase `0X` hex prefixes and rejected invalid signs after `0x`/`0X`.
 * Delegated floating-point parsing to `num.tryParse` for exact IEEE-754 precision.
 * Added support for UTF-8 BOM (`\uFEFF`) and non-breaking space (`\u00A0`) as whitespace.

## 0.1.8
 * Updated `README.md` Getting Started instructions to use `dart pub add json5_plus`.

## 0.1.7
 * Added support for escaping and quoting special characters in keys during JSON and JSON5 serialization (`toJsonString`, `toFormattedString`, `toString`).
 * Keys in JSON mode now escape quotes, backslashes, and control characters.
 * Keys in JSON5 mode now automatically quote and escape keys that are not valid ECMAScript identifiers (e.g. containing spaces, colons, punctuation, quotes, or leading digits).
 * Added explicit support for `\v` (vertical tab) and `\0` (null character) escape sequences when parsing keys and strings.

## 0.1.6
 * Fixed `Json5.fromJson5` and `Json5.fromDiffs` to properly inherit `caseSensitiveKeys` from the source object when unassigned.

## 0.1.5
 * Updated `meta` dependency version constraint to `^1.9.0` for full compatibility with Flutter SDK version pinning.

## 0.1.4
 * Made `Json5.escapeString` static method public for escaping control characters, quotes, and backslashes in JSON/JSON5 strings.
 * Added `Json5.fromDiffs` factory constructor to construct a new `Json5` object containing only key-value entries from `json2` that differ from or do not exist in `json1`.
 * Added `EDateTimeFormat` enum (`iso8601`, `yyyymmddhhmmss`) and `dateTimeFormat` parameter across `Json5` constructors, factories, and parser, with global configuration field `Json5.defaultDateTimeFormat`.
 * Added `allowBlankString` parameter to `Json5.fromString` and static field `Json5.defaultAllowBlankString` to allow parsing empty/whitespace strings as `{}`.
 * Added `sortedKeys` parameter and field to `Json5` constructors, factories, and parser to enforce case-insensitive key sorting.
 * Added global configuration static fields `Json5.defaultUseJson5ForToString` and `Json5.defaultUseSortedKeys`.
 * Added `OrNull` typed accessors (`asBoolOrNull`, `asDateTimeOrNull`, `asDateTimeUtcOrNull`, `asDoubleOrNull`, `asIntOrNull`, `asJsonOrNull`, `asStringOrNull`, and collection variants) to `TypedAccessorMixin` and `Json5`.
 * Added `OrNull` typed removal methods (`removeBoolOrNull`, `removeDateTimeOrNull`, `removeDateTimeUtcOrNull`, `removeDoubleOrNull`, `removeIntOrNull`, `removeJsonOrNull`, `removeStringOrNull`, and collection variants) to `Json5`.

## 0.1.3
 * Added typed collection remove methods (`removeBoolList`, `removeBoolSet`, `removeDateTimeList`, `removeDateTimeSet`, `removeDoubleList`, `removeDoubleSet`, `removeDynamicList`, `removeDynamicSet`, `removeIntList`, `removeIntSet`, `removeJsonList`, `removeJsonSet`, `removeStringList`, `removeStringSet`) to `Json5`.

## 0.1.2
 * Added typed scalar remove methods (`removeBool`, `removeDateTime`, `removeDateTimeUtc`, `removeDouble`, `removeInt`, `removeString`) to `Json5`.

## 0.1.1
 * For read-only Json5 objects always return unmodifiable lists or sets.

## 0.1.0
 * Bump the version to 0.1.0.

## 0.0.5
 * Added `Set` accessors (e.g., `asStringSet`, `asIntSet`) for typed JSON extraction.
 * Improved `List` and `Set` accessors to gracefully wrap single scalar values into a collection instead of overwriting them.
 * Improved `List` and `Set` accessors to return live, mutable collections for missing keys. These empty collections use an ephemeral key system so they don't bloat the serialized JSON output unless items are actually added to them.
 * Optimized internal collection parsing and conversion logic.

## 0.0.4
 * Add a longer package description in pubspec.yaml.

## 0.0.3
 * Fix the CHANGELOG.md instructions.
 * Ensure that all test filenames are lowercase.

## 0.0.2

* Fixed folder naming conventions in the test suite to follow Dart snake_case guidelines.
* Updated `win32` dependency constraints to support version 6.0.0.
* Improved internal file structure for better package scoring.

## 0.0.1

* Initial release of json5_plus.