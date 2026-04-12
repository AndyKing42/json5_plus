import 'json5_extensions.dart';

// TODO(andy): document this!
///
mixin Json5Accessor {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  static final DateTime epochUtc = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  dynamic operator [](dynamic key) => asType(key);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
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
  ///
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
  ///
  DateTime asDateTimeUtc(final dynamic key, [final DateTime? defaultValue]) =>
      asString(key).toDateTimeUtc() ?? defaultValue ?? epochUtc;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
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
  ///
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
  ///
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
  ///
  dynamic asType(dynamic key);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool isNotNull(dynamic key) => asType(key) != null;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
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
