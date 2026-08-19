import 'package:flutter/material.dart';

import 'workspace_profile.dart';
import 'workspace_profile_store.dart';

class ProfileManagerSheet extends StatefulWidget {
  const ProfileManagerSheet({required this.current, required this.onApply, super.key});
  final WorkspaceProfile current;
  final ValueChanged<WorkspaceProfile> onApply;

  @override
  State<ProfileManagerSheet> createState() => _ProfileManagerSheetState();
}

class _ProfileManagerSheetState extends State<ProfileManagerSheet> {
  final _store = WorkspaceProfileStore();
  late Future<List<WorkspaceProfile>> _profiles;

  @override
  void initState() { super.initState(); _profiles = _store.load(); }

  Future<void> _saveProfile() async {
    String name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save workspace profile'),
        content: TextField(autofocus: true, maxLength: 80, onChanged: (value) => name = value, decoration: const InputDecoration(labelText: 'Profile name')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, name.trim()), child: const Text('Save'))],
      ),
    );
    name = result ?? name;
    if (!mounted || name.trim().isEmpty) return;
    final profiles = await _store.load();
    final next = [...profiles.where((p) => p.name != name), widget.current.copyWith(name: name.trim())];
    await _store.save(next);
    final refreshed = await _store.load();
    if (mounted) setState(() { _profiles = Future.value(refreshed); });
  }

  Future<void> _delete(WorkspaceProfile profile) async {
    final profiles = await _store.load();
    await _store.save(profiles.where((p) => p.name != profile.name).toList());
    final refreshed = await _store.load();
    if (mounted) setState(() { _profiles = Future.value(refreshed); });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Workspace profiles', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Save and restore panel, canvas-first, and dock preferences.'),
            const SizedBox(height: 12),
            Flexible(child: FutureBuilder<List<WorkspaceProfile>>(future: _profiles, builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) return const Text('No saved profiles yet.');
              return ListView(shrinkWrap: true, children: snapshot.data!.map((profile) => ListTile(
                title: Text(profile.name),
                subtitle: Text('${profile.inspectorDock} dock  •  ${profile.canvasFirst ? 'canvas-first' : 'panel-first'}'),
                onTap: () { widget.onApply(profile); Navigator.pop(context); },
                trailing: IconButton(tooltip: 'Delete profile', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(profile)),
              )).toList());
            })),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _saveProfile, icon: const Icon(Icons.save_outlined), label: const Text('Save current workspace')),
          ]),
        ),
      );
}
