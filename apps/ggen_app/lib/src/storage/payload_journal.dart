import 'package:ggen_core/ggen_core.dart';

/// Journals that can durably associate the canonical JSON payload with a
/// recovery record, so replay can reconstruct the project.
///
/// The core [AutosaveRecoveryJournal] contract carries only record metadata
/// (id, revisions, digest, byte size); payload association is the adapter's
/// responsibility. This app-layer extension gives both the in-memory and
/// file-backed journals a uniform way to store the payload bytes that the
/// record's digest was computed over.
abstract interface class PayloadJournal {
  /// Stores the canonical JSON [canonicalJson] for [recordId] of
  /// [projectId].
  void storePayload(GgenId projectId, GgenId recordId, String canonicalJson);

  /// Returns the most recently stored payload for [projectId], decoded.
  ProjectEnvelope? latestPayload(GgenId projectId);
}
