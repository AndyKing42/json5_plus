// TODO(andy): document this!
/// Global configuration options managing the default behavior of the parsing layer
/// and memory retention during standard operations.
final Json5Options json5Options = Json5Options._();

// TODO(andy): document this!
/// Toggles tracking options for the json5_plus wrapper classes and standard parser outputs.
class Json5Options {
  // TODO(andy): document this!
  /// Globally toggle whether newly constructed Json5 allocations should
  /// default to enforcing strictly localized keys, or allow case insensitive map searches.
  /// Overridden individually by the Json5 constructors via `caseSensitiveKeys` param.
  bool caseSensitiveKeys;
  // TODO(andy): document this!
  /// Flag tracking whether comments explicitly encountered in a raw block should be
  /// kept in-memory mapping as text. (Currently unused).
  bool retainComments;

  Json5Options._() : caseSensitiveKeys = true, retainComments = false;
}
