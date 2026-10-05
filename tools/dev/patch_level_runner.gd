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
	_remove_tunnel_lids()
	_tunnels_at_floor_level()
	_fix_ladders()
	_sconce_fixtures()
	_fill_from_the_sea()
	_causeway()
	_link_plates()
	_gentler_fumes()
	_performance()
	_chapters()
	_sealing_guards_closer()
	_statue_parts()
	_way_out()
	_tunnel_rock()
	_grave_goods()
	_workshop_at_work()
	_the_fallen()
	_miniature_empire()
	_apprentice_clips()
	_tunnel_timbers()
	_guard_variety()
	_close_mechanism_wall()
	_makers_names()
	_liang_seated()
	_the_coffin()
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

## The jam laid invisible boxes in the service tunnels at 2.25 m, under the
## tunnel's own ceiling (3.1-3.3 m). Too low to stand in, and their tops were
## walkable floors outside the level. The tunnel mesh's collision is enough.
func _remove_tunnel_lids() -> void:
	var lids := root.get_node_or_null("TunnelCeilingColliders")
	if lids == null:
		return
	lids.get_parent().remove_child(lids)
	lids.free()
	_log.append("tunnels: removed the jam's invisible ceilings")

## The tunnels' trigger and air sat on the jam's invisible lids (y -3); the
## real tunnel floor is at about -8.5.
func _tunnels_at_floor_level() -> void:
	var trig := root.get_node("Story/TunnelsEnter") as Node3D
	trig.global_position = Vector3(31.8, -7.2, -40.0)
	var zone := root.get_node("AtmosphereZones/Tunnels") as Node3D
	zone.global_position = Vector3(21.0, -7.0, -5.0)
	var box := (zone.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
	box.size = Vector3(62.0, 5.0, 100.0)
	_log.append("tunnels: trigger and air moved down to the tunnel floor")

## The ladders' tops never made it into the level (edits inside an instanced
## scene aren't saved), so all three were 4 m stubs. Tops from the jam's
## TopExit markers; landings on the nearest floor at the top with headroom.
func _fix_ladders() -> void:
	var tops := {
		"Mechanism/Ladder1": Vector3(48.894, 0.835, -46.646),
		"Mechanism/Ladder2": Vector3(3.395, 12.81, 47.365),
		"Mechanism/Ladder3": Vector3(0.468, 7.81, 43.657),
	}
	var space := root.get_world_3d().direct_space_state
	for path in tops:
		var ladder := root.get_node(path) as ClimbLadder
		var top: Vector3 = tops[path]
		var landing := _landing_near(space, top, ladder.global_position)
		if landing == Vector3.INF:
			_log.append("ladder %s: WARNING no floor near the top %s" % [path.get_file(), top])
			continue
		ladder.top = ladder.to_local(top)
		ladder.landing = ladder.to_local(landing + Vector3.UP * 0.15)
		_log.append("ladder %s: %.1f m, top %s, landing %s" % [path.get_file(), top.y - ladder.global_position.y, top.snapped(Vector3.ONE * 0.01), landing.snapped(Vector3.ONE * 0.01)])

## Closest floor point around `top` (a ring of probes) with room to stand,
## preferring the side away from the ladder's foot.
func _landing_near(space: PhysicsDirectSpaceState3D, top: Vector3, foot: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_score := INF
	for r in [0.8, 1.2, 1.6, 2.0]:
		for i in 16:
			var a := TAU * i / 16.0
			var p: Vector3 = top + Vector3(sin(a), 0.0, cos(a)) * r
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 2.0, 1))
			if hit.is_empty():
				continue
			var f: Vector3 = hit.position
			if (hit.normal as Vector3).y < 0.7 or f.y < top.y - 1.2:
				continue
			var head := space.intersect_ray(PhysicsRayQueryParameters3D.create(f + Vector3.UP * 0.1, f + Vector3.UP * 2.9, 1))
			if not head.is_empty():
				continue
			var away := Vector2(f.x - foot.x, f.z - foot.z).length()
			var score: float = r - away * 0.25
			if score < best_score:
				best_score = score
				best = f
	return best

## Sconces in the level's model get a WallLamp for the flame and light; the
## lamp's own bracket would double up on them.
func _sconce_fixtures() -> void:
	var n := 0
	for wl in root.get_node("WallLamps").get_children():
		if wl is WallLamp and (wl as WallLamp).show_fixture:
			(wl as WallLamp).show_fixture = false
			n += 1
	if n > 0:
		_log.append("sconces: hid %d doubled brackets" % n)

