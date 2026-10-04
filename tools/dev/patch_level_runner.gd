extends Node
## Applies small, idempotent fixes to scenes/level/mausoleum.tscn in place, so
## edits made in the editor are kept. Add a patch function, call it from _run.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/patch_level_runner.gd

const LEVEL := "res://scenes/level/mausoleum.tscn"

var root: Node3D
var _log: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	root = (load(LEVEL) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	get_tree().root.add_child(root)
	await get_tree().physics_frame
	_localize_drain()
	_zone_sound()
	_guard_torches()
	_apprentice_kiln()
	_chisel_under_bench()
	get_tree().root.remove_child(root)
	var packed := PackedScene.new()
	packed.pack(root)
	print("save err=", ResourceSaver.save(packed, LEVEL))
	for line in _log:
		print("  ", line)
	root.free()
	get_tree().quit()

## Makes `node` part of the level itself instead of an instance of its scene
## (the editor's "Make Local"), so children removed from it stay removed.
func _make_local(node: Node) -> void:
	node.scene_file_path = ""
	for c in node.find_children("*", "", true, false):
		c.owner = root

## The drain was an instance of the jam's squeeze-tunnel scene; its old
## interactable and audio nodes kept coming back. Keep only what DrainCrawl uses.
func _localize_drain() -> void:
	var drain := root.get_node_or_null("Drain")
	if drain == null:
		return
	if drain.scene_file_path != "":
		_make_local(drain)
	for n in ["SqueezeAudio", "GravelAudio", "StonesAudio", "CinematicAudio", "PassageGate/GateVisual", "CollapseBlocker/CollisionShape3D", "EntryBody/Interactable", "SqueezeFocus", "CollapseFocus"]:
		var c := drain.get_node_or_null(n)
		if c != null:
			c.get_parent().remove_child(c)
			c.free()
			_log.append("drain: removed " + n)
	for c in drain.find_children("*", "", true, false):
		var s := c.get_script() as Script
		if s != null and not s.resource_path.begins_with("res://Scripts/world") and not s.resource_path.begins_with("res://Scripts/interaction"):
			_log.append("drain: WARNING old script on %s: %s" % [drain.get_path_to(c), s.resource_path])

func _zone(name: String, centre: Vector3, size: Vector3) -> AtmosphereZone:
	var group := root.get_node("AtmosphereZones")
	var z := group.get_node_or_null(name) as AtmosphereZone
	if z != null:
		return z
	z = AtmosphereZone.new()
	z.name = name
	group.add_child(z)
	z.owner = root
	z.global_position = centre
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	z.add_child(cs)
	cs.owner = root
	_log.append("zone: added " + name)
	return z

## Music and ambience per zone (Music.TRACKS / Music.AMBIENCE).
func _zone_sound() -> void:
	var zones := root.get_node("AtmosphereZones")
	var ws := zones.get_node("Workshop") as AtmosphereZone
	ws.music = &"workshop"
	ws.music_until_flag = &"guards_hostile"
	(zones.get_node("Tunnels") as AtmosphereZone).music = &"silence"
	var hall := zones.get_node("MercuryHall") as AtmosphereZone
	hall.music = &"mercury"
	hall.ambience = &"mercury"
	(zones.get_node("Treasury") as AtmosphereZone).music = &"mercury"
	_zone("Archives", Vector3(16.0, 4.0, -30.0), Vector3(56.0, 14.0, 64.0)).music = &"archives"
	_zone("Corridor", Vector3(-10.0, 3.0, 15.0), Vector3(84.0, 10.0, 22.0)).music = &"archives"
	_log.append("zones: music and ambience set")

## Some patrols carry torches: moving light that shows where they are and
## lights up anyone near them.
func _guard_torches() -> void:
	for n in ["ArchiveGuard1", "ArchiveGuard3", "GuardEscort"]:
		var g := root.get_node_or_null("Guards/" + n) as Guard
		if g != null and not g.carries_torch:
			g.carries_torch = true
			_log.append("torch: " + n)

func _floor_at(p: Vector3) -> Vector3:
	var space := root.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 3.0, 1))
	return hit.position if not hit.is_empty() else p

## "Hide in the cold kiln": the apprentice's hiding spot is the mouth of the
## workshop kiln that isn't burning, and the lamp you may give him sits there
## with him (he faces out, the NPC models look along local +X).
func _apprentice_kiln() -> void:
	var ws := root.get_node("Rooms/01_TerracottaWorkshop")
	var spot := ws.get_node("ApprenticeHideSpot") as Marker3D
	spot.global_transform = Transform3D(Basis(Vector3.UP, 3.0 * PI / 4.0), _floor_at(Vector3(-34.4, 0.0, -6.6)))
	var lamp := spot.get_node_or_null("KilnLamp") as Node3D
	if lamp == null:
		lamp = (load("res://scenes/world/oil_lamp_prop.tscn") as PackedScene).instantiate() as Node3D
		lamp.name = "KilnLamp"
		spot.add_child(lamp)
		lamp.owner = root
	lamp.position = Vector3(0.35, 0.0, 0.8)
	var appr := ws.get_node("Apprentice")
	appr.set(&"lamp_prop_path", appr.get_path_to(lamp))
	_log.append("apprentice: hides in the cold kiln at %s" % spot.global_position.snapped(Vector3.ONE * 0.1))

## "The chisel rolled under the bench" — it was lying on the bench top. Put it
## on the floor half under the bench's north edge, on the open side (not in
## the narrow gap behind the apprentice's chair, where nobody fits).
func _chisel_under_bench() -> void:
	var chisel := root.get_node("Rooms/01_TerracottaWorkshop/FallenChisel") as Node3D
	var space := root.get_world_3d().direct_space_state
	var at := Vector3(-70.6, 0.9, -6.45)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1))
	if hit.is_empty():
		_log.append("chisel: WARNING no floor under " + str(at))
		return
	chisel.global_transform = Transform3D(Basis(Vector3.UP, 0.15), (hit.position as Vector3) + Vector3.UP * 0.02)
	_log.append("chisel: on the floor at %s" % chisel.global_position.snapped(Vector3.ONE * 0.01))
