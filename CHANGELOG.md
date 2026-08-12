## 0.1.2
 * Added typed remove methods (`removeBool`, `removeDateTime`, `removeDateTimeUtc`, `removeDouble`, `removeInt`, and `removeString`) to `Json5`.

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