## The jar was filled at two invisible spots, one only reachable by wading
## round the whole hall. Now any mercury in reach will do: a thin use volume
## lies just over the sea (the relief, standing higher, hides it elsewhere),
## so the jar fills from the edge at the foot of the stairs, or a river.
func _fill_from_the_sea() -> void:
	var fill := root.get_node("MercuryHall/FillPoint1") as Node3D
	var body := fill.get_node("UseBody") as StaticBody3D
	body.global_position = Vector3(-77.6, -0.15, 66.8)
	var shape := body.get_node("Shape") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(54.0, 0.3, 58.0)
	shape.shape = box
	shape.position = Vector3.ZERO
	var second := root.get_node_or_null("MercuryHall/FillPoint2")
	if second != null:
		second.get_parent().remove_child(second)
		second.free()
	_log.append("mercury: the whole sea fills the jar")

## Nothing joined the mechanism room's north platform to the south one (and
## the way to the treasury) across the balance pit. The counterweight now
## raises a stone causeway out of the mercury between the two scale pans.
func _causeway() -> void:
	var mech := root.get_node("Mechanism")
	var cw := mech.get_node_or_null("Causeway") as Node3D
	if cw == null:
		cw = (load("res://scenes/world/causeway.tscn") as PackedScene).instantiate() as Node3D
		cw.name = "Causeway"
		mech.add_child(cw)
		cw.owner = root
	# Raised, the deck's top is level with the platforms (7.45).
	cw.global_position = Vector3(-3.0, 7.1 - 5.8, 57.6)
	var counterweight := mech.get_node("Counterweight")
	# Typed array properties ignore plain arrays set through set().
	var gates: Array[NodePath] = [counterweight.get_path_to(cw)]
	counterweight.set(&"gate_paths", gates)
	var jet := root.get_node_or_null("MapWithoutTreasure/MercuryFlowingPoint")
	if jet != null:
		var jets: Array[NodePath] = [counterweight.get_path_to(jet)]
		counterweight.set(&"flow_paths", jets)
	# Lamps at both ends, so the rising stone can be seen in the dark pit.
	for spec in [["CausewayLampNW", Vector3(-4.6, 0.0, 49.6)], ["CausewayLampNE", Vector3(-1.4, 0.0, 49.6)], ["CausewayLampS", Vector3(-4.6, 0.0, 65.8)]]:
		var lamp := mech.get_node_or_null(spec[0]) as Node3D
		if lamp == null:
			lamp = (load("res://scenes/world/oil_lamp_prop.tscn") as PackedScene).instantiate() as Node3D
			lamp.name = spec[0]
			mech.add_child(lamp)
			lamp.owner = root
		lamp.global_position = _floor_at(spec[1] + Vector3.UP * 8.0)
	_log.append("causeway: across the balance pit, raised by the counterweight")

## The plates' links to their crossbows were set as plain arrays on a typed
## property and never saved: no plate fired. Plate N fires Crossbow N.
func _link_plates() -> void:
	var traps := root.get_node("CorridorTraps")
	var n := 0
	for i in range(1, 10):
		var plate := traps.get_node_or_null("Plate%d" % i)
		var bow := traps.get_node_or_null("Crossbow%d" % i)
		if plate == null or bow == null:
			continue
		var links: Array[NodePath] = [plate.get_path_to(bow)]
		plate.set(&"crossbow_paths", links)
		n += 1
	_log.append("corridor: %d plates linked to their crossbows" % n)

## The fumes filled the whole mechanism room and treasury at a strength that
## killed in about a minute, cloth or not — rooms the player must spend
## minutes in. The air is now thin there and deadly near the mercury itself
## (the zones' source markers), so lingering by the mercury is what kills.
func _gentler_fumes() -> void:
	var levels := {"Fumes1": 0.12, "Fumes2": 0.06, "Fumes3": 0.06}
	for n in levels:
		var z := root.get_node_or_null("MercuryHall/" + n)
		if z != null:
			z.set(&"ambient", levels[n])
	_log.append("fumes: ambient %s" % str(levels))

## Frame time pass (the archives ran at 5 fps): the heaviest decorative meshes
## (1.9 M triangles of scrolls, 140 k-triangle cloth banners) stop casting
## shadows and draw at a lower level of detail, and static lights only render
## shadows close to the player.
func _performance() -> void:
	var heavy := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var am := mi.mesh as ArrayMesh
		if am == null:
			continue
		var tris := 0
		for i in am.get_surface_count():
			tris += am.surface_get_array_index_len(i) / 3
		var name := String(mi.name)
		var decorative := name == "Testamente" or name.begins_with("Plane_0") or name.begins_with("rope_crossbow")
		if decorative and tris > 30000:
			_editable_up_to(mi)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.lod_bias = 0.25
			heavy += 1
	var lights := 0
	for n in root.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		if l.shadow_enabled and l is FlickerLight and not root.get_node("Guards").is_ancestor_of(l):
			l.distance_fade_enabled = true
			l.distance_fade_shadow = 18.0
			l.distance_fade_length = 6.0
			lights += 1
	_log.append("performance: %d heavy meshes simplified, %d brazier shadows shortened" % [heavy, lights])

