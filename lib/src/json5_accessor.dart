import 'json5_extensions.dart';

// TODO(andy): document this!
/// Shared getter operations applied on top of internal `Json5` representations offering
/// gracefully defaulting extraction parameters and type-casting validations natively.
mixin Json5Accessor {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// A constant zero-time UTC anchor used for parsing fallback conditions lacking timezone specifics.
  static final DateTime epochUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Enables subscript `[]` querying through to the dynamically evaluated type nodes mapping into the tree.
  dynamic operator [](dynamic key) => asType(key);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Extract a value and convert to [bool], substituting [defaultValue] if null or blank.
  /// Handles "true", numeric != 0, and native booleans automatically.
  bool asBool(dynamic key, {bool defaultValue = false}) {
    dynamic result = asType(key);
    if (result == null) {
      return defaultValue;
    }
    switch (result) {
      case bool b:
        return b;
      case num n:
        return n != 0;
      default:
        return result.toString().toBool();
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Parses the requested property to a locale-oriented [DateTime], safely using string, numeric MS epoch,
  /// or providing [defaultValue] on error. If omitted completely, provides `DateTime.now()`.
  DateTime asDateTime(dynamic key, {DateTime? defaultValue}) {
    dynamic value = asType(key);
    if (value == null) {
      return defaultValue ?? DateTime.now();
    }
    switch (value) {
      case DateTime dateTimeValue:
        return dateTimeValue;
      case num numValue:
        return DateTime.fromMillisecondsSinceEpoch(numValue.toInt());
      default:
        return value.toString().toDateTime() ?? defaultValue ?? epochUtc;
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Forces the property interpretation strictly to UTC boundary coordinates from the payload format.
  DateTime asDateTimeUtc(final dynamic key, [final DateTime? defaultValue]) =>
      asString(key).toDateTimeUtc() ?? defaultValue ?? epochUtc;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Retrieve floating point values casting booleans to binary (0/1), timestamps to standard epochs,
  /// or attempting `double.parse`. Reverts to [defaultValue] assuming failure.
  double asDouble(dynamic key, {double defaultValue = 0}) {
    dynamic result = asType(key);
    if (result == null) {
      return defaultValue;
    }
    switch (result) {
      case bool b:
        return b ? 1 : 0;
      case DateTime d:
        return d.millisecondsSinceEpoch.toDouble();
      case num n:
        return n.toDouble();
      default:
        return result.toString().toDouble(defaultValue);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Evaluates and yields property mapping specifically as an integer, trimming floats to nearest `.toInt()`
  /// representation across the internal mapped variants before dropping to string-casts.
  int asInt(dynamic key, {int defaultValue = 0}) {
    dynamic result = asType(key);
    if (result == null) {
      return defaultValue;
    }
    switch (result) {
      case bool b:
        return b ? 1 : 0;
      case DateTime d:
        return d.millisecondsSinceEpoch;
      case num n:
        return n.toInt();
      default:
        return result.toString().toInt(defaultValue);
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Evaluates and yields property as string explicitly stringifying timestamps back through `formatIso8601()`.
  /// Blanks are reverted cleanly to [defaultValue] (defaults "").
  String asString(dynamic key, {String defaultValue = ""}) {
    dynamic result = asType(key);
    if (result == null) {
      return defaultValue;
    }
    switch (result) {
      case bool b:
        return b ? "true" : "false";
      case DateTime d:
        return d.formatIso8601();
      default:
        return result.toString();
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Interface hook enforcing access directly into the localized `SplayTreeMap` / raw tree nodes generically.
  dynamic asType(dynamic key);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Verifies presence natively verifying evaluated non-null allocations map over [key].
  bool containsKey(dynamic key) => asType(key) != null;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// Validates mapping directly returns a non-null instantiated structural object mapped dynamically at [key].
  bool isNotNull(dynamic key) => asType(key) != null;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  /// True if mapped object natively fails verification check matching to null exactly over [key].
  bool isNull(dynamic key) => asType(key) == null;

  //--------------------------------------------------------------------------------------------------
  /// Returns a string containing the string values for all keys, skipping blank or
  /// null values.
  String joinStrings(List<dynamic> keyList, [String separator = ","]) {
    final List<String> resultList = [];
    for (final dynamic key in keyList) {
      final String val = asString(key);
      if (val.isNotEmpty) {
        resultList.add(val);
      }
    }
    return resultList.join(separator);
  }

  //--------------------------------------------------------------------------------------------------
}
