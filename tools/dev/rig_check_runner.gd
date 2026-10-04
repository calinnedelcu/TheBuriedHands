extends Node
## Dev runner: compares skeleton bone names across character models and checks
## which bones translate horizontally in the walk/run animations (root motion).

const MODELS := ["res://TripoModels/samurai.glb", "res://TripoModels/ucenic.glb", "res://TripoModels/monk.glb", "res://TripoModels/mester-mestesugar-real.glb"]

func _ready() -> void:
	var first: PackedStringArray
	for path in MODELS:
		var n: Node = (load(path) as PackedScene).instantiate()
		var skel: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var names := PackedStringArray()
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
		if first.is_empty():
			first = names
			print("bones: ", names)
		print(path.get_file(), " same_rig=", names == first, " root_parent_bones=", [skel.get_bone_name(0)])
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		for anim_name in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			for t in anim.get_track_count():
				if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
					continue
				var keys := anim.track_get_key_count(t)
				if keys < 2:
					continue
				var a: Vector3 = anim.track_get_key_value(t, 0)
				var b: Vector3 = anim.track_get_key_value(t, keys - 1)
				var span := Vector2(b.x - a.x, b.z - a.z).length()
				if span > 0.05:
					print("   %s track %s moves %.2f horizontally (%s -> %s)" % [anim_name, anim.track_get_path(t), span, a, b])
		n.free()
	get_tree().quit()
