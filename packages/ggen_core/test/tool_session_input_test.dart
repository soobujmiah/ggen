import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  DocumentProject project({String name = 'Before', int revision = 0}) =>
      DocumentProject(
        id: GgenId('project.session'),
        name: name,
        revision: revision,
      );

  AdaptiveInputContract touchContract() => AdaptiveInputContract(
    availableCapabilities: <InputCapability>{InputCapability.touch},
    reportedAxes: <InputAxis>{},
    commandAlternatives: <String>{'canvas.pan', 'canvas.zoom'},
    numericInspectorAvailable: true,
    commandPaletteAvailable: true,
  );

  test('tool preview commits one reversible transaction', () {
    final session = ProjectToolSession(project());
    session.updatePreview(project(name: 'Preview'));
    final transaction = session.commit('Rename project');

    expect(session.state, ToolSessionState.committed);
    expect(transaction.before.name, 'Before');
    expect(transaction.after.name, 'Preview');
    expect(transaction.before.revision, 0);
    expect(transaction.after.revision, 1);
    expect(
      () => session.updatePreview(project(name: 'Too late')),
      throwsStateError,
    );
  });

  test('cancel restores the exact input and prevents commit', () {
    final input = project();
    final session = ProjectToolSession(input);
    session.updatePreview(project(name: 'Temporary'));
    session.cancel();

    expect(session.state, ToolSessionState.cancelled);
    expect(session.preview, same(input));
    expect(() => session.commit('Cancelled change'), throwsStateError);
    session.cancel();
    expect(session.state, ToolSessionState.cancelled);
  });

  test('preview cannot change identity or committed revision', () {
    final session = ProjectToolSession(project());
    expect(
      () => session.updatePreview(
        DocumentProject(id: GgenId('other.project'), name: 'Other'),
      ),
      throwsStateError,
    );
    expect(() => session.updatePreview(project(revision: 1)), throwsStateError);
  });

  test('adaptive input declares alternatives and reported axes', () {
    final contract = touchContract();
    expect(contract.supports(InputCapability.touch), isTrue);
    expect(contract.reports(InputAxis.pressure), isFalse);
    final event = NormalizedInputEvent(
      kind: NormalizedInputEventKind.down,
      contract: contract,
      x: 12,
      y: 24,
      timestampMicros: 100,
    );
    expect(event.buttons, isEmpty);
    expect(
      () => AdaptiveInputContract(
        availableCapabilities: <InputCapability>{InputCapability.touch},
        reportedAxes: <InputAxis>{InputAxis.pressure},
        commandAlternatives: <String>{'canvas.pan'},
        numericInspectorAvailable: true,
        commandPaletteAvailable: true,
      ),
      throwsArgumentError,
    );
  });

  test(
    'unsupported pressure or invalid axis values fail instead of being guessed',
    () {
      final contract = touchContract();
      expect(
        () => NormalizedInputEvent(
          kind: NormalizedInputEventKind.move,
          contract: contract,
          x: 0,
          y: 0,
          timestampMicros: 1,
          pressure: 0.5,
        ),
        throwsArgumentError,
      );
      final stylus = AdaptiveInputContract(
        availableCapabilities: <InputCapability>{InputCapability.stylus},
        reportedAxes: <InputAxis>{InputAxis.pressure, InputAxis.tilt},
        commandAlternatives: <String>{'brush.size'},
        numericInspectorAvailable: true,
        commandPaletteAvailable: true,
      );
      expect(
        () => NormalizedInputEvent(
          kind: NormalizedInputEventKind.move,
          contract: stylus,
          x: 0,
          y: 0,
          timestampMicros: 1,
          pressure: 1.1,
        ),
        throwsArgumentError,
      );
      final valid = NormalizedInputEvent(
        kind: NormalizedInputEventKind.move,
        contract: stylus,
        x: 0,
        y: 0,
        timestampMicros: 1,
        pressure: 0.5,
        tiltX: 0.1,
        tiltY: -0.1,
      );
      expect(valid.pressure, 0.5);
    },
  );
}