## Edits inside an instanced scene are only saved if the instance is marked
## "editable children" (as the map already is).
func _editable_up_to(node: Node) -> void:
	var n := node.get_parent()
	while n != null and n != root:
		if n.scene_file_path != "" and n.owner == root:
			root.set_editable_instance(n, true)
		n = n.get_parent()

## Chapter title cards open as the player first walks into each act.
func _chapters() -> void:
	var chapters := {"ArchivesEnter": 2, "TunnelsEnter": 3, "CorridorEnter": 3, "CorridorEnterEast": 3, "MechanismEnter": 4, "TreasuryEnter": 5}
	for n in chapters:
		var t := root.get_node_or_null("Story/" + n) as StoryTrigger
		if t != null:
			t.chapter = chapters[n]
	_log.append("chapters: cards on %s" % ", ".join(chapters.keys()))

## The guards of the sealing scene waited 30 and 70 m away and took over half
## a minute to walk in. They now stand just outside the workshop door.
func _sealing_guards_closer() -> void:
	var spots := {"GuardCaptain": Vector3(-56.8, 0.2, 10.8), "GuardEscort": Vector3(-58.6, 0.2, 12.2)}
	for n in spots:
		var g := root.get_node("Guards/" + n) as Node3D
		g.global_position = spots[n]
		g.rotation.y = 0.0
	# And they stop to talk a few steps from the statue, not across the room.
	var marks := root.get_node("Rooms/01_TerracottaWorkshop/SealingMarks")
	(marks.get_node("TalkSpotA") as Node3D).global_position = _floor_at(Vector3(-61.6, 0.0, -5.6))
	(marks.get_node("TalkSpotB") as Node3D).global_position = _floor_at(Vector3(-62.9, 0.0, -3.4))
	var door := marks.get_node_or_null("DoorLook") as Marker3D
	if door == null:
		door = Marker3D.new()
		door.name = "DoorLook"
		marks.add_child(door)
		door.owner = root
	door.global_position = Vector3(-57.0, 2.4, -2.2)
	var seq := root.get_node("Story/SealingSequence")
	seq.set(&"door_look_path", seq.get_path_to(door))
	_log.append("sealing: guards wait at the workshop door")

## The statue the tutorial builds: the legs on the plinth and the head waiting
## on the bench, and the whole soldier that replaces them on the last strike.
func _statue_parts() -> void:
	var statue := root.get_node("Rooms/01_TerracottaWorkshop/ClayStatue") as ClayStatue
	var legs := root.get_node("MapWithoutTreasure/tripo_node_50f1d62e-4661-4fcc-9639-fb0d08fe7406_017") as MeshInstance3D
	var head := root.get_node("MapWithoutTreasure/tripo_node_000b2929-e822-4b65-9ed3-d59ceee77067_003") as MeshInstance3D
	var parts: Array[NodePath] = [statue.get_path_to(legs), statue.get_path_to(head)]
	statue.unfinished_paths = parts
	var whole := statue.get_node_or_null("WholeSoldier") as Node3D
	if whole == null:
		whole = (load("res://TripoModels/statue1-idle.glb") as PackedScene).instantiate() as Node3D
		whole.name = "WholeSoldier"
		statue.add_child(whole)
		whole.owner = root
	var box := legs.global_transform * legs.get_aabb()
	whole.global_transform = Transform3D(Basis(Vector3.UP, 0.0).scaled(Vector3.ONE * 3.3), Vector3(box.get_center().x, box.position.y, box.get_center().z))
	whole.visible = false
	statue.finished_path = statue.get_path_to(whole)
	# "Set the bowl on the workbench": on the bench top, not the floor.
	var bowl := statue.get_node_or_null("PlacedBowl") as Node3D
	if bowl != null:
		var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-66.9, 4.0, -5.9), Vector3(-66.9, 0.0, -5.9), 1))
		if not hit.is_empty():
			bowl.global_position = hit.position
	_log.append("statue: legs + head become a whole soldier on the last strike")

