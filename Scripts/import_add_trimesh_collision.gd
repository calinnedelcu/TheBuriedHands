@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Node:
	_add_collision_recursive(scene, scene)
	return scene

func _add_collision_recursive(node: Node, owner_root: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var body := StaticBody3D.new()
		body.name = node.name + "_col"
		body.visible = false
		body.set_meta("generated_trimesh_collision", true)
		node.add_child(body)
		body.owner = owner_root

		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		shape.visible = false
		shape.set_meta("generated_trimesh_collision", true)
		shape.set("debug_color", Color(0.0, 0.0, 0.0, 0.0))
		body.add_child(shape)
		shape.owner = owner_root

	for child in node.get_children():
		_add_collision_recursive(child, owner_root)
