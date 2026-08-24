/// Deterministic linked text-frame chains for multi-frame text flow.
///
/// Text frames can be linked into ordered chains (A → B → C) so that one
/// story flows across several frames. The persisted representation is a
/// single successor pointer per frame, stored in the owning text-frame
/// node's extensions under the [textFrameNextFrameExtension] key (a frame
/// id string). A frame without the key is terminal; a frame that is neither
/// linked nor referenced is an isolated single-frame chain.
///
/// This model is LINKS-FIRST by deliberate decision: it does NOT introduce
/// a first-class persisted TextStory. Text remains stored per node through
/// `extensions['text']` (see docs/architecture/page-linked-text-flow.md);
/// a future TextStory abstraction is a separate, deliberate
/// schema/migration milestone and must not be mixed into this one.
///
/// All validation is fail-closed with a precise [ArgumentError]:
/// self-links, cycles (any length), dangling targets, missing link sources,
/// ambiguous references (a frame with two predecessors) and frame-id
/// violations are all rejected before any structure is returned. Legacy
/// documents without link metadata decode and resolve unchanged.
library;

import 'dart:collection';

import '../document/document_model.dart';
import 'text_flow_engine.dart';

/// Extensions key under which a text frame stores its successor frame id.
const String textFrameNextFrameExtension = 'nextFrame';

/// One validated, immutable chain of linked text frames, in flow order.
final class TextFlowChain {
  TextFlowChain(List<String> frameIds)
    : _ids = List<String>.unmodifiable(frameIds) {
    if (frameIds.isEmpty) {
      throw ArgumentError('A text-flow chain must contain at least one frame.');
    }
    final seen = <String>{};
    for (final id in frameIds) {
      _validateFrameId(id);
      if (!seen.add(id)) {
        throw ArgumentError(
          'Duplicate frame "$id" in chain; a frame cannot be visited twice.',
        );
      }
    }
  }

  final List<String> _ids;

  /// Ordered frame ids (flow order). Unmodifiable.
  List<String> get ids => UnmodifiableListView<String>(_ids);

  int get length => _ids.length;

  String get first => _ids.first;

  String get last => _ids.last;

  bool get isSingle => length == 1;

  String operator [](int index) => _ids[index];

  int indexOf(String frameId) => _ids.indexOf(frameId);

  bool contains(String frameId) => _ids.contains(frameId);

  /// The successor of [frameId] in this chain, or null when [frameId] is
  /// the terminal frame (or not in this chain).
  String? successorOf(String frameId) {
    final index = _ids.indexOf(frameId);
    if (index == -1 || index + 1 >= _ids.length) return null;
    return _ids[index + 1];
  }

  /// Terminal overflow for a flow result across this chain.
  ///
  /// Returns the terminal frame id when [result] reports terminal overflow
  /// (the story continues past the LAST linked frame), otherwise null.
  ///
  /// Semantics: a per-frame `hasOverflow` flag on an INTERMEDIATE frame is
  /// a continuation indicator (the frame is full and the story continues
  /// into the next frame), NOT an overflow. The terminal overflow itself
  /// occurs exactly once — here, on [last] — so UI can show the overflow
  /// indicator on one frame only.
  String? terminalOverflowFrame(TextFlowResult result) {
    if (result.overflowLength == 0) return null;
    return last;
  }

  @override
  bool operator ==(Object other) =>
      other is TextFlowChain && _idsEquals(_ids, other._ids);

  @override
  int get hashCode => Object.hashAll(_ids);

  @override
  String toString() => 'TextFlowChain(${_ids.join(' -> ')})';
}

/// The full validated link structure for one frame set (e.g. one artboard):
/// every frame appears in exactly one chain, and the chains are in
/// deterministic order (sorted by first frame id, lexicographic).
final class TextFlowLinkSet {
  TextFlowLinkSet(List<TextFlowChain> chains)
    : _chains = List<TextFlowChain>.unmodifiable(chains);

  final List<TextFlowChain> _chains;

