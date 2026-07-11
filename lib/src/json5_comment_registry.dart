import 'package:meta/meta.dart'
//==================================================================================================
;

@internal
enum ECommentLocation {
  afterColon,
  afterComma,
  beforeColon,
  beforeComma,
  standaloneAfter,
  standaloneBefore,

  //==================================================================================================
}

@internal
class Json5Comment {
  final String comment; // The raw text of the comment, including the delimiters (// or /* */).
  final bool blockComment;
  final bool precededByNewline;

  Json5Comment(this.comment, {required this.blockComment, required this.precededByNewline});

  @override
  String toString() => comment;

  //==================================================================================================
}

@internal
class Json5CommentRegistry {
  //------------------------------------------------------------------------------------------------
  // Container -> Index -> Location -> List<Comments>
  final Map<Object, Map<int, Map<ECommentLocation, List<Json5Comment>>>> _registryMap = {};

  //------------------------------------------------------------------------------------------------
  /// Adds a comment to the registry.
  void add({
    required Json5Comment comment,
    required ECommentLocation commentLocation,
    required Object container,
    required int index,
  }) => _registryMap
      .putIfAbsent(container, () => {})
      .putIfAbsent(index, () => {})
      .putIfAbsent(commentLocation, () => [])
      .add(comment);

  //------------------------------------------------------------------------------------------------
  /// Retrieves comments for a specific structural point.
  List<Json5Comment>? getComments(Object container, int index, ECommentLocation location) =>
      _registryMap[container]?[index]?[location];

  //------------------------------------------------------------------------------------------------
  /// Checks if any comments exist for a specific container (useful for the formatter).
  bool hasComments(Object container) => _registryMap.containsKey(container);

  //------------------------------------------------------------------------------------------------
  void moveContainer(Object oldContainer, Object newContainer) {
    final Map<int, Map<ECommentLocation, List<Json5Comment>>>? indexToCommentMap = _registryMap
        .remove(oldContainer);
    if (indexToCommentMap != null) {
      _registryMap[newContainer] = indexToCommentMap;
    }
  }

  //==================================================================================================
  //------------------------------------------------------------------------------------------------
}
