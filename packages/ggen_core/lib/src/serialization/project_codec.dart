import 'dart:collection';
import 'dart:convert';

import '../document/document_model.dart';
import '../project/project_contract.dart';

enum ProjectSchemaDisposition { current, migrationRequired, unsupported }

/// Finite limits for project JSON parsing and writing.
final class ProjectCodecLimits {
  ProjectCodecLimits({
    required this.maxJsonBytes,
    required this.maxArtboards,
    required this.maxNodesPerArtboard,
    required this.maxCollectionItems,
    required this.maxJsonDepth,
    required this.maxStringLength,
  }) {
    if (maxJsonBytes < 1 || maxJsonBytes > (1 << 26)) {
      throw ArgumentError.value(
        maxJsonBytes,
        'maxJsonBytes',
        'JSON limit must be in 1..67,108,864 bytes.',
      );
    }
    if (maxArtboards < 1 || maxArtboards > 100000) {
      throw ArgumentError.value(
        maxArtboards,
        'maxArtboards',
        'Artboard limit must be in 1..100,000.',
      );
    }
    if (maxNodesPerArtboard < 1 || maxNodesPerArtboard > 1000000) {
      throw ArgumentError.value(
        maxNodesPerArtboard,
        'maxNodesPerArtboard',
        'Node limit must be in 1..1,000,000.',
      );
    }
    if (maxCollectionItems < 1 || maxCollectionItems > 1000000) {
      throw ArgumentError.value(
        maxCollectionItems,
        'maxCollectionItems',
        'Collection limit must be in 1..1,000,000.',
      );
    }
    if (maxJsonDepth < 1 || maxJsonDepth > 256) {
      throw ArgumentError.value(
        maxJsonDepth,
        'maxJsonDepth',
        'JSON depth limit must be in 1..256.',
      );
    }
    if (maxStringLength < 1 || maxStringLength > (1 << 24)) {
      throw ArgumentError.value(
        maxStringLength,
        'maxStringLength',
        'String limit must be in 1..16,777,216 characters.',
      );
    }
  }

  final int maxJsonBytes;
  final int maxArtboards;
  final int maxNodesPerArtboard;
  final int maxCollectionItems;
  final int maxJsonDepth;
  final int maxStringLength;

  factory ProjectCodecLimits.conservative() => ProjectCodecLimits(
    maxJsonBytes: 4 * 1024 * 1024,
    maxArtboards: 1000,
    maxNodesPerArtboard: 100000,
    maxCollectionItems: 100000,
    maxJsonDepth: 32,
    maxStringLength: 65536,
  );
}

/// Schema policy deliberately rejects old/future data until an explicit
/// migration is registered and tested.
final class ProjectSchemaReadPolicy {
  ProjectSchemaReadPolicy({
    required int currentVersion,
    Set<int> migrationRequiredFrom = const <int>{},
  }) : currentVersion = _version(currentVersion),
       migrationRequiredFrom = UnmodifiableSetView<int>(
         Set<int>.from(migrationRequiredFrom),
       ) {
    if (this.migrationRequiredFrom.any((int value) => value < 1)) {
      throw ArgumentError('Migration source versions must be positive.');
    }
    if (this.migrationRequiredFrom.contains(this.currentVersion)) {
      throw ArgumentError('The current schema cannot require migration.');
    }
  }

  factory ProjectSchemaReadPolicy.currentOnly() =>
      ProjectSchemaReadPolicy(currentVersion: ProjectSchemaVersion.current);

  final int currentVersion;
  final Set<int> migrationRequiredFrom;

  ProjectSchemaDisposition dispositionFor(int version) {
    if (version == currentVersion) {
      return ProjectSchemaDisposition.current;
    }
    if (migrationRequiredFrom.contains(version)) {
      return ProjectSchemaDisposition.migrationRequired;
    }
    return ProjectSchemaDisposition.unsupported;
  }

