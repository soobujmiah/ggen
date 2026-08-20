import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:ggen_core/ggen_core.dart';

import '../storage/memory_project_store.dart';
import '../storage/memory_recovery_journal.dart';

/// App-layer controller that owns the current document project through the
/// platform-neutral `ggen_core` contracts.
///
/// The controller is deliberately widget-free: every mutation flows through
/// the core revision history or a core tool session, so undo/redo, bounds and
/// serialization semantics are exactly the tested core semantics. The shell
/// only observes [project] and triggers these methods.
///
/// Persistence goes through the core [TransactionalProjectStore] and
/// [AutosaveRecoveryJournal] contracts; the default adapters are in-memory
/// until a platform storage decision is accepted.
class StudioController extends ChangeNotifier {
  StudioController({
    String projectName = 'Untitled project',
    int historyLimit = 500,
    TransactionalProjectStore? store,
    AutosaveRecoveryJournal? journal,
    int checkpointEveryTransactions = 16,
  }) : _checkpointEveryTransactions = checkpointEveryTransactions,
       _store = store ?? MemoryProjectStore(),
       _journal =
           journal ??
           MemoryRecoveryJournal(
             AutosavePolicy(
               maxJournalEntries: 200,
               maxJournalBytes: 1 << 20,
               checkpointEveryTransactions: 16,
             ),
           ),
       _history = ProjectHistory.start(
         _newProject(projectName),
         maxEntries: historyLimit,
       );

  static const double defaultArtboardWidth = 1200;
  static const double defaultArtboardHeight = 800;

  /// Provisional checkpoint cadence until measured limits are approved.
  final int _checkpointEveryTransactions;

  final TransactionalProjectStore _store;
  final AutosaveRecoveryJournal _journal;

  ProjectHistory _history;
  String _lastSerialized = '';
  int _lastSerializedBytes = 0;
  int _journalSequence = 0;
  int _transactionsSinceCheckpoint = 0;
  ProjectStoreReceipt? _lastReceipt;

  DocumentProject get project => _history.current;
  int get revision => project.revision;
  int get maxHistoryEntries => _history.maxEntries;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  /// Last canonical serialization, kept for diagnostics and tests.
  String get lastSerialized => _lastSerialized;
  int get lastSerializedBytes => _lastSerializedBytes;

  /// Receipt of the last committed store write, or null before the first
  /// successful [save].
  ProjectStoreReceipt? get lastReceipt => _lastReceipt;

  /// Stable storage key for the current project. Derived from the project id
  /// so save and restore address the same slot.
  ProjectStorageKey get storageKey => ProjectStorageKey(project.id.value);

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
    _lastReceipt = null;
    notifyListeners();
  }

  /// Opens a reversible tool session against the current project snapshot.
  ProjectToolSession beginSession() => ProjectToolSession(project);

  /// Commits a session preview as exactly one undoable transaction and
  /// appends a bounded recovery-journal transaction record.
  void commitSession(ProjectToolSession session, String description) {
    final transaction = session.commit(description);
    _history = _history.commit(transaction);
    _journalRecord(transaction.before.revision, transaction.after.revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Cancels a session and restores the exact input project.
  void cancelSession(ProjectToolSession session) {
    session.cancel();
    notifyListeners();
  }

  /// Undoes one transaction and records a journal state marker so replay can
  /// reconstruct the resulting revision without a forward delta.
  void undo() {
    _history = _history.undo();
    _journalRecord(revision, revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Redoes one transaction and records a forward journal delta.
  void redo() {
    final revisionBefore = revision;
    _history = _history.redo();
    _journalRecord(revisionBefore, revision);
    _clearSerialized();
    notifyListeners();
  }

  /// Persists the current project through a transactional store write.
  ///
  /// Stages the canonical envelope, commits it atomically and returns the
  /// content-addressed receipt. A checkpoint record is appended to the
  /// recovery journal at the provisional cadence. Throws [StateError] when
  /// the store rejects a stale or non-advancing write.
  Future<ProjectStoreReceipt> save() async {
    final key = storageKey;
    final stored = await _store.read(key);
    final transaction = await _store.begin(
      key,
      expectedRevision: stored?.project.revision ?? -1,
    );
    final encoded = _encodeProject(project);
    await transaction.stage(
      ProjectEnvelope(
        project: project,
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      ),
    );
    final receipt = await transaction.commit();
    _lastReceipt = receipt;
    if (_transactionsSinceCheckpoint >= _checkpointEveryTransactions) {
      await _journalCheckpoint(encoded);
    }
    notifyListeners();
    return receipt;
  }

  /// Restores the project previously committed under [key].
  ///
  /// Returns false when the store has no committed project for the key; the
  /// current workspace is left untouched in that case.
  Future<bool> restore(ProjectStorageKey key) async {
    final envelope = await _store.read(key);
    if (envelope == null) return false;
    _history = ProjectHistory.start(
      envelope.project,
      maxEntries: maxHistoryEntries,
    );
    _clearSerialized();
    notifyListeners();
    return true;
  }

  /// Serializes the current envelope with the canonical bounded codec.
  ///
  /// Persistence to platform storage is a later milestone (the core storage
  /// contracts already exist); this keeps the canonical bytes available for
  /// diagnostics and tests.
  String serialize() {
    final encoded = _encodeProject(project);
    _lastSerialized = encoded;
    _lastSerializedBytes = utf8.encode(encoded).length;
    return encoded;
  }

  String _encodeProject(DocumentProject project) {
    final codec = ProjectCodec(limits: ProjectCodecLimits.conservative());
    return codec.encode(
      ProjectEnvelope(
        project: project,
        schemaVersion: ProjectSchemaVersion(ProjectSchemaVersion.current),
      ),
    );
  }

  /// Appends a recovery-journal transaction record for a history transition.
  ///
  /// Forward transitions (commit, redo) record a delta with base < target.
  /// Non-forward transitions (undo) record a state marker with base == target
  /// so replay can reconstruct the resulting revision directly.
  void _journalRecord(int baseRevision, int targetRevision) {
    final encoded = _encodeProject(project);
    _journalSequence++;
    unawaited(
      _journal.append(
        RecoveryJournalRecord(
          id: GgenId('txn-$_journalSequence'),
          projectId: project.id,
          kind: RecoveryRecordKind.transaction,
          sequence: _journalSequence,
          baseRevision: baseRevision,
          targetRevision: targetRevision,
          payloadSha256: _sha256Hex(encoded),
          payloadBytes: utf8.encode(encoded).length,
        ),
      ),
    );
    _transactionsSinceCheckpoint++;
  }

  Future<void> _journalCheckpoint(String encoded) async {
    _journalSequence++;
    await _journal.append(
      RecoveryJournalRecord(
        id: GgenId('cp-$_journalSequence'),
        projectId: project.id,
        kind: RecoveryRecordKind.checkpoint,
        sequence: _journalSequence,
        baseRevision: project.revision,
        targetRevision: project.revision,
        payloadSha256: _sha256Hex(encoded),
        payloadBytes: utf8.encode(encoded).length,
      ),
    );
    _transactionsSinceCheckpoint = 0;
  }

  static String _sha256Hex(String value) =>
      sha256.convert(utf8.encode(value)).toString();

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
