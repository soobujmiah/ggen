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

  group('fullscreen clusters', () {
    test('defaults to an empty cluster map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(
        (await WorkspacePreferences.load()).fullscreenClusters,
        isEmpty,
      );
    });

    test('cluster map round-trips through save/load', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await const WorkspacePreferences(
        fullscreenClusters: <String, dynamic>{
          'clusters': <dynamic>[
            <String, dynamic>{
              'id': 'history',
              'x': 1.0,
              'y': 1.0,
              'controls': <dynamic>['undo', 'zoomIn'],
            },
          ],
        },
      ).save();
      final loaded = await WorkspacePreferences.load();
      final clusters = loaded.fullscreenClusters['clusters']! as List<dynamic>;
      expect(clusters, hasLength(1));
      final entry = clusters.single as Map<String, dynamic>;
      expect(entry['id'], 'history');
      expect(entry['x'], 1.0);
      expect(entry['controls'], <dynamic>['undo', 'zoomIn']);
    });

    test('empty map removes the stored key on save', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_clusters':
            '{"clusters":[{"id":"history","controls":["undo"]}]}',
      });
      await const WorkspacePreferences().save();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_clusters'), isNull);
    });

    test('malformed JSON fails closed to an empty map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_clusters': '{not json',
      });
      expect(
        (await WorkspacePreferences.load()).fullscreenClusters,
        isEmpty,
      );
    });

    test('non-map JSON fails closed to an empty map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_clusters': '[1, 2, 3]',
      });
      expect(
        (await WorkspacePreferences.load()).fullscreenClusters,
        isEmpty,
      );
    });

    test('clear removes the cluster key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_clusters': '{"clusters":[]}',
      });
      await const WorkspacePreferences().clear();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_clusters'), isNull);
    });
  });

  group('legacy fullscreen regions (migration)', () {
    test('legacy region key is still read on load for migration', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions':
            '{"bottomRight":["undo","zoomIn"]}',
      });
      final loaded = await WorkspacePreferences.load();
      expect(loaded.fullscreenRegions['bottomRight'], <String>['undo', 'zoomIn']);
      expect(loaded.fullscreenClusters, isEmpty);
    });

    test('legacy region key is removed on the next save', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions': '{"bottomRight":["undo"]}',
      });
      await const WorkspacePreferences().save();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_regions'), isNull);
    });

    test('malformed legacy JSON fails closed to an empty map', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions': '{not json',
      });
      expect(
        (await WorkspacePreferences.load()).fullscreenRegions,
        isEmpty,
      );
    });

    test('clear removes the legacy region key too', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'workspace.fullscreen_regions': '{"bottomRight":["undo"]}',
      });
      await const WorkspacePreferences().clear();
      final raw = await SharedPreferences.getInstance();
      expect(raw.getString('workspace.fullscreen_regions'), isNull);
    });
  });
}

