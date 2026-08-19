import 'dart:convert';

class WorkspaceProfile {
  const WorkspaceProfile({
    required this.name,
    required this.inspectorVisible,
    required this.canvasFirst,
    required this.inspectorDock,
  });

  final String name;
  final bool inspectorVisible;
  final bool canvasFirst;
  final String inspectorDock;

  WorkspaceProfile copyWith({String? name, bool? inspectorVisible, bool? canvasFirst, String? inspectorDock}) => WorkspaceProfile(
        name: name ?? this.name,
        inspectorVisible: inspectorVisible ?? this.inspectorVisible,
        canvasFirst: canvasFirst ?? this.canvasFirst,
        inspectorDock: inspectorDock ?? this.inspectorDock,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'inspector_visible': inspectorVisible,
        'canvas_first': canvasFirst,
        'inspector_dock': inspectorDock,
      };

  factory WorkspaceProfile.fromJson(Map<String, Object?> json) => WorkspaceProfile(
        name: (json['name'] as String? ?? 'Unnamed').trim().isEmpty ? 'Unnamed' : (json['name'] as String).trim().substring(0, ((json['name'] as String).trim().length).clamp(0, 80)),
        inspectorVisible: json['inspector_visible'] as bool? ?? true,
        canvasFirst: json['canvas_first'] as bool? ?? true,
        inspectorDock: json['inspector_dock'] == 'left' ? 'left' : 'right',
      );

  String encode() => jsonEncode(toJson());

  static WorkspaceProfile decode(String value) => WorkspaceProfile.fromJson(jsonDecode(value) as Map<String, Object?>);
}