## The end of the drain opened onto nothing: a black void, and the "light" was
## a marker behind the player. Now the tunnel ends in a morning hillside (the
## DaylightExit scene), the walk out starts a few metres before the mouth, the
## lumpy stretched floor mesh is replaced by a flat one and the tunnel gets
## its own air for the sun's shaft.
func _way_out() -> void:
	var mouth := Vector3(-1.75, 7.45, 185.65)
	var day := root.get_node_or_null("DaylightExit") as DaylightExit
	if day == null:
		day = (load("res://scenes/world/daylight_exit.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as DaylightExit
		day.name = "DaylightExit"
		root.add_child(day)
		day.owner = root
	day.global_position = mouth
	# Its _ready hides it until Act V; the scene itself stays visible.
	day.visible = true
	var old_floor := root.get_node("TreasureRoomUpdated/Cube_296") as MeshInstance3D
	old_floor.visible = false
	var floor := root.get_node_or_null("EscapeFloor") as MeshInstance3D
	if floor == null:
		floor = MeshInstance3D.new()
		floor.name = "EscapeFloor"
		root.add_child(floor)
		floor.owner = root
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 0.6, 55.2)
	floor.mesh = box
	# A drainage channel: damp stone that catches the daylight.
	floor.material_override = load("res://assets/materials/level/drain_floor.tres")
	floor.global_position = Vector3(-1.5, 7.47 - 0.3, 130.9 + 55.2 * 0.5)
	var exit := root.get_node("Story/ExitLight") as Node3D
	exit.global_position = Vector3(-1.75, 8.6, 178.0)
	(exit.get_node("Light") as Node3D).global_position = mouth + Vector3(0.0, 3.0, 0.0) + day.sun_direction * 60.0
	var air := _zone("Escape", Vector3(-1.75, 10.5, 158.3), Vector3(9.0, 9.0, 56.0))
	air.zone_priority = 2
	air.fog_color = Color(0.02, 0.022, 0.026)
	air.fog_density = 0.005
	air.volumetric_density = 0.012
	air.volumetric_albedo = Color(0.95, 0.9, 0.82)
	air.ambient_color = Color(0.045, 0.05, 0.065)
	air.saturation = 0.95
	air.music = &"silence"
	_log.append("way out: daylight at the mouth, flat floor, walk-out trigger at z 178")

## The service tunnels (and the passage from the mechanism room to the Mercury
## Hall) were flat orange plaster from the jam: now hewn rock.
func _tunnel_rock() -> void:
	var rock := load("res://assets/materials/level/tunnel_rock.tres") as Material
	for n in ["Tunele/Cube_266", "Tunele/Cube_264"]:
		var mi := root.get_node(n) as MeshInstance3D
		_editable_up_to(mi)
		mi.material_override = rock
	_log.append("tunnels: hewn rock")

## The treasury held a single chest. Now the Emperor's grave goods
## (tools/blender/build_treasures.py): bronze ding and hu, gold, a heap of
## coins and jade discs on the island, a rack of bells on the west gallery,
## vessels along the east one, and a warm light that makes the metal glint.
func _grave_goods() -> void:
	var group := root.get_node_or_null("GraveGoods") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "GraveGoods"
		root.add_child(group)
		group.owner = root
	var items := [
		# name, prop, position (y found by ray), yaw degrees
		["DingWest", "ding", Vector3(-5.2, 0, 103.9), 25.0],
		["DingEast", "ding", Vector3(2.3, 0, 103.9), -20.0],
		["HuWest", "hu", Vector3(-5.5, 0, 111.4), 10.0],
		["HuEast", "hu", Vector3(2.5, 0, 111.4), -35.0],
		["Coins", "coins", Vector3(-5.4, 0, 107.6), 0.0],
		["Gold", "gold", Vector3(0.95, 0, 107.6), 15.0],
		["Bi", "bi", Vector3(-3.95, 0, 107.6), 0.0],
		# The east gallery leads nowhere, so the bells stand there; the west
		# one is the way to the drain and stays clear.
		["Bells", "bianzhong", Vector3(16.95, 0, 104.5), -90.0],
		["GalleryHuNorth", "hu", Vector3(16.9, 0, 98.6), 0.0],
		["LampBridgeWest", "bronze_lamp", Vector3(-3.3, 0, 103.1), 0.0],
		["LampBridgeEast", "bronze_lamp", Vector3(0.3, 0, 103.1), 0.0],
		["LampBellsNorth", "bronze_lamp", Vector3(16.9, 0, 101.6), 0.0],
		["LampBellsSouth", "bronze_lamp", Vector3(16.9, 0, 107.6), 0.0],
	]
	for gone in ["GalleryHuSouth", "LampGallery", "GalleryDing"]:
		var old := group.get_node_or_null(gone)
		if old != null:
			group.remove_child(old)
			old.free()
	var space := root.get_world_3d().direct_space_state
	# Rays find the floor, not the props already standing there.
	var own: Array[RID] = []
	for body in group.find_children("*", "CollisionObject3D", true, false):
		own.append((body as CollisionObject3D).get_rid())
	for it in items:
		var node := group.get_node_or_null(String(it[0])) as Node3D
		if node == null:
			node = (load("res://scenes/props/treasure/%s.tscn" % it[1]) as PackedScene).instantiate() as Node3D
			node.name = String(it[0])
			group.add_child(node)
			node.owner = root
		var at: Vector3 = it[2]
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, 14.0, at.z), Vector3(at.x, 0.0, at.z), 1)
		ray.exclude = own
		var hit := space.intersect_ray(ray)
		node.global_position = Vector3(at.x, hit.position.y if not hit.is_empty() else 7.5, at.z)
		node.rotation = Vector3(0.0, deg_to_rad(float(it[3])), 0.0)
	var glint := group.get_node_or_null("Glint") as OmniLight3D
	if glint == null:
		glint = OmniLight3D.new()
		glint.name = "Glint"
		group.add_child(glint)
		glint.owner = root
	glint.global_position = Vector3(-1.5, 11.6, 107.4)
	glint.light_color = Color(1.0, 0.76, 0.46)
	glint.light_energy = 2.4
	glint.omni_range = 9.0
	glint.omni_attenuation = 1.2
	glint.light_volumetric_fog_energy = 0.3
	_log.append("treasury: %d grave goods and a glint over the chest" % items.size())

