import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ggen_core/ggen_core.dart';

/// App-layer controller that owns the current document project through the
/// platform-neutral `ggen_core` contracts.
///
/// The controller is deliberately widget-free: every mutation flows through
/// the core revision history or a core tool session, so undo/redo, bounds and
/// serialization semantics are exactly the tested core semantics. The shell
/// only observes [project] and triggers these methods.
class StudioController extends ChangeNotifier {
  StudioController({
    String projectName = 'Untitled project',
    int historyLimit = 500,
  }) : _history = ProjectHistory.start(
         _newProject(projectName),
         maxEntries: historyLimit,
       );

  static const double defaultArtboardWidth = 1200;
  static const double defaultArtboardHeight = 800;

  ProjectHistory _history;
  String _lastSerialized = '';
  int _lastSerializedBytes = 0;

  DocumentProject get project => _history.current;
  int get revision => project.revision;
  int get maxHistoryEntries => _history.maxEntries;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Last canonical serialization, kept for diagnostics and tests.
  String get lastSerialized => _lastSerialized;
  int get lastSerializedBytes => _lastSerializedBytes;

  /// Total node count across artboards, shown in the shell status bar.
  int get objectCount => project.artboards.fold<int>(
    0,
    (sum, artboard) => sum + artboard.nodes.length,
  );

  /// Replaces the whole project (New Project). Not undoable by design: the
  /// previous project leaves the workspace entirely.
  void newProject(String name) {
    _history = ProjectHistory.start(
      _newProject(name),
      maxEntries: maxHistoryEntries,
    );
    _clearSerialized();
    notifyListeners();
  }

  /// Opens a reversible tool session against the current project snapshot.
  ProjectToolSession beginSession() => ProjectToolSession(project);

  /// Commits a session preview as exactly one undoable transaction.
  void commitSession(ProjectToolSession session, String description) {
    _history = _history.commit(session.commit(description));
    _clearSerialized();
    notifyListeners();
  }

  /// Cancels a session and restores the exact input project.
  void cancelSession(ProjectToolSession session) {
    session.cancel();
    notifyListeners();
  }

  void undo() {
    _history = _history.undo();
    _clearSerialized();
    notifyListeners();
  }

  void redo() {
    _history = _history.redo();
    _clearSerialized();
    notifyListeners();
  }

  /// Serializes the current envelope with the canonical bounded codec.
  ///
  /// Persistence to platform storage is a later milestone (the core storage
  /// contracts already exist); this keeps the canonical bytes available for
  /// diagnostics and tests.
  String serialize() {
    final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
    final encoded = codec.encode(
      ProjectEnvelope(
        project: project,
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      ),
    );
    _lastSerialized = encoded;
    _lastSerializedBytes = utf8.encode(encoded).length;
    return encoded;
  }

  static DocumentProject _newProject(String name) => DocumentProject(
    id: GgenId('project-${DateTime.now().microsecondsSinceEpoch}'),
    name: name,
    artboards: <Artboard>[
      Artboard(
        id: GgenId('artboard-1'),
        name: 'Artboard 1',
        width: defaultArtboardWidth,
        height: defaultArtboardHeight,
      ),
    ],
  );

  void _clearSerialized() {
    _lastSerialized = '';
    _lastSerializedBytes = 0;
  }
}
