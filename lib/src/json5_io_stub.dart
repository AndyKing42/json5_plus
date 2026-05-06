import 'json5.dart';

/// fromFile is not supported on the web.
Json5 fromFile({required bool caseSensitiveKeys, required String path, required bool readOnly}) =>
    throw UnsupportedError("Json5.fromFile is not supported on the web.");
