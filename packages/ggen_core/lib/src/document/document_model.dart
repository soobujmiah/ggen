import 'dart:collection';

/// Stable validated identifier used by persisted GGEN domain objects.
final class GgenId {
  GgenId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw ArgumentError.value(
        value,
        'value',
        'ID must contain 1..128 characters.',
      );
    }
    if (RegExp(r'[\x00-\x1F\x7F\s]').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'value',
        'ID cannot contain whitespace or controls.',
      );
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) => other is GgenId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum DocumentNodeKind {
  group,
  vectorPath,
  rasterLayer,
  textFrame,
  shape,
  table,
  image,
  mask,
  adjustment,
  componentInstance,
}

/// Minimal immutable node contract. Studio-specific payloads arrive in later schemas.
final class DocumentNode {
  DocumentNode({
    required this.id,
    required this.kind,
    required String name,
    this.visible = true,
    this.locked = false,
    this.opacity = 1.0,
    Map<String, Object?> extensions = const <String, Object?>{},
  }) : name = _validateName(name, 'node name'),
       extensions = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(extensions),
       ) {
    if (!opacity.isFinite || opacity < 0 || opacity > 1) {
      throw ArgumentError.value(
        opacity,
        'opacity',
        'Opacity must be finite in 0..1.',
      );
    }
  }

  final GgenId id;
  final DocumentNodeKind kind;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;
  final Map<String, Object?> extensions;
}

final class Artboard {
  Artboard({
    required this.id,
    required String name,
    required this.width,
    required this.height,
    List<DocumentNode> nodes = const <DocumentNode>[],
  }) : name = _validateName(name, 'artboard name'),
       nodes = List<DocumentNode>.unmodifiable(nodes) {
    _validateDimension(width, 'width');
    _validateDimension(height, 'height');
    _requireUniqueIds(nodes.map((DocumentNode node) => node.id), 'node');
  }

  final GgenId id;
  final String name;
  final double width;
  final double height;
  final List<DocumentNode> nodes;

  static void _validateDimension(double value, String label) {
    if (!value.isFinite || value <= 0 || value > 1000000) {
      throw ArgumentError.value(
        value,
        label,
        'Dimension must be finite in (0, 1,000,000].',
      );
    }
  }
}

/// Versioned immutable root of a GGEN document project.
final class DocumentProject {
  DocumentProject({
    required this.id,
    required String name,
    this.schemaVersion = 1,
    this.revision = 0,
    List<Artboard> artboards = const <Artboard>[],
  }) : name = _validateName(name, 'project name'),
       artboards = List<Artboard>.unmodifiable(artboards) {
    if (schemaVersion != 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'Only schema v1 is supported.',
      );
    }
    if (revision < 0) {
      throw ArgumentError.value(
        revision,
        'revision',
        'Revision cannot be negative.',
      );
    }
    _requireUniqueIds(
      artboards.map((Artboard artboard) => artboard.id),
      'artboard',
    );
  }

  final GgenId id;
  final String name;
  final int schemaVersion;
  final int revision;
  final List<Artboard> artboards;

  DocumentProject copyWith({
    String? name,
    int? revision,
    List<Artboard>? artboards,
  }) => DocumentProject(
    id: id,
    name: name ?? this.name,
    schemaVersion: schemaVersion,
    revision: revision ?? this.revision,
    artboards: artboards ?? this.artboards,
  );
}

String _validateName(String value, String label) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 256) {
    throw ArgumentError.value(
      value,
      label,
      'Name must contain 1..256 characters.',
    );
  }
  if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      label,
      'Name contains forbidden control characters.',
    );
  }
  return normalized;
}

void _requireUniqueIds(Iterable<GgenId> ids, String label) {
  final seen = <GgenId>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError('Duplicate $label ID: $id');
    }
  }
}
