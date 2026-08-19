import 'dart:collection';

enum ToolStudio { document, vector, raster, painting, font, threeD, pdf }

enum ToolReleaseState {
  designed,
  implemented,
  buildVerified,
  deviceVerified,
  productionReady,
}

enum InputCapability { touch, stylus, mouse, keyboard }

enum ToolParameterKind { boolean, integer, decimal, text, color, choice }

enum ToolQualityGate {
  manualWithoutAi,
  exactNumericControl,
  nonDestructiveOrExplicitDestructive,
  undoRedoTransaction,
  cancellationAndSafeCleanup,
  progressiveNonBlockingPreview,
  autosaveAndCrashRecovery,
  typedParametersAndPresets,
  multiInputSpecification,
  accessibleAlternativeForEveryGesture,
  importExportFidelityReport,
  resourceLimitsAndAdmission,
  testsDocumentationAndEvidence,
  originalGgenUi,
}

final class ToolParameterDescriptor {
  ToolParameterDescriptor({
    required String id,
    required String label,
    required this.kind,
    required this.defaultValue,
    this.minimum,
    this.maximum,
    List<String> choices = const <String>[],
  }) : id = _identifier(id),
       label = _label(label),
       choices = List<String>.unmodifiable(choices) {
    if (minimum != null && maximum != null && minimum! > maximum!) {
      throw ArgumentError('Parameter minimum cannot exceed maximum.');
    }
    if (kind == ToolParameterKind.choice && choices.isEmpty) {
      throw ArgumentError('Choice parameters require at least one choice.');
    }
    if (kind != ToolParameterKind.choice && choices.isNotEmpty) {
      throw ArgumentError('Only choice parameters may declare choices.');
    }
    _validateDefault();
  }

  final String id;
  final String label;
  final ToolParameterKind kind;
  final Object defaultValue;
  final double? minimum;
  final double? maximum;
  final List<String> choices;

  void _validateDefault() {
    if (kind == ToolParameterKind.boolean && defaultValue is! bool) {
      throw ArgumentError('Boolean default required for $id.');
    }
    if (kind == ToolParameterKind.integer && defaultValue is! int) {
      throw ArgumentError('Integer default required for $id.');
    }
    if (kind == ToolParameterKind.decimal && defaultValue is! num) {
      throw ArgumentError('Numeric default required for $id.');
    }
    if ((kind == ToolParameterKind.text || kind == ToolParameterKind.color) &&
        defaultValue is! String) {
      throw ArgumentError('String default required for $id.');
    }
    if (kind == ToolParameterKind.choice &&
        (defaultValue is! String || !choices.contains(defaultValue))) {
      throw ArgumentError(
        'Choice default must be one of the declared choices for $id.',
      );
    }
    if (defaultValue is num) {
      final number = (defaultValue as num).toDouble();
      if (!number.isFinite ||
          (minimum != null && number < minimum!) ||
          (maximum != null && number > maximum!)) {
        throw ArgumentError(
          'Numeric default is outside the valid range for $id.',
        );
      }
    }
  }
}

/// Domain-level quality contract shared by phone, tablet and future desktop UI.
final class ToolDescriptor {
  ToolDescriptor({
    required String id,
    required this.version,
    required String name,
    required this.studio,
    required this.releaseState,
    required this.manualAvailable,
    required this.mobileFriendly,
    required Set<InputCapability> inputCapabilities,
    required Set<ToolQualityGate> qualityGates,
    required String documentationPath,
    List<ToolParameterDescriptor> parameters =
        const <ToolParameterDescriptor>[],
  }) : id = _identifier(id),
       name = _label(name),
       inputCapabilities = UnmodifiableSetView<InputCapability>(
         Set<InputCapability>.from(inputCapabilities),
       ),
       qualityGates = UnmodifiableSetView<ToolQualityGate>(
         Set<ToolQualityGate>.from(qualityGates),
       ),
       documentationPath = documentationPath.trim(),
       parameters = List<ToolParameterDescriptor>.unmodifiable(parameters) {
    if (version < 1) {
      throw ArgumentError.value(
        version,
        'version',
        'Version must be positive.',
      );
    }
    if (!manualAvailable) {
      throw ArgumentError('Every GGEN tool must work manually without AI.');
    }
    if (!mobileFriendly) {
      throw ArgumentError(
        'Every GGEN tool requires a mobile-friendly UI contract.',
      );
    }
    if (this.inputCapabilities.isEmpty) {
      throw ArgumentError('A tool must declare at least one input capability.');
    }
    if (this.documentationPath.isEmpty) {
      throw ArgumentError('A tool must link to documentation.');
    }
    final missing = mandatoryQualityGates.difference(this.qualityGates);
    if (missing.isNotEmpty) {
      throw ArgumentError('Tool is missing mandatory quality gates: $missing');
    }
    final parameterIds = <String>{};
    for (final parameter in this.parameters) {
      if (!parameterIds.add(parameter.id)) {
        throw ArgumentError('Duplicate tool parameter ID: ${parameter.id}');
      }
    }
  }

  static final Set<ToolQualityGate> mandatoryQualityGates =
      Set<ToolQualityGate>.unmodifiable(ToolQualityGate.values);

  final String id;
  final int version;
  final String name;
  final ToolStudio studio;
  final ToolReleaseState releaseState;
  final bool manualAvailable;
  final bool mobileFriendly;
  final Set<InputCapability> inputCapabilities;
  final Set<ToolQualityGate> qualityGates;
  final String documentationPath;
  final List<ToolParameterDescriptor> parameters;
}

String _identifier(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^[a-z][a-z0-9_.-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'id',
      'Use a lowercase stable identifier.',
    );
  }
  return normalized;
}

String _label(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 256) {
    throw ArgumentError.value(
      value,
      'label',
      'Label must contain 1..256 characters.',
    );
  }
  return normalized;
}
