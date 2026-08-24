import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

Artboard artboard(String id, List<DocumentNode> nodes) =>
    Artboard(id: GgenId(id), name: id, width: 1000, height: 1000, nodes: nodes);

DocumentNode textNode(String id, {String? next}) => DocumentNode(
  id: GgenId(id),
  kind: DocumentNodeKind.textFrame,
  name: id,
  extensions: next == null
      ? const <String, Object?>{}
      : <String, Object?>{'text': 'x', textFrameNextFrameExtension: next},
);

TextFlowFrameInput frameInput(String id, {double w = 60, double h = 30}) =>
    TextFlowFrameInput(
      frameId: id,
      geometry: FrameGeometry(x: 0, y: 0, frameWidth: w, frameHeight: h),
      layout: ColumnLayout.create(columnCount: 2),
    );

void main() {
  const engine = TextFlowEngine(MonospaceMeasurementProvider());

  group('Resolver basics', () {
    test('no frames resolves to an empty link set', () {
      final set = TextFlowLinkResolver.resolve(frameIds: const {});
      expect(set.isEmpty, isTrue);
    });

    test('no links: every frame is an isolated single-frame chain', () {
      final set = TextFlowLinkResolver.resolve(frameIds: {'b', 'a', 'c'});
      expect(set.chains, hasLength(3));
      // Deterministic order: heads sorted lexicographically.
      expect(set.chains.map((c) => c.first).toList(), ['a', 'b', 'c']);
      for (final chain in set.chains) {
        expect(chain.isSingle, isTrue);
      }
    });

    test('A -> B resolves to one two-frame chain', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'A', 'B'},
        links: {'A': 'B'},
      );
      expect(set.chains, hasLength(1));
      expect(set.chains.single.ids, ['A', 'B']);
      expect(set.successorOf('A'), 'B');
      expect(set.successorOf('B'), isNull);
      expect(set.chainFrom('A'), set.chains.single);
      expect(() => set.chainFrom('B'), throwsStateError); // mid/terminal frame
    });

    test('A -> B -> C resolves in exact flow order', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'A', 'B', 'C'},
        links: {'A': 'B', 'B': 'C'},
      );
      expect(set.chains.single.ids, ['A', 'B', 'C']);
      expect(set.successorOf('C'), isNull);
      expect(set.chainContaining('B'), set.chains.single);
    });

    test(
      'multiple chains are deterministic (heads sorted lexicographically)',
      () {
        final set = TextFlowLinkResolver.resolve(
          frameIds: {'a1', 'a2', 'b1', 'b2', 'z9'},
          links: {'b1': 'b2', 'a1': 'a2'},
        );
        expect(set.chains.map((c) => c.ids).toList(), [
          ['a1', 'a2'],
          ['b1', 'b2'],
          ['z9'],
        ]);
      },
    );

    test('successors map covers every frame exactly once', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'a', 'b', 'c'},
        links: {'a': 'b'},
      );
      final map = set.successors;
      expect(map.keys, unorderedEquals(['a', 'b', 'c']));
      expect(map['a'], 'b');
      expect(map['b'], isNull);
      expect(map['c'], isNull);
    });
  });

  group('Fail-closed link validation', () {
    test('self-link rejected', () {
      expect(
        () => TextFlowLinkResolver.resolve(frameIds: {'A'}, links: {'A': 'A'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Self-link'),
          ),
        ),
      );
    });

    test('two-cycle A -> B -> A rejected', () {
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A', 'B'},
          links: {'A': 'B', 'B': 'A'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle'),
          ),
        ),
      );
    });

    test('longer cycles rejected (3 and 4 frames)', () {
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A', 'B', 'C'},
          links: {'A': 'B', 'B': 'C', 'C': 'A'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle'),
          ),
        ),
      );
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A', 'B', 'C', 'D'},
          links: {'A': 'B', 'B': 'C', 'C': 'D', 'D': 'A'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Cycle'),
          ),
        ),
      );
    });

    test('cycle attached to a tail is still rejected', () {
      // A -> B -> C -> B (cycle not including the head). The cycle head
      // gains a second predecessor, so the ambiguity rule may fire before
      // cycle detection; BOTH are fail-closed rejections of the same
      // invalid graph.
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A', 'B', 'C'},
          links: {'A': 'B', 'B': 'C', 'C': 'B'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            anyOf(contains('Cycle'), contains('Ambiguous')),
          ),
        ),
      );
    });

    test('dangling target rejected', () {
      expect(
        () =>
            TextFlowLinkResolver.resolve(frameIds: {'A'}, links: {'A': 'NOPE'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Dangling'),
          ),
        ),
      );
    });

    test('missing link source rejected', () {
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'B'},
          links: {'GHOST': 'B'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Missing frame'),
          ),
        ),
      );
    });

    test('duplicate/ambiguous reference rejected (two predecessors)', () {
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A', 'B', 'C'},
          links: {'A': 'C', 'B': 'C'},
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Ambiguous'),
          ),
        ),
      );
    });

    test('invalid frame ids rejected', () {
      expect(
        () => TextFlowLinkResolver.resolve(frameIds: {''}),
        throwsArgumentError,
      );
      expect(
        () => TextFlowLinkResolver.resolve(frameIds: {'has space'}),
        throwsArgumentError,
      );
      expect(
        () => TextFlowLinkResolver.resolve(
          frameIds: {'A'},
          links: {'A': 'bad\tid'},
        ),
        throwsArgumentError,
      );
    });
  });

  group('Chain invariants', () {
    test('frame cannot be visited twice (uniqueness enforced)', () {
      expect(() => TextFlowChain(['a', 'b', 'a']), throwsArgumentError);
      expect(() => TextFlowChain([]), throwsArgumentError);
    });

    test('every frame appears in exactly one chain, once', () {
      final frames = {'a', 'b', 'c', 'd', 'e'};
      final set = TextFlowLinkResolver.resolve(
        frameIds: frames,
        links: {'a': 'b', 'c': 'd'},
      );
      final flat = set.chains.expand((c) => c.ids).toList();
      expect(flat.length, frames.length);
      expect(flat.toSet(), frames);
    });

    test('chain successorOf matches the resolver view', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'A', 'B', 'C'},
        links: {'A': 'B', 'B': 'C'},
      );
      final chain = set.chains.single;
      expect(chain.successorOf('A'), 'B');
      expect(chain.successorOf('C'), isNull);
      expect(chain.successorOf('ZZZ'), isNull);
    });
  });

  group('DocumentProject integration', () {
    test('legacy nodes without link metadata work unchanged', () {
      final ab = artboard('ab', [textNode('t1'), textNode('t2')]);
      final set = TextFlowLinkResolver.fromArtboard(ab);
      expect(set.chains, hasLength(2));
      for (final chain in set.chains) {
        expect(chain.isSingle, isTrue);
      }
    });

    test('linked text frames in one artboard resolve to a chain', () {
      final ab = artboard('ab', [
        textNode('t1', next: 't2'),
        textNode('t2', next: 't3'),
        textNode('t3'),
      ]);
      final set = TextFlowLinkResolver.fromArtboard(ab);
      expect(set.chains.single.ids, ['t1', 't2', 't3']);
      expect(set.successorOf('t3'), isNull);
    });

    test('cross-artboard link rejected (dangling inside the artboard)', () {
      // 'other' exists only in another artboard; from THIS artboard's view
      // it is a dangling target.
      final ab = artboard('ab', [textNode('t1', next: 'other')]);
      expect(
        () => TextFlowLinkResolver.fromArtboard(ab),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Dangling'),
          ),
        ),
      );
    });

    test('non-text-frame node carrying nextFrame rejected', () {
      final shape = DocumentNode(
        id: GgenId('s1'),
        kind: DocumentNodeKind.shape,
        name: 's',
        extensions: <String, Object?>{textFrameNextFrameExtension: 't1'},
      );
      final ab = artboard('ab', [shape, textNode('t1')]);
      expect(
        () => TextFlowLinkResolver.fromArtboard(ab),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('Non-text-frame'),
          ),
        ),
      );
    });

    test('non-string nextFrame value rejected', () {
      final node = DocumentNode(
        id: GgenId('t1'),
        kind: DocumentNodeKind.textFrame,
        name: 't1',
        extensions: <String, Object?>{textFrameNextFrameExtension: 42},
      );
      final ab = artboard('ab', [node]);
      expect(
        () => TextFlowLinkResolver.fromArtboard(ab),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('frame id string'),
          ),
        ),
      );
    });

    test('fromProject maps every artboard', () {
      final project = DocumentProject(
        id: GgenId('p'),
        name: 'P',
        artboards: [
          artboard('ab1', [textNode('t1', next: 't2'), textNode('t2')]),
          artboard('ab2', [textNode('u1')]),
        ],
      );
      final sets = TextFlowLinkResolver.fromProject(project);
      expect(sets.keys, {'ab1', 'ab2'});
      expect(sets['ab1']!.chains.single.ids, ['t1', 't2']);
      expect(sets['ab2']!.chains.single.isSingle, isTrue);
    });
  });

  group('Flow across linked frames (engine reuse, no second engine)', () {
    test('terminal overflow exactly once across a linked chain', () {
      // Chain from links: f1 -> f2. Story longer than both frames.
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'f1', 'f2'},
        links: {'f1': 'f2'},
      );
      final order = set.chains.single.ids;
      // Total chain capacity is 2 frames x 20 chars = 40; 42 chars leave a
      // 2-char terminal overflow in the last frame.
      final story = 'A' * 38 + 'TAIL';
      final chain = set.chains.single;
      final result = engine.flow(
        story: story,
        frames: order.map(frameInput).toList(),
        fontSize: 10,
      );
      expect(result.hasOverflow, isTrue);
      expect(result.overflowLength, 2);
      // Per-frame flags: f1's last column is a CONTINUATION indicator
      // (story continues into f2); f2's last column carries the terminal
      // overflow.
      final flagged = result.allColumns.where((c) => c.hasOverflow).toList();
      expect(flagged.map((c) => c.frameId), ['f1', 'f2']);
      // Terminal overflow occurs exactly ONCE, on the chain's last frame.
      expect(chain.terminalOverflowFrame(result), 'f2');
      expect(result.conserves(story), isTrue);
    });

    test('conservation holds across linked frames when the story fits', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'f1', 'f2', 'f3'},
        links: {'f1': 'f2', 'f2': 'f3'},
      );
      final story = 'A' * 10 + 'B' * 10 + 'C' * 10; // fits exactly (3x20)
      final result = engine.flow(
        story: story,
        frames: set.chains.single.ids.map(frameInput).toList(),
        fontSize: 10,
      );
      expect(result.hasOverflow, isFalse);
      expect(result.consumed, story.length);
      expect(result.allColumns.map((c) => c.visibleText).join(), story);
      expect(result.conserves(story), isTrue);
      // No terminal overflow when the story fits.
      expect(set.chains.single.terminalOverflowFrame(result), isNull);
    });

    test('chain order equals the explicit ordered-frame contract', () {
      final set = TextFlowLinkResolver.resolve(
        frameIds: {'a', 'b', 'c'},
        links: {'a': 'b', 'b': 'c'},
      );
      const story = 'XYZ';
      final viaChain = engine.flow(
        story: story,
        frames: set.chains.single.ids.map(frameInput).toList(),
        fontSize: 10,
      );
      final viaExplicit = engine.flow(
        story: story,
        frames: [frameInput('a'), frameInput('b'), frameInput('c')],
        fontSize: 10,
      );
      expect(
        viaChain.allColumns.map((c) => '${c.frameId}:${c.visibleText}'),
        viaExplicit.allColumns.map((c) => '${c.frameId}:${c.visibleText}'),
      );
    });
  });
}
