@tool
extends Node3D

## Ascunde toate sferele de debug copiilor cand jocul ruleaza.
## In editor raman vizibile pentru a vedea unde patruleaza gardienii.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_hide_debug_meshes(self)

func _hide_debug_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child.name == "DebugSphere" or String(child.name).begins_with("DebugSphere")):
			(child as MeshInstance3D).visible = false
		_hide_debug_meshes(child)
