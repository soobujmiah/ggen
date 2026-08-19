import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  DocumentProject project(String name, int revision) => DocumentProject(
    id: GgenId('project.history'),
    name: name,
    revision: revision,
  );

  test('commit undo and redo preserve exact revisions', () {
    final before = project('Before', 0);
    final after = project('After', 1);
    final transaction = ProjectTransaction(
      description: 'Rename project',
      before: before,
      after: after,
    );

    final committed = ProjectHistory.start(before).commit(transaction);
    expect(committed.current.name, 'After');
    expect(committed.canUndo, isTrue);

    final undone = committed.undo();
    expect(undone.current.name, 'Before');
    expect(undone.canRedo, isTrue);

    final redone = undone.redo();
    expect(redone.current.name, 'After');
  });

  test('stale transaction is rejected and new commit clears redo', () {
    final before = project('A', 0);
    final first = project('B', 1);
    final history = ProjectHistory.start(before).commit(
      ProjectTransaction(description: 'A to B', before: before, after: first),
    );

    expect(
      () => history.commit(
        ProjectTransaction(
          description: 'Stale change',
          before: before,
          after: project('Stale', 1),
        ),
      ),
      throwsStateError,
    );

    final undone = history.undo();
    final alternative = project('C', 1);
    final branched = undone.commit(
      ProjectTransaction(
        description: 'A to C',
        before: before,
        after: alternative,
      ),
    );
    expect(branched.canRedo, isFalse);
    expect(branched.current.name, 'C');
  });
}
