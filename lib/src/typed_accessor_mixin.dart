import 'json5_extensions.dart';

/// Generic accessors that can be added to any collection type object. For example, the [Json5]
/// class uses this mixin to provide typed access to the values in the JSON.
mixin TypedAccessorMixin {
  //--------------------------------------------------------------------------------------------------
  /// Returns the number of milliseconds since the epoch.
  static final DateTime epochUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  //--------------------------------------------------------------------------------------------------
  /// Returns the value associated with [key].
  dynamic operator [](dynamic key) => asType(key);

  //--------------------------------------------------------------------------------------------------
  /// Returns the boolean representation of the value associated with [key].
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
  /// Returns the date/time representation of the value associated with [key].
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
  /// Returns the UTC date/time representation of the value associated with [key].
  DateTime asDateTimeUtc(final dynamic key, [final DateTime? defaultValue]) =>
      asString(key).toDateTimeUtc() ?? defaultValue ?? epochUtc;

  //--------------------------------------------------------------------------------------------------
  /// Returns the double representation of the value associated with [key].
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
  /// Returns the integer representation of the value associated with [key].
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
  /// Returrns the string representation of the value associated with [key].
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
  /// Return the value associated with [key].
  dynamic asType(dynamic key);

  //--------------------------------------------------------------------------------------------------
  /// Indicates whether the [key] exists in the collection.
  bool containsKey(dynamic key) => asType(key) != null;

  //--------------------------------------------------------------------------------------------------
  /// Returns true if the value associated with [key] is not null.
  bool isNotNull(dynamic key) => asType(key) != null;

  //--------------------------------------------------------------------------------------------------
  /// Returns true if the value associated with [key] is null.
  bool isNull(dynamic key) => asType(key) == null;

  //--------------------------------------------------------------------------------------------------
  /// Returns a string containing the string values for all keys.
  String joinStrings(
    List<dynamic> keyList, {
    bool includeBlankValues = false,
    String separator = ",",
  }) {
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
