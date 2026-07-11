//==================================================================================================
/// Extension methods for [DateTime].
extension Json5DateTimeExtension on DateTime? {
  //------------------------------------------------------------------------------------------------
  /// Returns the ISO 8601 representation of the date/time.
  String formatIso8601() {
    ArgumentError.checkNotNull(this, "DateTime cannot be null");
    return "${this!.year}"
        "-"
        "${this!.month < 10 ? "0" : ""}${this!.month}"
        "-"
        "${this!.day < 10 ? "0" : ""}${this!.day}"
        "T"
        "${this!.hour < 10 ? "0" : ""}${this!.hour}"
        ":"
        "${this!.minute < 10 ? "0" : ""}${this!.minute}"
        ":"
        "${this!.second < 10 ? "0" : ""}${this!.second}"
        "Z";
  }

  //==================================================================================================
  //------------------------------------------------------------------------------------------------
}

/// Extension methods for [String].
extension Json5StringExtension on String? {
  //------------------------------------------------------------------------------------------------
  /// Returns the result of comparing this tring to another string, ignoring case.
  int compareToIgnoreCase(String? other) {
    final int len = this?.length ?? 0;
    final int otherLen = other?.length ?? 0;
    final int minLen = len < otherLen ? len : otherLen;
    for (int i = 0; i < minLen; ++i) {
      int a = this!.codeUnitAt(i);
      int b = other!.codeUnitAt(i);
      if (a != b) {
        // If either character is non-ASCII (Unicode), fallback to toLowerCase
        if (a > 127 || b > 127) {
          return this!.toLowerCase().compareTo(other.toLowerCase());
        }
        if (a >= 97 && a <= 122) a -= 32; // a-z -> A-Z
        if (b >= 97 && b <= 122) b -= 32; // a-z -> A-Z
        if (a != b) return a - b;
      }
    }
    return len - otherLen;
  }

  //------------------------------------------------------------------------------------------------
  /// Returns true if the string is null, empty, or entirely whitespace.
  bool get isBlank => this == null || this!.isEmpty || this!.trim().isEmpty;

  //------------------------------------------------------------------------------------------------
  /// Returns true if the string is not: null; empty; or entirely whitespace.
  bool get isNotBlank => !isBlank;

  //------------------------------------------------------------------------------------------------
  /// Converts the string to a boolan value
  bool toBool({final bool defaultValue = false}) => isBlank
      ? defaultValue
      : this![0] == "y" || this![0] == "Y" || this!.toLowerCase() == "true" || this! == "1";

  //------------------------------------------------------------------------------------------------
  /// Converts the string to a [DateTime].
  DateTime? toDateTime([final DateTime? defaultValue]) =>
      _toDateTime(defaultValue: defaultValue, utc: false);

  //------------------------------------------------------------------------------------------------
  DateTime? _toDateTime({DateTime? defaultValue, required bool utc}) {
    if (isBlank) {
      return defaultValue;
    }
    DateTime? parsedDateTime = DateTime.tryParse(this!);
    if (parsedDateTime != null) {
      return utc ? parsedDateTime.toUtc() : parsedDateTime.toLocal();
    }
    try {
      String strippedDate = this!.replaceAll(RegExp(r"[-/:\sT.]"), "");
      int length = strippedDate.length;
      int day;
      int hour = 0;
      int minute = 0;
      int month;
      int second = 0;
      int millisecond = 0;
      int timeIndex;
      int year;
      if (length == 6 || length == 10 || length == 12) /* yymmdd[hhmm][ss] */ {
        year = 2_000 + int.parse(strippedDate.substring(0, 2));
        month = int.parse(strippedDate.substring(2, 4));
        day = int.parse(strippedDate.substring(4, 6));
        timeIndex = 6;
      } else if (length > 7) /* yyyymmdd[hhmm][ss][.*] */ {
        year = int.parse(strippedDate.substring(0, 4));
        month = int.parse(strippedDate.substring(4, 6));
        day = int.parse(strippedDate.substring(6, 8));
        timeIndex = 8;
      } else {
        return defaultValue;
      }
      if (length > timeIndex + 3) {
        hour = int.parse(strippedDate.substring(timeIndex, timeIndex + 2));
        minute = int.parse(strippedDate.substring(timeIndex + 2, timeIndex + 4));
        if (length > timeIndex + 5) {
          second = int.parse(strippedDate.substring(timeIndex + 4, timeIndex + 6));
          if (length > timeIndex + 8) {
            millisecond = int.parse(strippedDate.substring(timeIndex + 6, timeIndex + 9));
          }
        }
      }
      return utc
          ? DateTime.utc(year, month, day, hour, minute, second, millisecond)
          : DateTime(year, month, day, hour, minute, second, millisecond);
    } on Exception {
      return defaultValue;
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Converts the string to a UTC [DateTime].
  DateTime? toDateTimeUtc([final DateTime? defaultValue]) =>
      _toDateTime(defaultValue: defaultValue, utc: true);

  //------------------------------------------------------------------------------------------------
  /// Converts the string to a [double].
  double toDouble([final double defaultValue = 0]) {
    try {
      return this == null ? 0 : double.parse(this!);
    } on FormatException {
      return defaultValue;
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Converts the string to an integer.
  int toInt([final int defaultValue = 0]) {
    try {
      return this == null ? 0 : int.parse(this!);
    } on FormatException {
      return defaultValue;
    }
  }

  //==================================================================================================
  //------------------------------------------------------------------------------------------------
}