  /// Ordered chains (deterministic: sorted by first frame id). Unmodifiable.
  List<TextFlowChain> get chains =>
      UnmodifiableListView<TextFlowChain>(_chains);

  bool get isEmpty => _chains.isEmpty;

  /// Successor map covering every frame: frame id -> successor, or null for
  /// terminal frames.
  Map<String, String?> get successors {
    final map = <String, String?>{};
    for (final chain in _chains) {
      for (var i = 0; i < chain.length; i++) {
        map[chain[i]] = i + 1 < chain.length ? chain[i + 1] : null;
      }
    }
    return UnmodifiableMapView(map);
  }

  /// The successor of [frameId], or null (terminal frame, or unknown frame).
  String? successorOf(String frameId) => successors[frameId];

  /// The chain containing [frameId] (at any position), or null.
  TextFlowChain? chainContaining(String frameId) {
    for (final chain in _chains) {
      if (chain.contains(frameId)) return chain;
    }
    return null;
  }

  /// The chain that STARTS at [entryId].
  ///
  /// Throws [StateError] when [entryId] is unknown or mid-chain (a frame
  /// that already has a predecessor cannot be a flow entry).
  TextFlowChain chainFrom(String entryId) {
    for (final chain in _chains) {
      if (chain.first == entryId) return chain;
    }
    throw StateError(
      'Frame "$entryId" is not the head of any text-flow chain.',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TextFlowLinkSet && _chainsEquals(_chains, other._chains);

  @override
  int get hashCode => Object.hashAll(_chains);

  @override
  String toString() => 'TextFlowLinkSet(${_chains.join(', ')})';
}

/// Validates successor links and resolves them into deterministic chains.
///
/// The input is the full set of frame ids that may carry links plus a map
/// of `source -> target` successor links. Because every node has out-degree
/// at most 1 and validation rejects cycles, ambiguity and dangling
/// references, the result is always a set of disjoint, totally ordered
/// chains in which no frame is visited twice.
abstract final class TextFlowLinkResolver {
  /// Resolves [links] over [frameIds] into a validated [TextFlowLinkSet].
  ///
  /// Rules (all fail closed with [ArgumentError]):
  ///  * every id (frame and link endpoint) must be a valid frame id
  ///    (1..128 chars, no whitespace/controls — same contract as [GgenId]);
  ///  * a frame may not link to itself (self-link rejection);
  ///  * a link source must be in [frameIds] (missing-frame rejection);
  ///  * a link target must be in [frameIds] (dangling-target rejection);
  ///  * a frame may have at most one predecessor (duplicate/ambiguous
  ///    reference rejection);
  ///  * no cycles of any length (A → B → A, A → B → C → A, …).
  static TextFlowLinkSet resolve({
    required Set<String> frameIds,
    Map<String, String> links = const <String, String>{},
  }) {
    final ids = <String>{};
    for (final id in frameIds) {
      _validateFrameId(id);
      if (!ids.add(id)) {
        throw ArgumentError('Duplicate frame id in frame set: $id.');
      }
    }

    final successors = <String, String>{};
    for (final entry in links.entries) {
      final source = entry.key;
      final target = entry.value;
      _validateFrameId(source);
      _validateFrameId(target);
      if (source == target) {
        throw ArgumentError(
          'Self-link rejected: frame "$source" cannot link to itself.',
        );
      }
      if (!ids.contains(source)) {
        throw ArgumentError(
          'Missing frame: link source "$source" is not in the frame set.',
        );
      }
      if (!ids.contains(target)) {
        throw ArgumentError(
          'Dangling link: frame "$source" links to missing frame "$target".',
        );
      }
      successors[source] = target;
    }

    // Ambiguity: a frame with two predecessors has no well-defined chain
    // position.
    final inDegree = <String, int>{for (final id in ids) id: 0};
    for (final target in successors.values) {
      inDegree[target] = (inDegree[target] ?? 0) + 1;
    }
    for (final entry in inDegree.entries) {
      if (entry.value > 1) {
        throw ArgumentError(
          'Ambiguous link: frame "${entry.key}" has ${entry.value} '
          'predecessors; each frame may have at most one.',
        );
      }
    }

    // Cycle detection (white/gray/black over the functional graph).
    const white = 0;
    const gray = 1;
    const black = 2;
    final color = <String, int>{for (final id in ids) id: white};
    void visit(String start) {
      final path = <String>[];
      var node = start;
      while (true) {
        final state = color[node]!;
        if (state == gray) {
          final cycleStart = path.indexOf(node);
          final cycle = path.sublist(cycleStart);
          throw ArgumentError(
            'Cycle detected in text-frame links: '
            '${cycle.join(' -> ')} -> $node.',
          );
        }
        if (state == black) break;
        color[node] = gray;
        path.add(node);
        final next = successors[node];
        if (next == null) break;
        node = next;
      }
      for (final id in path) {
        color[id] = black;
      }
    }

    for (final id in ids) {
      if (color[id] == white) visit(id);
    }

    // Build the chains: every in-degree-0 frame is a head; deterministic
    // order (lexicographic by head id). Walking from every head covers each
    // frame exactly once (acyclic, out-degree <= 1).
    final heads = ids.where((id) => inDegree[id]! == 0).toList()..sort();
    final chains = <TextFlowChain>[];
    final visited = <String>{};
    for (final head in heads) {
      if (!visited.add(head)) continue; // defensive; cannot happen
      final path = <String>[head];
      var node = head;
      while (true) {
        final next = successors[node];
        if (next == null) break;
        if (!visited.add(next)) {
          // Unreachable after validation; kept as a last-resort guard.
          throw StateError(
            'Frame "$next" would be visited twice; link graph is malformed.',
          );
        }
        path.add(next);
        node = next;
      }
      chains.add(TextFlowChain(path));
    }
    return TextFlowLinkSet(chains);
  }

  /// Reads successor links from one artboard's text-frame node extensions
  /// and resolves them.
  ///
  /// A text frame stores its successor as a plain string under
  /// [textFrameNextFrameExtension]. Legacy nodes without the key are
  /// isolated single-frame chains and keep working unchanged.
  ///
  /// Fail-closed rules on top of [resolve]:
  ///  * only text-frame nodes may carry the key (any other kind throws);
  ///  * the target must be a text-frame node in the SAME artboard
  ///    (cross-artboard or dangling targets throw).
  static TextFlowLinkSet fromArtboard(Artboard artboard) {
    final frames = <String>{};
    final links = <String, String>{};
    for (final node in artboard.nodes) {
      if (node.kind != DocumentNodeKind.textFrame) {
        if (node.extensions.containsKey(textFrameNextFrameExtension)) {
          throw ArgumentError(
            'Non-text-frame node "${node.id}" (${node.kind.name}) must not '
            'declare "$textFrameNextFrameExtension".',
          );
        }
        continue;
      }
      frames.add(node.id.value);
      final raw = node.extensions[textFrameNextFrameExtension];
      if (raw == null) continue;
      if (raw is! String) {
        throw ArgumentError(
          'Node "${node.id}": "$textFrameNextFrameExtension" must be a '
          'frame id string.',
        );
      }
      links[node.id.value] = raw;
    }
    return TextFlowLinkResolver.resolve(frameIds: frames, links: links);
  }

  /// Resolves the link structure of every artboard in [project].
  static Map<String, TextFlowLinkSet> fromProject(DocumentProject project) => {
    for (final artboard in project.artboards)
      artboard.id.value: TextFlowLinkResolver.fromArtboard(artboard),
  };
}

bool _idsEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _chainsEquals(List<TextFlowChain> a, List<TextFlowChain> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _validateFrameId(String id) {
  if (id.isEmpty || id.length > 128) {
    throw ArgumentError.value(
      id,
      'frameId',
      'Frame id must contain 1..128 characters.',
    );
  }
  if (RegExp(r'[\x00-\x1F\x7F\s]').hasMatch(id)) {
    throw ArgumentError.value(
      id,
      'frameId',
      'Frame id cannot contain whitespace or controls.',
    );
  }
}