  void requireCurrent(int version) {
    switch (dispositionFor(version)) {
      case ProjectSchemaDisposition.current:
        return;
      case ProjectSchemaDisposition.migrationRequired:
        throw StateError(
          'Project schema v$version requires an explicit tested migration '
          'to v$currentVersion.',
        );
      case ProjectSchemaDisposition.unsupported:
        throw FormatException(
          'Unsupported project schema v$version; current is v$currentVersion.',
        );
    }
  }

  static int _version(int value) {
    if (value < 1 || value > 1000) {
      throw ArgumentError.value(
        value,
        'currentVersion',
        'Current schema version must be in 1..1000.',
      );
    }
    return value;
  }
}

/// Canonical JSON codec for the current platform-neutral project envelope.
final class ProjectCodec {
  ProjectCodec({required this.limits, ProjectSchemaReadPolicy? schemaPolicy})
    : schemaPolicy = schemaPolicy ?? ProjectSchemaReadPolicy.currentOnly();

  static const String format = 'ggen.project';

  final ProjectCodecLimits limits;
  final ProjectSchemaReadPolicy schemaPolicy;

  String encode(ProjectEnvelope envelope) {
    if (envelope.schemaVersion.value != schemaPolicy.currentVersion ||
        !envelope.schemaVersion.isCurrent) {
      throw StateError(
        'Only the current project schema can be written; explicit migration '
        'is required first.',
      );
    }
    _validateProjectShape(envelope.project);
    final root = <String, Object?>{
      'format': format,
      'schemaVersion': envelope.schemaVersion.value,
      'project': _projectToJson(envelope.project),
      'extensions': _canonicalJson(envelope.extensions, 'root.extensions'),
    };
    final encoded = jsonEncode(_canonicalJson(root, 'root'));
    _requireJsonBytes(encoded);
    return encoded;
  }

  ProjectEnvelope decode(String source) {
    _requireJsonBytes(source);
    final decoded = jsonDecode(source);
    final root = _map(decoded, 'root');
    _requireKeys(
      root,
      required: <String>{'format', 'schemaVersion', 'project', 'extensions'},
      context: 'root',
    );
    if (_string(root['format'], 'root.format') != format) {
      throw FormatException('Unsupported project format.');
    }
    final schemaVersion = _integer(root['schemaVersion'], 'root.schemaVersion');
    schemaPolicy.requireCurrent(schemaVersion);
    final project = _projectFromJson(root['project'], schemaVersion);
    final extensions = _extensions(root['extensions'], 'root.extensions');
    return ProjectEnvelope(
      project: project,
      schemaVersion: ProjectSchemaVersion(schemaVersion),
      extensions: extensions,
    );
  }

  Map<String, Object?> _projectToJson(DocumentProject project) {
    if (project.artboards.length > limits.maxArtboards) {
      throw ArgumentError('Project contains too many artboards.');
    }
    return <String, Object?>{
      'id': project.id.value,
      'name': project.name,
      'schemaVersion': project.schemaVersion,
      'revision': project.revision,
      'artboards': <Object?>[
        for (final artboard in project.artboards) _artboardToJson(artboard),
      ],
    };
  }

  Map<String, Object?> _artboardToJson(Artboard artboard) {
    if (artboard.nodes.length > limits.maxNodesPerArtboard) {
      throw ArgumentError('Artboard contains too many nodes.');
    }
    return <String, Object?>{
      'id': artboard.id.value,
      'name': artboard.name,
      'width': artboard.width,
      'height': artboard.height,
      'nodes': <Object?>[for (final node in artboard.nodes) _nodeToJson(node)],
    };
  }

  Map<String, Object?> _nodeToJson(DocumentNode node) => <String, Object?>{
    'id': node.id.value,
    'kind': _kindToWire(node.kind),
    'name': node.name,
    'visible': node.visible,
    'locked': node.locked,
    'opacity': node.opacity,
    'extensions': _canonicalJson(node.extensions, 'node.extensions'),
  };

