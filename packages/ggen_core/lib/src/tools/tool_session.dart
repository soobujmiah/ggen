import '../document/document_model.dart';
import '../history/project_history.dart';

enum ToolSessionState { previewing, committed, cancelled }

/// A tool preview is mutable session state; only commit creates a history item.
abstract interface class ToolSession {
  DocumentProject get inputSnapshot;

  DocumentProject get preview;

  ToolSessionState get state;

  void updatePreview(DocumentProject nextPreview);

  ProjectTransaction commit(String description);

  void cancel();
}

final class ProjectToolSession implements ToolSession {
  ProjectToolSession(DocumentProject input)
    : inputSnapshot = input,
      _preview = input;

  @override
  final DocumentProject inputSnapshot;

  DocumentProject _preview;
  ToolSessionState _state = ToolSessionState.previewing;

  @override
  DocumentProject get preview => _preview;

  @override
  ToolSessionState get state => _state;

  @override
  void updatePreview(DocumentProject nextPreview) {
    _ensurePreviewing();
    if (nextPreview.id != inputSnapshot.id ||
        nextPreview.revision != inputSnapshot.revision) {
      throw StateError(
        'A preview must retain the input project identity and revision.',
      );
    }
    _preview = nextPreview;
  }

  @override
  ProjectTransaction commit(String description) {
    _ensurePreviewing();
    final after = _preview.copyWith(revision: inputSnapshot.revision + 1);
    final transaction = ProjectTransaction(
      description: description,
      before: inputSnapshot,
      after: after,
    );
    _state = ToolSessionState.committed;
    return transaction;
  }

  @override
  void cancel() {
    if (_state == ToolSessionState.committed) {
      throw StateError('A committed tool session cannot be cancelled.');
    }
    _state = ToolSessionState.cancelled;
    _preview = inputSnapshot;
  }

  void _ensurePreviewing() {
    if (_state != ToolSessionState.previewing) {
      throw StateError('Tool session is no longer previewing.');
    }
  }
}
