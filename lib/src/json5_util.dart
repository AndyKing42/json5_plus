/// The Json5Util singleton.
final Json5Util json5Util = Json5Util._();

/// A class that provides Json5Util utility methods.
class Json5Util {
  //--------------------------------------------------------------------------------------------------
  final Set<Type> _builtinTypeSet;

  //--------------------------------------------------------------------------------------------------
  Json5Util._()
    : _builtinTypeSet = Set.unmodifiable([bool, double, int, List, Map, Null, Set, String]);

  //--------------------------------------------------------------------------------------------------
  /// Returns true if [value] is an enum entry.
  bool isEnum(dynamic value) {
    Type type = value.runtimeType;
    if (_builtinTypeSet.contains(type)) {
      return false;
    }
    String valueString = value.toString();
    int dotIndex = valueString.indexOf(".");
    return dotIndex > 0 && type.toString() == valueString.substring(0, dotIndex);
  }

  //--------------------------------------------------------------------------------------------------
}
