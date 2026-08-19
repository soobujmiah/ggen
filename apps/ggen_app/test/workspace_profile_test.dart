import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/workspace_profile.dart';

void main() {
  test('workspace profiles round trip with bounded values', () {
    const profile = WorkspaceProfile(name: '  Studio  ', inspectorVisible: false, canvasFirst: true, inspectorDock: 'left');
    final decoded = WorkspaceProfile.decode(profile.encode());
    expect(decoded.name, 'Studio');
    expect(decoded.inspectorVisible, isFalse);
    expect(decoded.canvasFirst, isTrue);
    expect(decoded.inspectorDock, 'left');
  });

  test('unknown dock values fail closed to right', () {
    final profile = WorkspaceProfile.fromJson({'name': 'x', 'inspector_dock': 'unknown'});
    expect(profile.inspectorDock, 'right');
  });
}
