import 'package:flutter_test/flutter_test.dart';
import 'package:ggen_app/workspace_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load defaults to null last project key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await WorkspacePreferences.load();
    expect(prefs.lastProjectKey, isNull);
    expect(prefs.inspectorVisible, isTrue);
    expect(prefs.canvasFirst, isTrue);
    expect(prefs.inspectorDock, 'right');
  });

  test('last project key round trips and clears', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await const WorkspacePreferences(lastProjectKey: 'project-1').save();
    final loaded = await WorkspacePreferences.load();
    expect(loaded.lastProjectKey, 'project-1');

    await const WorkspacePreferences().save();
    expect((await WorkspacePreferences.load()).lastProjectKey, isNull);
  });

  test('clear removes the last project key', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await const WorkspacePreferences(lastProjectKey: 'project-1').save();
    await const WorkspacePreferences().clear();
    expect((await WorkspacePreferences.load()).lastProjectKey, isNull);
  });

  test('empty stored value is treated as absent', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'workspace.last_project_key': '',
    });
    expect((await WorkspacePreferences.load()).lastProjectKey, isNull);
  });
}
