import 'dart:collection';

import 'package:meta/meta.dart';

import 'json5.dart';

//==================================================================================================
@internal
enum ECommentLocation {
  afterColon,
  afterComma,
  beforeColon,
  beforeComma,
  beforeKey,
  standaloneAfter,
  standaloneBefore,
}

//==================================================================================================
@internal
class Json5Comment {
  //------------------------------------------------------------------------------------------------
  final bool blockComment;
  final String comment; // The raw text of the comment, including the delimiters (// or /* */).
  final bool precededByNewline;

  //------------------------------------------------------------------------------------------------
  Json5Comment(this.comment, {required this.blockComment, required this.precededByNewline});

  //------------------------------------------------------------------------------------------------
  @override
  String toString() => comment;
}

//==================================================================================================
@internal
class Json5CommentRegistry {
  //------------------------------------------------------------------------------------------------
  static final Object trailingKey = Object();

  // Container -> KeyOrIndex -> Location -> List<Comments>
  final Map<Object, Map<Object, Map<ECommentLocation, List<Json5Comment>>>> _registryMap = {};

  //------------------------------------------------------------------------------------------------
  static bool _commentKeyEquals(Object key1, Object key2) {
    if (key1 is String && key2 is String) {
      return Json5.caseInsensitiveKeyEquals(key1, key2);
    }
    return key1 == key2;
  }

  //------------------------------------------------------------------------------------------------
  static int _commentKeyHashCode(Object key) =>
      key is String ? Json5.caseInsensitiveKeyHashCode(key) : key.hashCode;

  //------------------------------------------------------------------------------------------------
  /// Adds a comment to the registry.
  void add({
    required Json5Comment comment,
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
  }) => _getOrCreateSlot(
    commentLocation: commentLocation,
    container: container,
    keyOrIndex: keyOrIndex,
  ).add(comment);

  //------------------------------------------------------------------------------------------------
  /// Adds all comments in [commentList] to the registry.
  void addAll({
    required ECommentLocation commentLocation,
    required List<Json5Comment> commentList,
    required Object container,
    required Object keyOrIndex,
  }) {
    if (commentList.isEmpty) {
      return;
    }
    _getOrCreateSlot(
      commentLocation: commentLocation,
      container: container,
      keyOrIndex: keyOrIndex,
    ).addAll(commentList);
  }

  //------------------------------------------------------------------------------------------------
  /// Copies all comments registered for [sourceContainer] onto [targetContainer] in [targetRegistry].
  void copyContainerCommentsTo(
    Object sourceContainer,
    Object targetContainer,
    Json5CommentRegistry targetRegistry,
  ) {
    final Map<Object, Map<ECommentLocation, List<Json5Comment>>>? sourceKeyMap =
        _registryMap[sourceContainer];
    if (sourceKeyMap == null) {
      return;
    }
    for (final MapEntry<Object, Map<ECommentLocation, List<Json5Comment>>> keyEntry
        in sourceKeyMap.entries) {
      for (final MapEntry<ECommentLocation, List<Json5Comment>> locEntry in keyEntry.value.entries) {
        targetRegistry.addAll(
          commentLocation: locEntry.key,
          commentList: locEntry.value,
          container: targetContainer,
          keyOrIndex: keyEntry.key,
        );
      }
    }
  }

  //------------------------------------------------------------------------------------------------
  /// Retrieves comments for a specific structural point.
  List<Json5Comment>? getComments(Object container, Object keyOrIndex, ECommentLocation location) =>
      _registryMap[container]?[keyOrIndex]?[location];

  //------------------------------------------------------------------------------------------------
  List<Json5Comment> _getOrCreateSlot({
    required ECommentLocation commentLocation,
    required Object container,
    required Object keyOrIndex,
  }) => _registryMap
      .putIfAbsent(
        container,
        () => (container is Json5 && !container.caseSensitiveKeys)
            ? LinkedHashMap<Object, Map<ECommentLocation, List<Json5Comment>>>(
                equals: _commentKeyEquals,
                hashCode: _commentKeyHashCode,
              )
            : <Object, Map<ECommentLocation, List<Json5Comment>>>{},
      )
      .putIfAbsent(keyOrIndex, () => <ECommentLocation, List<Json5Comment>>{})
      .putIfAbsent(commentLocation, () => <Json5Comment>[]);

  //------------------------------------------------------------------------------------------------
  /// Checks if any comments exist for a specific container (useful for the formatter).
  bool hasComments(Object container) => _registryMap.containsKey(container);

  //------------------------------------------------------------------------------------------------
  void moveContainer(Object oldContainer, Object newContainer) {
    final Map<Object, Map<ECommentLocation, List<Json5Comment>>>? keyToCommentMap = _registryMap
        .remove(oldContainer);
    if (keyToCommentMap != null) {
      _registryMap[newContainer] = keyToCommentMap;
    }
  }
}
