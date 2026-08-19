import 'dart:collection';

import '../document/document_model.dart';

/// One already-computed reversible semantic transaction.
final class ProjectTransaction {
  ProjectTransaction({
    required String description,
    required this.before,
    required this.after,
  }) : description = _validateDescription(description) {
    if (before.id != after.id) {
      throw ArgumentError('A transaction cannot replace the project identity.');
    }
    if (after.revision != before.revision + 1) {
      throw ArgumentError(
        'After revision must be exactly before revision + 1.',
      );
    }
  }

  final String description;
  final DocumentProject before;
  final DocumentProject after;

  static String _validateDescription(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 256) {
      throw ArgumentError.value(
        value,
        'description',
        'Description must contain 1..256 characters.',
      );
    }
    return normalized;
  }
}

/// Immutable bounded undo/redo history.
final class ProjectHistory {
  ProjectHistory._({
    required this.current,
    required List<ProjectTransaction> undoStack,
    required List<ProjectTransaction> redoStack,
    required this.maxEntries,
  }) : undoStack = UnmodifiableListView<ProjectTransaction>(undoStack),
       redoStack = UnmodifiableListView<ProjectTransaction>(redoStack);

  factory ProjectHistory.start(
    DocumentProject project, {
    int maxEntries = 500,
  }) {
    if (maxEntries < 1 || maxEntries > 10000) {
      throw ArgumentError.value(
        maxEntries,
        'maxEntries',
        'History limit must be in 1..10000.',
      );
    }
    return ProjectHistory._(
      current: project,
      undoStack: const <ProjectTransaction>[],
      redoStack: const <ProjectTransaction>[],
      maxEntries: maxEntries,
    );
  }

  final DocumentProject current;
  final List<ProjectTransaction> undoStack;
  final List<ProjectTransaction> redoStack;
  final int maxEntries;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  ProjectHistory commit(ProjectTransaction transaction) {
    _requireCurrent(transaction.before);
    final nextUndo = <ProjectTransaction>[...undoStack, transaction];
    if (nextUndo.length > maxEntries) {
      nextUndo.removeRange(0, nextUndo.length - maxEntries);
    }
    return ProjectHistory._(
      current: transaction.after,
      undoStack: nextUndo,
      redoStack: const <ProjectTransaction>[],
      maxEntries: maxEntries,
    );
  }

  ProjectHistory undo() {
    if (!canUndo) {
      throw StateError('Nothing to undo.');
    }
    final transaction = undoStack.last;
    _requireCurrent(transaction.after);
    return ProjectHistory._(
      current: transaction.before,
      undoStack: undoStack.sublist(0, undoStack.length - 1),
      redoStack: <ProjectTransaction>[...redoStack, transaction],
      maxEntries: maxEntries,
    );
  }

  ProjectHistory redo() {
    if (!canRedo) {
      throw StateError('Nothing to redo.');
    }
    final transaction = redoStack.last;
    _requireCurrent(transaction.before);
    return ProjectHistory._(
      current: transaction.after,
      undoStack: <ProjectTransaction>[...undoStack, transaction],
      redoStack: redoStack.sublist(0, redoStack.length - 1),
      maxEntries: maxEntries,
    );
  }

  void _requireCurrent(DocumentProject expected) {
    if (current.id != expected.id || current.revision != expected.revision) {
      throw StateError(
        'Stale transaction: current ${current.id}@${current.revision}, '
        'expected ${expected.id}@${expected.revision}.',
      );
    }
  }
}
