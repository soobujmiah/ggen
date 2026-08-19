import 'dart:collection';

import '../tools/tool_contract.dart';

enum InputAxis { pressure, tilt, azimuth, rotation, velocity }

enum NormalizedInputEventKind {
  down,
  move,
  up,
  cancel,
  hover,
  scroll,
  keyDown,
  keyUp,
}

/// Declares capabilities reported by the platform, never guessed by a tool.
final class AdaptiveInputContract {
  AdaptiveInputContract({
    required Set<InputCapability> availableCapabilities,
    required Set<InputAxis> reportedAxes,
    required Set<String> commandAlternatives,
    required this.numericInspectorAvailable,
    required this.commandPaletteAvailable,
  }) : availableCapabilities = UnmodifiableSetView<InputCapability>(
         Set<InputCapability>.from(availableCapabilities),
       ),
       reportedAxes = UnmodifiableSetView<InputAxis>(
         Set<InputAxis>.from(reportedAxes),
       ),
       commandAlternatives = UnmodifiableSetView<String>(
         commandAlternatives.map(_commandId).toSet(),
       ) {
    if (this.availableCapabilities.isEmpty) {
      throw ArgumentError('An input contract needs at least one capability.');
    }
    if (this.commandAlternatives.isEmpty) {
      throw ArgumentError(
        'Every gesture surface needs a discoverable command alternative.',
      );
    }
    if (!numericInspectorAvailable || !commandPaletteAvailable) {
      throw ArgumentError(
        'Professional input contracts require numeric precision and a command palette.',
      );
    }
    if (this.reportedAxes.contains(InputAxis.pressure) &&
        !this.availableCapabilities.contains(InputCapability.stylus)) {
      throw ArgumentError(
        'Pressure can only be reported by a stylus-capable input.',
      );
    }
    if (this.reportedAxes.contains(InputAxis.tilt) &&
        !this.availableCapabilities.contains(InputCapability.stylus)) {
      throw ArgumentError(
        'Tilt can only be reported by a stylus-capable input.',
      );
    }
  }

  final Set<InputCapability> availableCapabilities;
  final Set<InputAxis> reportedAxes;
  final Set<String> commandAlternatives;
  final bool numericInspectorAvailable;
  final bool commandPaletteAvailable;

  bool supports(InputCapability capability) =>
      availableCapabilities.contains(capability);

  bool reports(InputAxis axis) => reportedAxes.contains(axis);
}

final class NormalizedInputEvent {
  NormalizedInputEvent({
    required this.kind,
    required this.contract,
    required this.x,
    required this.y,
    required this.timestampMicros,
    this.pressure,
    this.tiltX,
    this.tiltY,
    this.azimuth,
    this.rotation,
    this.velocity,
    Set<int> buttons = const <int>{},
  }) : buttons = UnmodifiableSetView<int>(Set<int>.from(buttons)) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Normalized input coordinates must be finite.');
    }
    if (timestampMicros < 0) {
      throw ArgumentError.value(
        timestampMicros,
        'timestampMicros',
        'Input timestamps cannot be negative.',
      );
    }
    for (final button in this.buttons) {
      if (button < 0 || button > 31) {
        throw ArgumentError.value(
          button,
          'buttons',
          'Button IDs must be in 0..31.',
        );
      }
    }
    _axis(
      value: pressure,
      axis: InputAxis.pressure,
      label: 'pressure',
      minimum: 0,
      maximum: 1,
    );
    _axis(value: tiltX, axis: InputAxis.tilt, label: 'tiltX');
    _axis(value: tiltY, axis: InputAxis.tilt, label: 'tiltY');
    _axis(value: azimuth, axis: InputAxis.azimuth, label: 'azimuth');
    _axis(value: rotation, axis: InputAxis.rotation, label: 'rotation');
    _axis(value: velocity, axis: InputAxis.velocity, label: 'velocity');
  }

  final NormalizedInputEventKind kind;
  final AdaptiveInputContract contract;
  final double x;
  final double y;
  final int timestampMicros;
  final double? pressure;
  final double? tiltX;
  final double? tiltY;
  final double? azimuth;
  final double? rotation;
  final double? velocity;
  final Set<int> buttons;

  void _axis({
    required double? value,
    required InputAxis axis,
    required String label,
    double? minimum,
    double? maximum,
  }) {
    if (value == null) {
      return;
    }
    if (!contract.reports(axis)) {
      throw ArgumentError(
        '$label was supplied although the platform did not report $axis.',
      );
    }
    if (!value.isFinite ||
        (minimum != null && value < minimum) ||
        (maximum != null && value > maximum)) {
      throw ArgumentError.value(value, label, 'Input axis value is invalid.');
    }
  }
}

String _commandId(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^[a-z][a-z0-9_.-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'commandAlternatives',
      'Command alternatives must use lowercase stable IDs.',
    );
  }
  return normalized;
}
