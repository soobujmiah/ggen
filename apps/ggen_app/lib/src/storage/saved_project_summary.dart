/// Lightweight summary of one saved project, produced by listing the
/// project store. Used by the "Open project" sheet so the user can discover
/// and open previously saved projects without any new persistence system.
class SavedProjectSummary {
  const SavedProjectSummary({
    required this.key,
    required this.name,
    required this.revision,
    required this.byteSize,
    required this.updatedAt,
  });

  /// Storage key (`ProjectStorageKey.value`) the project is saved under.
  final String key;

  /// Project name shown to the user.
  final String name;

  /// Revision the project was last saved at.
  final int revision;

  /// Size of the stored file/payload in bytes.
  final int byteSize;

  /// When the stored copy was last written.
  final DateTime updatedAt;
}

/// Optional capability implemented by the app's project-store adapters:
/// listing the saved projects the store currently holds. Adapters that do
/// not implement it are treated as having nothing to list (fail closed).
abstract interface class ProjectStoreListing {
  /// Returns the saved projects, most recently updated first. Entries that
  /// cannot be decoded safely (corrupt payload, invalid key) are skipped
  /// rather than surfaced — opening must never crash the app.
  Future<List<SavedProjectSummary>> listSavedProjects();
}
