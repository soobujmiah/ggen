import 'dart:collection';

import '../document/document_model.dart';

/// Version contract for the serialized universal project envelope.
final class ProjectSchemaVersion {
  ProjectSchemaVersion(int value) : value = _validate(value);

  static const int current = 1;

  final int value;

  static int _validate(int value) {
    if (value < 1 || value > 1000) {
      throw ArgumentError.value(
        value,
        'value',
        'Project schema version must be in 1..1000.',
      );
    }
    return value;
  }

  bool get isCurrent => value == current;

  @override
  bool operator ==(Object other) =>
      other is ProjectSchemaVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'v$value';
}

/// Platform-neutral project envelope. Serialization belongs to an adapter.
final class ProjectEnvelope {
  ProjectEnvelope({
    required this.project,
    required this.schemaVersion,
    Map<String, Object?> extensions = const <String, Object?>{},
  }) : extensions = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(extensions),
       ) {
    if (project.schemaVersion != schemaVersion.value) {
      throw ArgumentError(
        'Envelope schema must match the document project schema.',
      );
    }
  }

  final DocumentProject project;
  final ProjectSchemaVersion schemaVersion;
  final Map<String, Object?> extensions;
}
