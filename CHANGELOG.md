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