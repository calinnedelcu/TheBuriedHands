class_name RuntimeCollision
extends Node3D
## Gives every mesh below this node a trimesh collider at startup, unless it
## already has a StaticBody3D child. For imported models that came without
## collision.

func _ready() -> void:
	_add_collisions_recursive(self)

func _add_collisions_recursive(node: Node) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var already_has := false
		for c in mi.get_children():
			if c is StaticBody3D:
				already_has = true
				break
		if not already_has:
			var body := StaticBody3D.new()
			body.name = mi.name + "_col"
			mi.add_child(body)
			var shape := CollisionShape3D.new()
			var tri := mi.mesh.create_trimesh_shape()
			if tri is ConcavePolygonShape3D:
				(tri as ConcavePolygonShape3D).backface_collision = true
			shape.shape = tri
			body.add_child(shape)
	for c in node.get_children():
		_add_collisions_recursive(c)
