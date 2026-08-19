import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/workspace_profile.dart';
import 'package:ggen_app/workspace_profile_store.dart';

void main() {
  test('profile storage bounds serialized profile count', () {
    final profiles = List.generate(10, (index) => WorkspaceProfile(name: 'P$index', inspectorVisible: true, canvasFirst: true, inspectorDock: 'right'));
    final decoded = jsonDecode(WorkspaceProfileStore.encodeForTest(profiles)) as List<dynamic>;
    expect(decoded, hasLength(8));
  });
}