## Two craftsmen worked a workshop built for hundreds. Seven more now: four
## shaping clay figures, three kneading clay at the tables (craftsman.glb,
## tools/blender/build_craftsman.py). At the sealing they stop and despair.
func _workshop_at_work() -> void:
	var room := root.get_node("Rooms/01_TerracottaWorkshop")
	var people := [
		# name, clip, position (floor found by ray), facing (degrees, 0 = +x), after the sealing
		["Sculptor1", &"sculpt", Vector3(-47.4, 0, -25.25), 90.0, &"kneel"],
		["Sculptor2", &"sculpt", Vector3(-46.55, 0, -12.9), 180.0, &"idle"],
		["Sculptor3", &"sculpt", Vector3(-35.35, 0, -13.4), 0.0, &"kneel"],
		["Sculptor4", &"sculpt", Vector3(-80.85, 0, -18.1), 180.0, &"kneel"],
		["Kneader1", &"knead", Vector3(-68.0, 0, -30.15), 90.0, &"kneel"],
		["Kneader2", &"knead", Vector3(-41.0, 0, -32.45), 90.0, &"idle"],
		["Kneader3", &"knead", Vector3(-49.3, 0, -16.85), -90.0, &"kneel"],
	]
	var space := root.get_world_3d().direct_space_state
	for p in people:
		var w := room.get_node_or_null(String(p[0])) as Worker
		if w == null:
			w = (load("res://scenes/ai/craftsman.tscn") as PackedScene).instantiate() as Worker
			w.name = String(p[0])
			room.add_child(w)
			w.owner = root
		var at: Vector3 = p[2]
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x, 3.0, at.z), Vector3(at.x, -2.0, at.z), 1)
		var hit := space.intersect_ray(ray)
		w.global_position = Vector3(at.x, hit.position.y if not hit.is_empty() else 0.2, at.z)
		w.rotation = Vector3(0.0, deg_to_rad(float(p[3])), 0.0)
		w.work_anim = p[1]
		w.after_sealing_anim = p[4]
		w.holds_tool = p[1] == &"sculpt"
	_log.append("workshop: %d more craftsmen at work" % people.size())
	# Working hours: the workshop is lit for work until the gate slams, then
	# its lamps gutter out and the air darkens (SealingDimmer, AtmosphereZone).
	var zone := root.get_node("AtmosphereZones/Workshop") as AtmosphereZone
	zone.lit_before_sealing = true
	var lights := room.get_node_or_null("WorkLights") as Node3D
	if lights == null:
		lights = Node3D.new()
		lights.name = "WorkLights"
		lights.set_script(load("res://Scripts/world/sealing_dimmer.gd"))
		room.add_child(lights)
		lights.owner = root
	var spots := [Vector3(-75, 5.2, -20), Vector3(-63, 5.2, -27), Vector3(-50, 5.2, -21), Vector3(-37, 5.2, -24),
			Vector3(-63, 5.2, -11), Vector3(-46, 5.2, -9)]
	for i in spots.size():
		var name := "Lamp%d" % (i + 1)
		var l := lights.get_node_or_null(name) as OmniLight3D
		if l == null:
			l = OmniLight3D.new()
			l.name = name
			lights.add_child(l)
			l.owner = root
		l.global_position = spots[i]
		l.light_color = Color(1.0, 0.7, 0.44)
		l.light_energy = 1.0
		l.omni_range = 15.0
		l.omni_attenuation = 1.1
		l.light_volumetric_fog_energy = 0.4
		l.shadow_enabled = false