  DocumentProject _projectFromJson(Object? value, int expectedSchemaVersion) {
    final map = _map(value, 'project');
    _requireKeys(
      map,
      required: <String>{
        'id',
        'name',
        'schemaVersion',
        'revision',
        'artboards',
      },
      context: 'project',
    );
    final schemaVersion = _integer(
      map['schemaVersion'],
      'project.schemaVersion',
    );
    if (schemaVersion != expectedSchemaVersion) {
      throw FormatException('Project and envelope schema versions differ.');
    }
    final artboards = _list(map['artboards'], 'project.artboards');
    if (artboards.length > limits.maxArtboards) {
      throw FormatException('Project contains too many artboards.');
    }
    return DocumentProject(
      id: GgenId(_string(map['id'], 'project.id')),
      name: _string(map['name'], 'project.name'),
      schemaVersion: schemaVersion,
      revision: _integer(map['revision'], 'project.revision'),
      artboards: <Artboard>[
        for (var index = 0; index < artboards.length; index++)
          _artboardFromJson(artboards[index], 'project.artboards[$index]'),
      ],
    );
  }

  Artboard _artboardFromJson(Object? value, String context) {
    final map = _map(value, context);
    _requireKeys(
      map,
      required: <String>{'id', 'name', 'width', 'height', 'nodes'},
      context: context,
    );
    final nodes = _list(map['nodes'], '$context.nodes');
    if (nodes.length > limits.maxNodesPerArtboard) {
      throw FormatException('$context contains too many nodes.');
    }
    return Artboard(
      id: GgenId(_string(map['id'], '$context.id')),
      name: _string(map['name'], '$context.name'),
      width: _number(map['width'], '$context.width'),
      height: _number(map['height'], '$context.height'),
      nodes: <DocumentNode>[
        for (var index = 0; index < nodes.length; index++)
          _nodeFromJson(nodes[index], '$context.nodes[$index]'),
      ],
    );
  }

  DocumentNode _nodeFromJson(Object? value, String context) {
    final map = _map(value, context);
    _requireKeys(
      map,
      required: <String>{
        'id',
        'kind',
        'name',
        'visible',
        'locked',
        'opacity',
        'extensions',
      },
      context: context,
    );
    return DocumentNode(
      id: GgenId(_string(map['id'], '$context.id')),
      kind: _kindFromWire(_string(map['kind'], '$context.kind')),
      name: _string(map['name'], '$context.name'),
      visible: _boolean(map['visible'], '$context.visible'),
      locked: _boolean(map['locked'], '$context.locked'),
      opacity: _number(map['opacity'], '$context.opacity'),
      extensions: _extensions(map['extensions'], '$context.extensions'),
    );
  }

  void _validateProjectShape(DocumentProject project) {
    if (project.schemaVersion != schemaPolicy.currentVersion) {
      throw StateError(
        'Project schema does not match the active write policy.',
      );
    }
    if (project.artboards.length > limits.maxArtboards) {
      throw ArgumentError('Project contains too many artboards.');
    }
    for (final artboard in project.artboards) {
      if (artboard.nodes.length > limits.maxNodesPerArtboard) {
        throw ArgumentError('Artboard contains too many nodes.');
      }
      _canonicalJson(<String, Object?>{
        'name': artboard.name,
        'width': artboard.width,
        'height': artboard.height,
      }, 'artboard');
      for (final node in artboard.nodes) {
        _canonicalJson(node.extensions, 'node.extensions');
      }
    }
    _canonicalJson(project.name, 'project.name');
  }

