import 'package:ggen_core/ggen_core.dart';
import 'package:test/test.dart';

void main() {
  test('professional mobile-friendly tool accepts all mandatory gates', () {
    final tool = ToolDescriptor(
      id: 'vector.pen',
      version: 1,
      name: 'Pen',
      studio: ToolStudio.vector,
      releaseState: ToolReleaseState.designed,
      manualAvailable: true,
      mobileFriendly: true,
      inputCapabilities: <InputCapability>{
        InputCapability.touch,
        InputCapability.stylus,
        InputCapability.mouse,
        InputCapability.keyboard,
      },
      qualityGates: ToolDescriptor.mandatoryQualityGates,
      documentationPath: 'docs/tools/vector-pen.md',
      parameters: <ToolParameterDescriptor>[
        ToolParameterDescriptor(
          id: 'smoothing',
          label: 'Smoothing',
          kind: ToolParameterKind.decimal,
          defaultValue: 0.25,
          minimum: 0,
          maximum: 1,
        ),
      ],
    );

    expect(tool.manualAvailable, isTrue);
    expect(tool.mobileFriendly, isTrue);
    expect(tool.qualityGates, containsAll(ToolQualityGate.values));
  });

  test('demo-quality or desktop-only descriptors fail closed', () {
    expect(
      () => ToolDescriptor(
        id: 'raster.bad',
        version: 1,
        name: 'Bad tool',
        studio: ToolStudio.raster,
        releaseState: ToolReleaseState.designed,
        manualAvailable: true,
        mobileFriendly: false,
        inputCapabilities: <InputCapability>{InputCapability.mouse},
        qualityGates: ToolDescriptor.mandatoryQualityGates,
        documentationPath: 'docs/tools/bad.md',
      ),
      throwsArgumentError,
    );
    expect(
      () => ToolDescriptor(
        id: 'raster.incomplete',
        version: 1,
        name: 'Incomplete tool',
        studio: ToolStudio.raster,
        releaseState: ToolReleaseState.designed,
        manualAvailable: true,
        mobileFriendly: true,
        inputCapabilities: <InputCapability>{InputCapability.touch},
        qualityGates: <ToolQualityGate>{ToolQualityGate.manualWithoutAi},
        documentationPath: 'docs/tools/incomplete.md',
      ),
      throwsArgumentError,
    );
  });
}
