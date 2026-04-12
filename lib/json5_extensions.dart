// TODO(andy): document this!
///
extension Json5DateTimeExtension on DateTime? {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  String formatIso8601() {
    ArgumentError.checkNotNull(this, "DateTime cannot be null");
    return "${this!.year}"
        "-"
        "${this!.month < 10 ? '0' : ''}${this!.month}"
        "-"
        "${this!.day < 10 ? '0' : ''}${this!.day}"
        "T"
        "${this!.hour < 10 ? '0' : ''}${this!.hour}"
        ":"
        "${this!.minute < 10 ? '0' : ''}${this!.minute}"
        ":"
        "${this!.second < 10 ? '0' : ''}${this!.second}"
        "Z";
  }

  //--------------------------------------------------------------------------------------------------
}

//==================================================================================================
// TODO(andy): document this!
///
extension Json5StringExtension on String? {
  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  int compareToIgnoreCase(String? other) =>
      (this == null ? "" : this!.toLowerCase()).compareTo(other == null ? "" : other.toLowerCase());

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool get isBlank => this == null || this!.isEmpty || this!.trim().isEmpty;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool get isNotBlank => !isBlank;

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  bool toBool({final bool defaultValue = false}) => isBlank
      ? defaultValue
      : this![0] == 'y' || this![0] == 'Y' || this!.toLowerCase() == "true" || this! == "1";

  //--------------------------------------------------------------------------------------------------
  /// Returns a DateTime extracted from a String.
  /// @param s The String containing a date plus an optional time. The string can contain "/", "-",
  /// " ", and ":" characters, the year can be two or four digits, and the optional time can be
  /// hhmmss or hhmm.
  DateTime? toDateTime([final DateTime? defaultValue]) =>
      _toDateTime(defaultValue: defaultValue, utc: false);

  //--------------------------------------------------------------------------------------------------
  DateTime? _toDateTime({DateTime? defaultValue, required bool utc}) {
    if (isBlank) {
      return defaultValue;
    }
    DateTime? parsedDateTime = DateTime.tryParse(this!);
    if (parsedDateTime != null) {
      return utc ? parsedDateTime.toUtc() : parsedDateTime.toLocal();
    }
    try {
      String strippedDate = this!.replaceAll(RegExp(r'[-/:\sT.]'), '');
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

  //--------------------------------------------------------------------------------------------------
  /// Returns a UTC DateTime extracted from a String.
  /// @param s The String containing a date plus an optional time. The string can contain "/", "-",
  /// " ", and ":" characters, the year can be two or four digits, and the optional time can be
  /// hhmmss or hhmm.
  DateTime? toDateTimeUtc([final DateTime? defaultValue]) =>
      _toDateTime(defaultValue: defaultValue, utc: true);

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  double toDouble([final double defaultValue = 0]) {
    try {
      return this == null ? 0 : double.parse(this!);
    } on FormatException {
      return defaultValue;
    }
  }

  //--------------------------------------------------------------------------------------------------
  // TODO(andy): document this!
  ///
  int toInt([final int defaultValue = 0]) {
    try {
      return this == null ? 0 : int.parse(this!);
    } on FormatException {
      return defaultValue;
    }
  }

  //--------------------------------------------------------------------------------------------------
}