  Object? _canonicalJson(Object? value, String context, [int depth = 0]) {
    if (depth > limits.maxJsonDepth) {
      throw ArgumentError('$context exceeds the JSON depth limit.');
    }
    if (value == null || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError('$context contains a non-finite number.');
      }
      return value;
    }
    if (value is num) {
      final number = value.toDouble();
      if (!number.isFinite) {
        throw ArgumentError('$context contains a non-finite number.');
      }
      return number;
    }
    if (value is String) {
      if (value.length > limits.maxStringLength) {
        throw ArgumentError('$context exceeds the string limit.');
      }
      return value;
    }
    if (value is List) {
      if (value.length > limits.maxCollectionItems) {
        throw ArgumentError('$context exceeds the collection limit.');
      }
      return <Object?>[
        for (var index = 0; index < value.length; index++)
          _canonicalJson(value[index], '$context[$index]', depth + 1),
      ];
    }
    if (value is Map) {
      if (value.length > limits.maxCollectionItems) {
        throw ArgumentError('$context exceeds the collection limit.');
      }
      final keys = <String>[];
      for (final key in value.keys) {
        if (key is! String) {
          throw ArgumentError('$context contains a non-string JSON key.');
        }
        if (key.length > limits.maxStringLength) {
          throw ArgumentError('$context contains an oversized JSON key.');
        }
        keys.add(key);
      }
      keys.sort();
      final result = <String, Object?>{};
      for (final key in keys) {
        result[key] = _canonicalJson(value[key], '$context.$key', depth + 1);
      }
      return result;
    }
    throw ArgumentError('$context contains a non-JSON value.');
  }

  Map<String, Object?> _extensions(Object? value, String context) {
    final map = _map(value, context);
    final canonical = _canonicalJson(map, context);
    return Map<String, Object?>.from(canonical! as Map);
  }

  Map<String, Object?> _map(Object? value, String context) {
    if (value is! Map) {
      throw FormatException('$context must be a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('$context contains a non-string key.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  List<Object?> _list(Object? value, String context) {
    if (value is! List) {
      throw FormatException('$context must be a JSON array.');
    }
    if (value.length > limits.maxCollectionItems) {
      throw FormatException('$context exceeds the collection limit.');
    }
    return List<Object?>.from(value);
  }

  void _requireKeys(
    Map<String, Object?> map, {
    required Set<String> required,
    required String context,
  }) {
    final allowed = required;
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('$context contains unknown field: $key.');
      }
    }
    for (final key in required) {
      if (!map.containsKey(key)) {
        throw FormatException('$context is missing field: $key.');
      }
    }
  }

  String _string(Object? value, String context) {
    if (value is! String || value.length > limits.maxStringLength) {
      throw FormatException('$context must be a bounded JSON string.');
    }
    return value;
  }

  bool _boolean(Object? value, String context) {
    if (value is! bool) {
      throw FormatException('$context must be a JSON boolean.');
    }
    return value;
  }

  int _integer(Object? value, String context) {
    if (value is! int) {
      throw FormatException('$context must be a JSON integer.');
    }
    return value;
  }

  double _number(Object? value, String context) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$context must be a finite JSON number.');
    }
    return value.toDouble();
  }

  void _requireJsonBytes(String source) {
    if (utf8.encode(source).length > limits.maxJsonBytes) {
      throw ArgumentError('Project JSON exceeds the byte limit.');
    }
  }

  String _kindToWire(DocumentNodeKind kind) {
    switch (kind) {
      case DocumentNodeKind.group:
        return 'group';
      case DocumentNodeKind.vectorPath:
        return 'vector_path';
      case DocumentNodeKind.rasterLayer:
        return 'raster_layer';
      case DocumentNodeKind.textFrame:
        return 'text_frame';
      case DocumentNodeKind.shape:
        return 'shape';
      case DocumentNodeKind.table:
        return 'table';
      case DocumentNodeKind.image:
        return 'image';
      case DocumentNodeKind.mask:
        return 'mask';
      case DocumentNodeKind.adjustment:
        return 'adjustment';
      case DocumentNodeKind.componentInstance:
        return 'component_instance';
    }
  }

  DocumentNodeKind _kindFromWire(String value) {
    switch (value) {
      case 'group':
        return DocumentNodeKind.group;
      case 'vector_path':
        return DocumentNodeKind.vectorPath;
      case 'raster_layer':
        return DocumentNodeKind.rasterLayer;
      case 'text_frame':
        return DocumentNodeKind.textFrame;
      case 'shape':
        return DocumentNodeKind.shape;
      case 'table':
        return DocumentNodeKind.table;
      case 'image':
        return DocumentNodeKind.image;
      case 'mask':
        return DocumentNodeKind.mask;
      case 'adjustment':
        return DocumentNodeKind.adjustment;
      case 'component_instance':
        return DocumentNodeKind.componentInstance;
      default:
        throw FormatException('Unknown document node kind: $value.');
    }
  }
}
