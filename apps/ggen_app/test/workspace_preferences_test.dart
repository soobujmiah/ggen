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

  group('fullscreen regions', () {
    test('defaults to an empty region map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(
        (await WorkspacePreferences.load()).fullscreenRegions,
        isEmpty,
      );
    });

    test('region map round-trips through save/load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await const WorkspacePreferences(
        fullscreenRegions: <String, List<String>>{
          'bottomRight': <String>['undo', 'zoomIn'],
          'topRight': <String>['save'],
        },
      ).save();
      final loaded = await WorkspacePreferences.load();
      expect(loaded.fullscreenRegions['bottomRight'], <String>['undo', 'zoomIn']);
      expect(loaded.fullscreenRegions['topRight'], <String>['save']);
    });

    test('empty map removes the stored key on save', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions':
            '{"bottomRight":["undo","zoomIn"]}',
      });
      await const WorkspacePreferences().save();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_regions'), isNull);
    });

    test('malformed JSON fails closed to an empty map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions': '{not json',
      });
      expect(
        (await WorkspacePreferences.load()).fullscreenRegions,
        isEmpty,
      );
    });

    test('non-string list entries are dropped', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions':
            '{"bottomRight":["undo", 42, "zoomIn"]}',
      });
      final loaded = await WorkspacePreferences.load();
      expect(loaded.fullscreenRegions['bottomRight'], <String>['undo', 'zoomIn']);
    });

    test('clear removes the region key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions': '{"bottomRight":["undo"]}',
      });
      await const WorkspacePreferences().clear();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_regions'), isNull);
    });
  });
}
