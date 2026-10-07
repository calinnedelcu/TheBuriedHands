extends Node
## Lists the level geometry that pokes into spaces built from the level kit:
## a LevelBox's inside and its walls (they are thick outward, and only the
## inner faces are drawn, so a wall inside an old room is an invisible one), a
## LevelSolid, a LevelRamp. New rooms go where this prints nothing.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/overlap_check_runner.gd [--group=UnderTheMountain]

const LEVEL := "res://scenes/level/mausoleum.tscn"
## Groups built from the kit: their own pieces may touch each other.
const KIT_GROUPS := ["ServiceTunnels", "UnderTheMountain"]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--group="):
			only = arg.substr(8)
	var root := (load(LEVEL) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(root)
	for i in 4:
		await get_tree().physics_frame
	var exclude: Array[RID] = []
	for g in KIT_GROUPS:
		var group := root.get_node_or_null(g)
		if group == null:
			continue
		for c in group.find_children("*", "CollisionObject3D", true, false):
			exclude.append((c as CollisionObject3D).get_rid())
	var space := root.get_world_3d().direct_space_state
	var problems := 0
	for g in KIT_GROUPS:
		if only != "" and g != only:
			continue
		var group := root.get_node_or_null(g)
		if group == null:
			continue
		for piece in group.get_children():
			var volumes := _volumes(piece)
			for v in volumes:
				var hits := _query(space, piece as Node3D, v[0], v[1], exclude)
				for h in hits:
					problems += 1
					print("%s/%s (%s): %s" % [g, piece.name, v[2], h])
	print("overlap check: %d problem(s)" % problems)
	root.queue_free()
	get_tree().quit()

## [size, centre (local), label] boxes to test for a kit piece, shrunk a
## little so pieces that only touch don't count.
func _volumes(piece: Node) -> Array:
	var shrink := Vector3.ONE * 0.1
	if piece is LevelBox:
		var b := piece as LevelBox
		var t := b.thickness
		return [
			[b.size - shrink, Vector3(0, b.size.y * 0.5, 0), "inside"],
			[b.size + Vector3(t, t, t) * 2.0 - shrink, Vector3(0, b.size.y * 0.5, 0), "walls"],
		]
	if piece is LevelSolid:
		var s := piece as LevelSolid
		return [[s.size - shrink, Vector3(0, s.size.y * 0.5, 0), "solid"]]
	if piece is LevelRamp:
		var r := piece as LevelRamp
		return [[Vector3(r.width, r.rise, r.run) - shrink, Vector3(0, r.rise * 0.5, -r.run * 0.5), "ramp"]]
	return []

func _query(space: PhysicsDirectSpaceState3D, piece: Node3D, size: Vector3, centre: Vector3, exclude: Array[RID]) -> Array[String]:
	var box := BoxShape3D.new()
	box.size = size.max(Vector3.ONE * 0.05)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = piece.global_transform * Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = 1
	q.exclude = exclude
	var out: Array[String] = []
	var seen := {}
	for hit in space.intersect_shape(q, 32):
		var c := hit.get("collider") as Node
		if c == null or seen.has(c):
			continue
		seen[c] = true
		out.append(String(piece.get_tree().root.get_path_to(c)))
	return out