## The sealing traps thousands; the player only ever met two of them after
## it. Now the way tells it: a craftsman shot down by the corridor's
## crossbows with a friend kneeling by him, another fallen near the plates
## at the far end, one who breathed the mercury fumes on the way to the hall.
func _the_fallen() -> void:
	var group := root.get_node_or_null("TheFallen") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "TheFallen"
		root.add_child(group)
		group.owner = root
	var people := [
		# name, clip, position, facing (degrees), dead, bolts
		["ShotAtPlate3", &"collapse", Vector3(-47.4, 0, 17.6), 200.0, true, 2],
		["Mourner", &"kneel", Vector3(-46.0, 0, 18.9), 150.0, false, 0],
		["ShotAtPlate4", &"collapse", Vector3(16.6, 0, 17.8), 15.0, true, 1],
		["Fumes", &"collapse", Vector3(-38.0, 0, 70.2), 175.0, true, 0],
	]
	var space := root.get_world_3d().direct_space_state
	for p in people:
		var w := group.get_node_or_null(String(p[0])) as Worker
		if w == null:
			w = (load("res://scenes/ai/craftsman.tscn") as PackedScene).instantiate() as Worker
			w.name = String(p[0])
			group.add_child(w)
			w.owner = root
		var at: Vector3 = p[2]
		var top := 9.5 if at.z > 60.0 else 3.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, top, at.z), Vector3(at.x, top - 6.0, at.z), 1))
		w.global_position = Vector3(at.x, hit.position.y if not hit.is_empty() else at.y, at.z)
		w.rotation = Vector3(0.0, deg_to_rad(float(p[3])), 0.0)
		w.work_anim = p[1]
		w.after_sealing_anim = p[1]
		w.dead = p[4]
		w.bolts = p[5]
		w.holds_tool = false
	_log.append("the fallen: %d along the way" % people.size())
	# Bolts that found the wall instead: the corridor warns who looks.
	var bolt_scene := load("res://scenes/props/bolt.tscn") as PackedScene
	var rng := RandomNumberGenerator.new()
	rng.seed = 214
	for cb_name in ["Crossbow3", "Crossbow4", "Crossbow1"]:
		var cb := root.get_node_or_null("CorridorTraps/" + cb_name) as Node3D
		if cb == null:
			continue
		var dir := -cb.global_basis.z
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cb.global_position + dir * 0.6, cb.global_position + dir * 40.0, 1))
		if hit.is_empty():
			continue
		for k in 2:
			var name := "Bolt%s_%d" % [cb_name.trim_prefix("Crossbow"), k]
			var b := group.get_node_or_null(name) as Node3D
			if b == null:
				b = bolt_scene.instantiate() as Node3D
				b.name = name
				group.add_child(b)
				b.owner = root
			var jitter := cb.global_basis.x * rng.randf_range(-0.35, 0.35) + Vector3.UP * rng.randf_range(-0.12, 0.1)
			var tilt := Basis(cb.global_basis.x, rng.randf_range(-0.06, 0.06)) * Basis(Vector3.UP, rng.randf_range(-0.08, 0.08))
			b.global_transform = Transform3D(tilt * cb.global_basis, hit.position + jitter - dir * 0.15)

## The map of the empire in the Mercury Hall was bare clay. Now it carries
## its cities ("palaces and towers for the hundred officials"): walled
## cities, palaces and watchtowers in bronze with gilded roofs, along the
## mercury rivers, the capital in the middle, all facing the same way as
## Qin halls did. Spots are found on flat ground of the map by rays.
func _miniature_empire() -> void:
	var group := root.get_node_or_null("MercuryHall/Miniatures") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "Miniatures"
		root.get_node("MercuryHall").add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	var terrain := root.find_child("tripo_node_8a344439*", true, false) as MeshInstance3D
	var box := terrain.global_transform * terrain.get_aabb()
	var space := root.get_world_3d().direct_space_state
	var ground := func(x: float, z: float) -> Dictionary:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 5.5, z), Vector3(x, -3.0, z), 1))
		if hit.is_empty():
			return {}
		return {"y": hit.position.y, "terrain": String((hit.collider as Node).name).contains("8a344439")}
	# Candidates: flat terrain, scored by mercury close by (cities by rivers).
	var candidates := []
	var step := 0.9
	var x := box.position.x + 2.0
	while x < box.end.x - 2.0:
		var z := box.position.z + 2.0
		while z < box.end.z - 2.0:
			var here: Dictionary = ground.call(x, z)
			if not here.is_empty() and here["terrain"]:
				var flat := true
				var wet := 0
				for o in [Vector2(0.9, 0), Vector2(-0.9, 0), Vector2(0, 0.9), Vector2(0, -0.9), Vector2(0.7, 0.7), Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7)]:
					var g: Dictionary = ground.call(x + o.x, z + o.y)
					if g.is_empty() or not g["terrain"] or absf(float(g["y"]) - float(here["y"])) > 0.45:
						flat = false
						break
				if flat:
					for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
						var g: Dictionary = ground.call(x + o.x, z + o.y)
						if not g.is_empty() and not g["terrain"] and float(g["y"]) < -0.2:
							wet += 1
					candidates.append({"p": Vector3(x, here["y"], z), "score": wet + randf() * 0.5})
			z += step
		x += step
	var centre := box.get_center()
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	var chosen := []
	# The capital first: the flattest ground nearest the middle.
	var capital: Dictionary = {}
	for c in candidates:
		if capital.is_empty() or (c["p"] as Vector3).distance_to(centre) < (capital["p"] as Vector3).distance_to(centre):
			capital = c
	if not capital.is_empty():
		chosen.append([capital["p"], "city", 1.5])
	var kinds := ["palace", "tower", "palace", "city", "tower", "palace", "palace", "tower", "city", "palace", "tower", "palace", "tower", "palace"]
	for c in candidates:
		if chosen.size() >= kinds.size() + 1:
			break
		var p: Vector3 = c["p"]
		var ok := true
		for ch in chosen:
			if (ch[0] as Vector3).distance_to(p) < 4.2:
				ok = false
				break
		if ok:
			chosen.append([p, kinds[chosen.size() - 1], 1.3 if kinds[chosen.size() - 1] != "tower" else 1.2])
	var i := 0
	for ch in chosen:
		var node := (load("res://scenes/props/miniatures/%s.tscn" % ch[1]) as PackedScene).instantiate() as Node3D
		node.name = "%s%d" % [String(ch[1]).capitalize(), i]
		group.add_child(node)
		node.owner = root
		node.global_position = ch[0] - Vector3.UP * 0.04
		node.rotation = Vector3(0.0, PI * 0.5, 0.0)
		node.scale = Vector3.ONE * float(ch[2])
		i += 1
	_log.append("miniatures: %d on the map (%d flat spots)" % [chosen.size(), candidates.size()])

## The apprentice's model is now apprentice.glb (tools/blender/
## build_apprentice.py), its clips named for what they are, with "scared"
## and "cower" for after the sealing.
func _apprentice_clips() -> void:
	var a := root.get_node("Rooms/01_TerracottaWorkshop/Apprentice")
	a.set(&"anims", {
		"bow": "bow", "idle": "hands_on_hips", "idle_hips": "hands_on_hips", "point": "point",
		"scared": "scared", "talk": "talk", "work": "work", "cower": "cower", "walk": "walk",
	})
	_log.append("apprentice: clips by name, scared and cower")

## The service tunnels were bare rock: now dug tunnels, shored up with pit
## props (TimberFrame) every few metres, sized to the tunnel by rays, an oil
## lamp left burning on every third one.
func _tunnel_timbers() -> void:
	var group := root.get_node_or_null("TunnelTimbers") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "TunnelTimbers"
		root.add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	var space := root.get_world_3d().direct_space_state
	var ray := func(a: Vector3, b: Vector3) -> Variant:
		var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
		return null if r.is_empty() else r.position
	# Corridors: [axis along, fixed coordinate across, from, to, step]
	var runs := [["z", 27.0, -42.0, 26.0, 6.0], ["x", -34.0, -12.0, 20.0, 6.0], ["x", 31.0, 4.0, 22.0, 6.0], ["x", -46.0, 32.0, 42.0, 5.0]]
	var n := 0
	for run in runs:
		var along_z: bool = run[0] == "z"
		var t: float = run[2]
		while t <= float(run[3]) + 0.01:
			var p := Vector3(run[1], -7.0, t) if along_z else Vector3(t, -7.0, run[1])
			var across := Vector3.RIGHT if along_z else Vector3.BACK
			var floor_hit = ray.call(p, p + Vector3.DOWN * 3.0)
			var ceil_hit = ray.call(p, p + Vector3.UP * 4.0)
			var a = ray.call(p, p + across * 6.0)
			var b = ray.call(p, p - across * 6.0)
			if floor_hit != null and ceil_hit != null and a != null and b != null:
				var w: float = (a as Vector3).distance_to(b)
				var h: float = (ceil_hit as Vector3).y - (floor_hit as Vector3).y
				if w > 2.5 and w < 6.0 and h > 3.1 and h < 5.0:
					var centre: Vector3 = ((a as Vector3) + (b as Vector3)) * 0.5
					var frame := TimberFrame.new()
					frame.name = "Frame%d" % n
					group.add_child(frame)
					frame.owner = root
					frame.global_position = Vector3(centre.x, (floor_hit as Vector3).y, centre.z)
					frame.rotation.y = 0.0 if along_z else PI * 0.5
					frame.width = w
					frame.height = h
					frame.with_lamp = n % 3 == 1
					n += 1
			t += float(run[4])
	_log.append("tunnels: %d timber frames" % n)

## Six guards, one face: at least their armour differs. The captain's is
## lacquered red.
func _guard_variety() -> void:
	var tints := {
		"GuardCaptain": Color(1.25, 0.62, 0.5),
		"GuardEscort": Color(0.9, 0.88, 0.85),
		"ArchiveGuard1": Color(0.8, 0.8, 0.82),
		"ArchiveGuard2": Color(1.05, 0.95, 0.85),
		"ArchiveGuard3": Color(0.72, 0.7, 0.68),
		"ArchiveGuard4": Color(0.95, 0.9, 1.0),
	}
	for n in tints:
		var g := root.get_node_or_null("Guards/" + n) as Guard
		if g != null:
			g.armor_tint = tints[n]
	_log.append("guards: armour tints")

## The mechanism room's west wall was one-sided, facing out: from inside it
## was invisible and the Mercury Hall's starry dome showed through. Its
## earth is now drawn from both sides.
func _close_mechanism_wall() -> void:
	var shell := root.get_node("MapWithoutTreasure/BalantaRoof") as MeshInstance3D
	shell.set_surface_override_material(1, load("res://assets/materials/level/dirt_double.tres"))
	_log.append("mechanism room: west wall drawn from both sides")

## The makers' names pressed into the figures' clay (NameMark, NamesDB),
## one on each of eight statues along the way, on the side you pass.
func _makers_names() -> void:
	var group := root.get_node_or_null("MakersNames") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "MakersNames"
		root.add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	# name, statue centre (x, z), where you pass by it (x, z), height of the mark
	var spots := [
		[&"gong_jiang", Vector2(-71.3, -27.8), Vector2(-68.4, -27.8), 1.9],
		[&"xianyang_yi", Vector2(-63.6, -33.7), Vector2(-63.6, -30.8), 1.8],
		[&"gong_de", Vector2(-46.1, -35.0), Vector2(-46.1, -32.0), 1.2],
		[&"xianyang_ci", Vector2(-24.9, -25.9), Vector2(-27.9, -25.9), 1.2],
		[&"xianyang_ye", Vector2(-20.7, -40.2), Vector2(-20.7, -37.4), 1.25],
		[&"gong_cang", Vector2(55.8, -12.0), Vector2(52.8, -12.0), 1.2],
		[&"xianyang_qing", Vector2(52.2, -56.3), Vector2(52.2, -53.3), 1.2],
		[&"gong_shui", Vector2(33.2, -35.6), Vector2(30.6, -35.6), 1.2],
	]
	var space := root.get_world_3d().direct_space_state
	var placed := 0
	for s in spots:
		var centre: Vector2 = s[1]
		var want: Vector2 = (s[2] as Vector2 - centre).normalized()
		var y: float = s[3]
		# Try the wanted side first, then turn round until a ray meets the
		# statue itself (not a table or wall in between).
		var best: Dictionary = {}
		for k in 16:
			var turn := (k + 1) / 2 * (1 if k % 2 == 0 else -1) * TAU / 16.0
			var d := want.rotated(turn)
			var from := Vector3(centre.x + d.x * 2.4, y, centre.y + d.y * 2.4)
			var to := Vector3(centre.x, y, centre.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			if hit.is_empty():
				continue
			var p: Vector3 = hit.position
			if Vector2(p.x, p.z).distance_to(centre) < 0.85:
				best = hit
				break
		if best.is_empty():
			_log.append("names: WARNING no statue surface for %s" % s[0])
			continue
		var mark := NameMark.new()
		mark.name = String(s[0]).to_pascal_case()
		mark.name_id = s[0]
		group.add_child(mark)
		mark.owner = root
		var n: Vector3 = best.normal
		n.y = 0.0
		n = n.normalized()
		mark.global_transform = Transform3D(Basis.looking_at(-n), best.position + n * 0.01)
		placed += 1
	_log.append("names: %d makers' names on statues" % placed)

## Liang talks from where he sits (liang.glb, tools/blender/build_liang.py):
## no more standing up for each line and dropping back onto the stool.
func _liang_seated() -> void:
	var liang := root.get_node("Liang")
	liang.set(&"anims", {"sit": "sit", "talk": "talk", "surprised": "surprised", "frustrated": "frustrated"})
	_log.append("liang: seated talk")

## The lacquered chest on the treasury's island is the Emperor's coffin;
## stepping up to it, the craftsman says so.
func _the_coffin() -> void:
	var story := root.get_node("Story")
	var t := story.get_node_or_null("CoffinNear") as StoryTrigger
	if t == null:
		t = StoryTrigger.new()
		t.name = "CoffinNear"
		story.add_child(t)
		t.owner = root
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 4.0, 5.0)
		cs.shape = box
		t.add_child(cs)
		cs.owner = root
	t.global_position = Vector3(-1.5, 9.5, 106.5)
	t.quest_from = &"find_drain"
	t.dialogue = &"coffin"
	_log.append("treasury: a word at the coffin")
