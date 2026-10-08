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
	# Patches that scatter things pick the same spots every run, so re-running
	# changes only what a new patch changes.
	seed(20261007)
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
	_kit_service_tunnels()
	# Before the props are sized by rays: the falls must be there every run.
	_tunnels_fallen_in()
	await get_tree().physics_frame
	_grave_goods()
	_workshop_at_work()
	_the_fallen()
	_miniature_empire()
	_apprentice_clips()
	_tunnel_timbers()
	_no_props_past_the_falls()
	_guard_variety()
	_close_mechanism_wall()
	_makers_names()
	_liang_seated()
	_the_coffin()
	_one_crossbow_per_trap()
	_jar_and_cloth_any_time()
	_tunnels_trigger_in_the_middle()
	_timber_ceilings()
	_apprentice_taken()
	# Last: its lamps and guards draw on the shared random numbers, which
	# would reshuffle what the patches above scatter.
	_workers_shaft_and_pits()
	_corridor_on_the_way_to_the_archives()
	_wei_at_his_desk()
	_wei_at_the_last_door()
	_exit_watch()
	_corridor_mechanisms()
	_masons_song()
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
	# The army pits: still air thick with clay dust, the lamps hazy in it,
	# and no music, only the tomb.
	var pits := _zone("Pits", Vector3(50.0, -22.5, 9.0), Vector3(44.0, 9.0, 48.0))
	pits.zone_priority = 1
	pits.fog_color = Color(0.018, 0.013, 0.009)
	pits.fog_density = 0.02
	pits.volumetric_density = 0.022
	pits.volumetric_albedo = Color(0.86, 0.72, 0.56)
	pits.ambient_color = Color(0.03, 0.025, 0.02)
	pits.ambient_energy = 0.75
	pits.saturation = 0.9
	pits.music = &"silence"
	pits.ambience = &"tomb"
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
	var chapters := {"ArchivesEnter": 2, "TunnelsEnter": 3, "MechanismEnter": 4, "TreasuryEnter": 5}
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

## The service tunnels were one jam mesh, closed at every end and stretched
## thirty-fold along its length, so nothing could ever open off them. Now
## they are LevelBox pieces on the same path, with the same floors, widths and
## heights (measured from the old mesh), so new spaces can join them anywhere
## by adding an opening. The old mesh and both of its colliders are off.
func _kit_service_tunnels() -> void:
	var old := root.get_node("Tunele/Cube_266") as MeshInstance3D
	_editable_up_to(old)
	old.visible = false
	old.set_meta(&"no_collision", true)
	# Its import-time collider and the map's copy of it would wall up any
	# new opening in the tunnels.
	for path in ["Tunele/Cube_266/Cube_266_col", "MapWithoutTreasure/Cube_266/Cube_266_col"]:
		var old_col := root.get_node_or_null(path) as StaticBody3D
		if old_col != null:
			_editable_up_to(old_col)
			old_col.collision_layer = 0
			old_col.collision_mask = 0
	var group := root.get_node_or_null("ServiceTunnels") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "ServiceTunnels"
		root.add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	const F := LevelOpening.Face
	# The long run south from Liang's shaft, joined by the other three.
	_kit_box(group, "NorthSouth", Vector3(27.55, -8.63, -8.015), Vector3(3.5, 3.43, 80.23), false, 0, [
		LevelOpening.make(F.EAST, Vector2(-38.665, 0.0), Vector2(2.9, 3.3)),
		LevelOpening.make(F.WEST, Vector2(-25.935, 0.0), Vector2(3.9, 3.43)),
		LevelOpening.make(F.WEST, Vector2(38.165, 0.0), Vector2(3.9, 3.43)),
		# The passage east to the workers' shaft.
		LevelOpening.make(F.EAST, Vector2(-11.985, 0.0), Vector2(3.5, 3.43), false),
	])
	# East to the foot of Liang's ladder, with the shaft up through its roof.
	_kit_box(group, "TopBranch", Vector3(39.355, -8.55, -46.68), Vector3(2.9, 3.22, 20.11), true, 1 << F.NORTH, [
		LevelOpening.make(F.CEILING, Vector2(0.0, 7.77), Vector2(3.0, 4.57)),
	])
	_kit_box(group, "ShaftToLiang", Vector3(47.125, -5.33, -46.495), Vector3(4.57, 4.83, 2.91), false, (1 << F.FLOOR) | (1 << F.CEILING), [])
	# West under the archives, a dead end.
	_kit_box(group, "WestBranch", Vector3(3.53, -8.58, -33.95), Vector3(3.9, 3.63, 44.54), true, 1 << F.SOUTH, [])
	# The southern run, then the turn to the mechanism and its ladder shaft.
	_kit_box(group, "South", Vector3(13.81, -8.63, 30.15), Vector3(3.9, 3.43, 23.98), true, (1 << F.NORTH) | (1 << F.SOUTH), [])
	_kit_box(group, "ToMechanism", Vector3(0.255, -8.54, 35.505), Vector3(3.13, 3.25, 14.61), false, 0, [
		LevelOpening.make(F.EAST, Vector2(-5.355, 0.0), Vector2(3.9, 3.25)),
		LevelOpening.make(F.CEILING, Vector2(0.03, 5.7), Vector2(3.11, 3.21)),
		# The top of the stairs up from the army pits.
		LevelOpening.make(F.EAST, Vector2(-0.505, 0.0), Vector2(2.0, 3.25), false),
		# The hatch up from the crossbow gallery's ladder, over its rungs,
		# cut down through the floor's whole thickness.
		LevelOpening.make(F.FLOOR, Vector2(-0.005, -6.555), Vector2(1.4, 1.4)),
	])
	_kit_box(group, "ShaftToMechanism", Vector3(0.285, -5.29, 41.205), Vector3(3.11, 16.69, 3.21), false, 1 << F.FLOOR, [
		LevelOpening.make(F.SOUTH, Vector2(0.0, 12.79), Vector2(3.11, 3.9)),
	])
	_log.append("tunnels: rebuilt from %d LevelBox pieces" % group.get_child_count())

## The sealing brought the service tunnel down where it ran on to the
## mechanism (Liang felt it go), and the branch west under the archives that
## led nowhere: the way on is the workers' shaft, through the army pits,
## whose stairs come up by the mechanism's ladder. Three falls of rock, each
## spilling toward the side still open: west of the main tunnel, south of
## the shaft's passage, and at the far end of the southern run, so neither
## side of the sealed stretch is a long walk to a dead end.
const FALLS := [
	# name, where the roof came down, facing (yaw: the open side is -z), size, spill
	["WestBranch", Vector3(22.0, -8.58, -33.95), -PI * 0.5, Vector3(3.9, 3.63, 2.5), 2.6],
	["PastTheShaft", Vector3(27.55, -8.63, -12.0), 0.0, Vector3(3.5, 3.43, 2.5), 3.0],
	["SouthRun", Vector3(5.5, -8.63, 30.15), PI * 0.5, Vector3(3.9, 3.43, 2.5), 2.6],
]

func _tunnels_fallen_in() -> void:
	var group := root.get_node_or_null("TunnelFalls") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "TunnelFalls"
		root.add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	for i in FALLS.size():
		var f: Array = FALLS[i]
		var fall := Rubble.new()
		fall.name = String(f[0])
		fall.size = f[3]
		fall.spill = f[4]
		fall.pattern_seed = 31 + i
		group.add_child(fall)
		fall.owner = root
		var at: Vector3 = f[1]
		fall.global_transform = Transform3D(Basis(Vector3.UP, float(f[2])), at)
	# A word as he comes to it, with both falls in sight.
	var story := root.get_node("Story")
	var t := story.get_node_or_null("TunnelFallen") as StoryTrigger
	if t == null:
		t = StoryTrigger.new()
		t.name = "TunnelFallen"
		story.add_child(t)
		t.owner = root
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(3.4, 3.0, 6.0)
		cs.shape = box
		t.add_child(cs)
		cs.owner = root
	t.global_position = Vector3(27.55, -7.2, -24.0)
	t.quest_from = &"talk_liang"
	t.dialogue = &"tunnel_fallen"
	_log.append("tunnels: %d falls of rock, the way on is the workers' shaft" % FALLS.size())

## The pit props past (and under) the falls go: whatever stood there came
## down with the roof, and no lamp burns where no one can go.
func _no_props_past_the_falls() -> void:
	var sealed := [
		AABB(Vector3(-20.0, -10.0, -36.5), Vector3(20.0 + 22.0, 6.0, 5.0)),
		AABB(Vector3(25.0, -10.0, -12.0), Vector3(5.0, 6.0, 45.0)),
		AABB(Vector3(3.0, -10.0, 27.0), Vector3(23.5, 6.0, 6.0)),
	]
	var gone := 0
	for frame in root.get_node("TunnelTimbers").get_children():
		var p := (frame as Node3D).global_position + Vector3.UP
		for box in sealed:
			if (box as AABB).has_point(p):
				frame.get_parent().remove_child(frame)
				frame.free()
				gone += 1
				break
	_log.append("tunnels: %d props gone with the falls" % gone)

## Act I's last turn (ApprenticeTaken): crossing the workshop to find Liang,
## the craftsman watches Overseer Wei and two of his men come in from the
## annex, pull the apprentice out of the cold kiln and take him away. Wei is a
## guard officer in black lacquer, a register in his hand instead of a ji.
func _apprentice_taken() -> void:
	var ws := root.get_node("Rooms/01_TerracottaWorkshop") as Node3D
	for path in ["Story/ApprenticeTaken", "Rooms/01_TerracottaWorkshop/TakenMarks", "Guards/Wei", "Guards/WeiManA", "Guards/WeiManB"]:
		var old := root.get_node_or_null(path)
		if old != null:
			old.get_parent().remove_child(old)
			old.free()
	var marks := Node3D.new()
	marks.name = "TakenMarks"
	ws.add_child(marks)
	marks.owner = root
	# Wei waits in the open (seen from all the way across); his men go to the
	# kiln's mouth and bring the boy to him.
	var spots := {"WeiSpot": Vector3(-38.8, 0.2, -11.2), "ManASpot": Vector3(-35.9, 0.2, -8.4), "ManBSpot": Vector3(-36.6, 0.2, -10.4), "Approach": Vector3(-34.0, 0.2, -12.5),
		"PullSpot": Vector3(-39.6, 0.2, -10.6), "KilnMouth": Vector3(-34.6, 0.8, -7.0), "Watch": Vector3(-39.2, 1.6, -11.2)}
	for k in spots:
		var m := Marker3D.new()
		m.name = k
		marks.add_child(m)
		m.owner = root
		m.global_position = spots[k]
	var way := Node3D.new()
	way.name = "Way"
	marks.add_child(way)
	way.owner = root
	for i in 3:
		var m := Marker3D.new()
		m.name = "W%d" % i
		way.add_child(m)
		m.owner = root
		# In the annex out of sight, its opening to the workshop, and on.
		m.global_position = [Vector3(-21.5, 0.2, -30.0), Vector3(-28.5, 0.2, -29.5), Vector3(-33.5, 0.2, -23.0)][i]
	var guard_scene := load("res://scenes/ai/guard.tscn") as PackedScene
	var actors := {}
	for actor in [["Wei", Color(0.42, 0.22, 0.2)], ["WeiManA", Color(0.95, 0.9, 0.85)], ["WeiManB", Color(1.05, 0.95, 0.88)]]:
		var g := guard_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		g.name = actor[0]
		root.get_node("Guards").add_child(g)
		g.owner = root
		g.global_position = Vector3(-21.5, 0.2, -30.0)
		g.set(&"armor_tint", actor[1])
		actors[actor[0]] = g
	# The man in front lights their way: and the scene, for the one watching.
	actors["WeiManA"].set(&"carries_torch", true)
	var wei: Node3D = actors["Wei"]
	wei.set(&"carries_ji", false)
	wei.set(&"held_scene", load("res://scenes/items/visuals/register.tscn"))
	wei.set(&"held_offset", Vector3(0.0, 0.06, 0.04))
	wei.set(&"held_rotation", Vector3(0.0, 0.0, 90.0))
	var scene := ApprenticeTaken.new()
	scene.name = "ApprenticeTaken"
	root.get_node("Story").add_child(scene)
	scene.owner = root
	scene.global_position = Vector3(-43.5, 2.0, -17.2)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 4.0, 31.6)
	shape.shape = box
	scene.add_child(shape)
	shape.owner = root
	scene.wei_path = scene.get_path_to(wei)
	var men: Array[NodePath] = [scene.get_path_to(actors["WeiManA"]), scene.get_path_to(actors["WeiManB"])]
	scene.men_paths = men
	scene.apprentice_path = scene.get_path_to(ws.get_node("Apprentice"))
	var stands: Array[NodePath] = [scene.get_path_to(marks.get_node("WeiSpot")), scene.get_path_to(marks.get_node("ManASpot")), scene.get_path_to(marks.get_node("ManBSpot"))]
	scene.stand_paths = stands
	scene.pull_spot_path = scene.get_path_to(marks.get_node("PullSpot"))
	scene.kiln_path = scene.get_path_to(marks.get_node("KilnMouth"))
	scene.approach_path = scene.get_path_to(marks.get_node("Approach"))
	scene.way_path = scene.get_path_to(way)
	scene.watch_path = scene.get_path_to(marks.get_node("Watch"))
	_log.append("workshop: Wei and two men come for the apprentice when the craftsman crosses x -46")

## The trigger that opens the tunnels' chapter sat mostly in the rock east of
## the long tunnel, touching it along one wall only: walking down the middle
## missed it.
func _tunnels_trigger_in_the_middle() -> void:
	var trigger := root.get_node("Story/TunnelsEnter") as Node3D
	trigger.global_position.x = 27.55
	_log.append("tunnels: the chapter trigger across the whole tunnel")

## The jam's roofs: over the workshop, planks tilted every which way, their
## normals wrong (the wood grain smears into streaks) and the gaps between
## them showing the void; over the hall, the second workshop and the
## archives, faces turned to the sky, so from inside there was no ceiling at
## all. Now boards on beams (TimberCeiling) over the same ground, found by
## rays up through each old roof's collider (which stays); the old meshes
## are hidden.
func _timber_ceilings() -> void:
	for pair in [["FirstTerracottaRoomRoof", "WorkshopCeiling"], ["HallwayRoof", "HallwayCeiling"],
			["SecondTerracottaRoomRoof", "SecondWorkshopCeiling"], ["SecretaryRoof", "ArchivesCeiling"]]:
		_timber_ceiling(pair[0], pair[1])

func _timber_ceiling(roof_name: String, ceiling_name: String) -> void:
	var old := root.get_node("MapWithoutTreasure/" + roof_name) as MeshInstance3D
	_editable_up_to(old)
	var col: CollisionObject3D = null
	for c in old.get_children():
		if c is CollisionObject3D:
			col = c
	var aabb := old.global_transform * old.get_aabb()
	var origin := Vector3(floorf(aabb.position.x), 0.0, floorf(aabb.position.z))
	var nx := int(ceilf(aabb.end.x - origin.x))
	var nz := int(ceilf(aabb.end.z - origin.z))
	var space := root.get_world_3d().direct_space_state
	var cover := PackedByteArray()
	cover.resize(nx * nz)
	var heights: Array[float] = []
	for iz in nz:
		for ix in nx:
			var hit := false
			for off in [Vector2(0.5, 0.5), Vector2(0.2, 0.2), Vector2(0.8, 0.2), Vector2(0.2, 0.8), Vector2(0.8, 0.8)]:
				var from := Vector3(origin.x + ix + off.x, aabb.position.y - 2.0, origin.z + iz + off.y)
				var y := _ray_height(space, from, Vector3(from.x, aabb.end.y + 2.0, from.z), col)
				if not is_nan(y):
					hit = true
					heights.append(y)
					break
			cover[iz * nx + ix] = 1 if hit else 0
	# Close the gaps the old planks left between them: a cell with roof on
	# both sides of it, along its row and along its column, has roof.
	var row_span: Array[Vector2i] = []
	for iz in nz:
		var first := -1
		var last := -1
		for ix in nx:
			if cover[iz * nx + ix] != 0:
				last = ix
				if first < 0:
					first = ix
		row_span.append(Vector2i(first, last))
	var col_span: Array[Vector2i] = []
	for ix in nx:
		var first := -1
		var last := -1
		for iz in nz:
			if cover[iz * nx + ix] != 0:
				last = iz
				if first < 0:
					first = iz
		col_span.append(Vector2i(first, last))
	for iz in nz:
		for ix in nx:
			if row_span[iz].x >= 0 and ix > row_span[iz].x and ix < row_span[iz].y and iz > col_span[ix].x and iz < col_span[ix].y:
				cover[iz * nx + ix] = 1
	old.visible = false
	var existing := root.get_node_or_null(ceiling_name)
	if existing != null:
		root.remove_child(existing)
		existing.free()
	# The boards' undersides where most of the old roof was.
	heights.sort()
	var y := heights[heights.size() / 2] - 0.03 if not heights.is_empty() else aabb.position.y
	var ceiling := TimberCeiling.new()
	ceiling.name = ceiling_name
	ceiling.cells = Vector2i(nx, nz)
	ceiling.cover = cover
	root.add_child(ceiling)
	ceiling.owner = root
	ceiling.global_position = Vector3(origin.x, y, origin.z)
	var n := 0
	for b in cover:
		n += b
	_log.append("%s: boards on beams over %d m² at y %.2f (old roof hidden)" % [ceiling_name, n, y])

## Where a ray from `from` to `to` meets `target` (going through anything
## else): its height, or NAN.
func _ray_height(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: CollisionObject3D) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF)
	var skip: Array[RID] = []
	for k in 8:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		if hit.collider == target:
			return (hit.position as Vector3).y
		skip.append(hit.rid)
	return NAN

## Act III's new way down (the first piece of the restructure): from the
## service tunnel a passage east to the workers' shaft, a lift on a
## counterweight down to the army pits (four trenches of clay soldiers, the
## yard with the pen where the guards keep the craftsmen they caught, two
## guards), and a way out south and up a stair well into the tunnel by the
## mechanism's ladder. LevelBox walls are thick outward and floors stop at
## the inner faces, so spaces meet through a passage from one inner face to
## the other, its floor bridging the walls, the size of the holes it goes
## through (which then draw no edges of their own).
func _workers_shaft_and_pits() -> void:
	var group := root.get_node_or_null("UnderTheMountain") as Node3D
	if group == null:
		group = Node3D.new()
		group.name = "UnderTheMountain"
		root.add_child(group)
		group.owner = root
	for c in group.get_children():
		group.remove_child(c)
		c.free()
	for path in ["Guards/PitGuardRing", "Guards/PitGuardYard", "Routes/PitsRing", "Routes/PitsYard", "Guards/GalleryBowWest", "Guards/GalleryBowEast", "Routes/GalleryBowWest", "Routes/GalleryBowEast"]:
		var old := root.get_node_or_null(path)
		if old != null:
			old.get_parent().remove_child(old)
			old.free()
	const F := LevelOpening.Face
	var dirt := load("res://assets/materials/level/dirt.tres") as Material
	var timber := load("res://assets/materials/level/timber.tres") as Material
	# Built like the workshop: its dressed stone and its flagstones.
	var stone := load("res://assets/materials/level/walls.tres") as Material
	var flag := load("res://assets/materials/level/floortiles1.tres") as Material
	var step_stone := load("res://assets/materials/level/floortiles2.tres") as Material
	var pit_floor := -26.0
	var tunnel_floor := -8.63
	var rise := tunnel_floor - pit_floor
	# The shaft (x 36..52, z -27..-14), its top landing a ledge of rock level
	# with the tunnel, the lift beside it.
	_dressed(_kit_box(group, "ShaftPassage", Vector3(32.65, tunnel_floor, -20.0), Vector3(3.5, 3.43, 6.7), true, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	_dressed(_kit_box(group, "WorkersShaft", Vector3(44.0, pit_floor, -20.5), Vector3(16.0, 24.0, 13.0), false, 0, [
		LevelOpening.make(F.WEST, Vector2(0.5, rise), Vector2(3.5, 3.43), false),
		LevelOpening.make(F.SOUTH, Vector2(0.0, 0.0), Vector2(6.0, 4.5), false),
		# At its foot, west under the ledge: the way to the crossbow gallery.
		LevelOpening.make(F.WEST, Vector2(3.0, 0.0), Vector2(3.5, 3.43), false),
	]), timber)
	# The ledge of rock the top landing stands on, with the way west cut
	# through its foot (z -19.25..-15.75). Its other sides are against the
	# shaft's walls.
	var cut := 3.43
	_masonry(_kit_solid(group, "ShaftLanding", Vector3(38.25, pit_floor, -23.125), Vector3(4.5, rise, 7.75), stone), flag).dressed_sides = 8
	_masonry(_kit_solid(group, "ShaftLandingSouth", Vector3(38.25, pit_floor, -14.875), Vector3(4.5, rise, 1.75), stone), flag).dressed_sides = 8
	_masonry(_kit_solid(group, "ShaftLandingOverCut", Vector3(38.25, pit_floor + cut, -17.5), Vector3(4.5, rise - cut, 3.5), stone), flag).dressed_sides = 8
	_kit_solid(group, "LandingRailNorth", Vector3(40.42, tunnel_floor, -24.7), Vector3(0.15, 1.1, 4.6), timber)
	_kit_solid(group, "LandingRailSouth", Vector3(40.42, tunnel_floor, -15.8), Vector3(0.15, 1.1, 3.6), timber)
	var lift := CounterweightLift.new()
	lift.name = "ShaftLift"
	lift.travel = rise
	lift.basket_offset = 5.4
	group.add_child(lift)
	lift.owner = root
	lift.global_position = Vector3(42.8, tunnel_floor, -20.0)
	_dressed(_kit_box(group, "ShaftToPits", Vector3(44.0, pit_floor, -13.0), Vector3(6.0, 4.5, 2.0), false, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	# Stones for the ballast in a heap by each stop; at the bottom, timber
	# and spare blocks to crouch behind while a guard comes to see what
	# creaked.
	var heaps := [[Vector3(39.4, tunnel_floor, -17.2), 0], [Vector3(41.0, pit_floor, -15.0), 1]]
	for h in heaps:
		for k in 5:
			var off := Vector3((k % 3) * 0.62 - 0.6, 0.0, (k / 3) * 0.7 - 0.35)
			_kit_solid(group, "Ballast%d_%d" % [h[1], k], h[0] + off, Vector3(0.55, 0.42, 0.55), null)
		_kit_solid(group, "BallastTop%d" % h[1], h[0] + Vector3(0.0, 0.42, 0.0), Vector3(0.55, 0.4, 0.55), null)
	_kit_solid(group, "TimberStack", Vector3(49.6, pit_floor, -25.6), Vector3(4.2, 1.3, 1.6), timber)
	_kit_solid(group, "TimberStackTop", Vector3(49.3, pit_floor + 1.3, -25.4), Vector3(3.6, 0.5, 1.1), timber)
	_kit_solid(group, "SpareBlockA", Vector3(50.6, pit_floor, -19.0), Vector3(1.6, 1.3, 1.6), stone)
	_kit_solid(group, "SpareBlockB", Vector3(50.8, pit_floor, -16.9), Vector3(1.4, 1.1, 1.4), stone)
	# The pits (x 30..70, z -12..30): rammed earth, a timber roof on beams,
	# a walkway along the west wall, four trenches of soldiers between
	# earthen walls, and the yard to the east with the pen.
	var pits := _kit_box(group, "ArmyPits", Vector3(50.0, pit_floor, 9.0), Vector3(40.0, 7.0, 42.0), false, 0, [
		LevelOpening.make(F.NORTH, Vector2(-6.0, 0.0), Vector2(6.0, 4.5), false),
		LevelOpening.make(F.SOUTH, Vector2(-17.0, 0.0), Vector2(3.5, 3.43), false),
	])
	_dressed(pits, timber)
	for k in 10:
		_kit_solid(group, "RoofBeam%d" % k, Vector3(50.0, pit_floor + 6.55, -10.0 + k * 4.4), Vector3(40.0, 0.45, 0.5), timber)
	var trench_x := [35.5, 42.9, 50.3, 57.7]
	for k in 4:
		if k < 3:
			var wall_x: float = trench_x[k] + 3.7
			# Rammed earth, laid in thin layers.
			var earth := _masonry(_kit_solid(group, "TrenchWall%d" % k, Vector3(wall_x, pit_floor, 9.0), Vector3(1.4, 3.0, 30.0), dirt), dirt)
			earth.course_height = 0.3
			earth.block_length = Vector2(2.5, 5.0)
			earth.stones = false
			# Posts on the earthen walls carry the roof beams.
			for b in range(1, 7):
				var z := -10.0 + b * 4.4
				_kit_solid(group, "Post%d_%d" % [k, b], Vector3(wall_x, pit_floor + 3.0, z), Vector3(0.4, 3.55, 0.4), timber)
		var ranks := StatueRanks.new()
		ranks.name = "Ranks%d" % k
		ranks.columns = 3
		ranks.rows = 12
		ranks.spacing = Vector2(1.7, 2.4)
		ranks.variation_seed = 3 + k
		var gaps := PackedVector2Array()
		for g in [[1, 2 + k], [0, 7 - k], [2, 5 + (k % 3)], [1, 10 - (k % 2)]]:
			gaps.append(Vector2(g[0], g[1]))
		ranks.gaps = gaps
		group.add_child(ranks)
		ranks.owner = root
		ranks.global_position = Vector3(trench_x[k], pit_floor, 9.0)
	# The pen in the yard, the lever by the east wall, the way the freed run.
	var lever_spot := Marker3D.new()
	lever_spot.name = "PenLever"
	group.add_child(lever_spot)
	lever_spot.owner = root
	lever_spot.global_position = Vector3(69.3, pit_floor, 22.0)
	lever_spot.rotation.y = PI * 0.5
	var flee := Node3D.new()
	flee.name = "PenWayOut"
	group.add_child(flee)
	flee.owner = root
	for p in [Vector3(64.0, pit_floor, -8.5), Vector3(31.3, pit_floor, -8.5), Vector3(31.3, pit_floor, 27.0), Vector3(33.0, pit_floor, 32.0), Vector3(33.0, pit_floor, 44.5), Vector3(21.0, pit_floor, 44.5)]:
		var m := Marker3D.new()
		flee.add_child(m)
		m.owner = root
		m.global_position = p
	var pen := WorkersPen.new()
	pen.name = "WorkersPen"
	pen.size = Vector2(4.5, 7.0)
	group.add_child(pen)
	pen.owner = root
	pen.global_position = Vector3(67.25, pit_floor, 5.5)
	pen.lever_path = pen.get_path_to(lever_spot)
	pen.flee_path = pen.get_path_to(flee)
	# The way out: south, west, and up the stair well into the tunnel by the
	# mechanism's ladder.
	_dressed(_kit_box(group, "PitsExitSouth", Vector3(33.0, pit_floor, 38.5), Vector3(3.5, 3.43, 17.0), false, 1 << F.NORTH, [
		LevelOpening.make(F.WEST, Vector2(6.0, 0.0), Vector2(3.5, 3.43), false),
	]), stone)
	_dressed(_kit_box(group, "PitsExitWest", Vector3(21.135, pit_floor, 44.5), Vector3(3.5, 3.43, 20.23), true, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	var top := -8.54
	var well := _kit_box(group, "StairWell", Vector3(7.02, pit_floor, 40.3), Vector3(8.0, 22.0, 14.0), false, 0, [
		LevelOpening.make(F.EAST, Vector2(4.2, 0.0), Vector2(3.5, 3.43), false),
		LevelOpening.make(F.WEST, Vector2(-5.3, top - pit_floor), Vector2(2.0, 3.25), false),
	])
	_dressed(well, stone)
	_dressed(_kit_box(group, "StairDoor", Vector3(2.42, top, 35.0), Vector3(2.0, 3.25, 1.2), true, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	# Three flights round a core wall: north up the west side, south up the
	# east side, north up the west side again to the landing by the door.
	var step := (top - pit_floor) / 3.0
	_masonry(_kit_solid(group, "StairCore", Vector3(7.02, pit_floor, 40.3), Vector3(1.0, top - pit_floor + 1.0, 7.9), stone), flag)
	for flight in [_kit_ramp(group, "Flight1", Vector3(4.77, pit_floor, 44.25), 0.0, step, 7.9),
			_kit_ramp(group, "Flight2", Vector3(9.27, pit_floor + step, 36.35), PI, step, 7.9),
			_kit_ramp(group, "Flight3", Vector3(4.77, pit_floor + step * 2.0, 44.25), 0.0, step, 7.9)]:
		flight.masonry = true
		flight.material = step_stone
	# The landings span the well: only the edge toward the flights shows.
	_masonry(_kit_solid(group, "LandingA", Vector3(7.02, pit_floor + step - 0.5, 34.825), Vector3(8.0, 0.5, 3.05), stone), flag).dressed_sides = 2
	_masonry(_kit_solid(group, "LandingB", Vector3(7.02, pit_floor + step * 2.0 - 0.5, 45.775), Vector3(8.0, 0.5, 3.05), stone), flag).dressed_sides = 1
	_masonry(_kit_solid(group, "LandingC", Vector3(7.02, top - 0.5, 34.825), Vector3(8.0, 0.5, 3.05), stone), flag).dressed_sides = 2
	_kit_solid(group, "LandingCRail", Vector3(9.27, top, 36.225), Vector3(3.5, 1.1, 0.25), timber)
	# A word on first seeing the army, from whichever side he comes in.
	var seen := StoryTrigger.new()
	seen.name = "PitsEnter"
	seen.dialogue = &"pits_enter"
	seen.quest_from = &"talk_liang"
	# Reaching them is a step of its own (a checkpoint follows it: they are
	# guarded, and a fall there doesn't send him back up to Liang's). It
	# waits for that step, so going down early and coming back still counts.
	var reached := StoryTrigger.new()
	reached.name = "PitsReached"
	reached.quest_step = &"descend"
	reached.completes_step = &"descend"
	for t in [seen, reached]:
		group.add_child(t)
		t.owner = root
		t.global_position = Vector3(44.0, pit_floor, 9.0)
		for spot in [[Vector3(44.0, pit_floor + 2.0, -10.0), Vector3(6.0, 4.0, 2.0), "Shape0"], [Vector3(33.0, pit_floor + 2.0, 28.0), Vector3(3.5, 4.0, 2.0), "Shape1"]]:
			var shape := CollisionShape3D.new()
			shape.name = spot[2]
			var box := BoxShape3D.new()
			box.size = spot[1]
			shape.shape = box
			t.add_child(shape)
			shape.owner = root
			shape.global_position = spot[0]
	# Light. A wall lamp's back (+z) goes against the wall.
	var lamp_scene := load("res://scenes/world/wall_lamp.tscn") as PackedScene
	for spot in [
			[Vector3(36.4, tunnel_floor + 2.4, -24.5), -PI * 0.5], [Vector3(49.5, pit_floor + 2.6, -14.4), 0.0, false],
			[Vector3(36.0, pit_floor + 2.6, -11.6), PI], [Vector3(30.4, pit_floor + 2.6, 2.0), -PI * 0.5],
			[Vector3(30.4, pit_floor + 2.6, 20.0), -PI * 0.5], [Vector3(69.6, pit_floor + 2.6, 18.5), PI * 0.5],
			[Vector3(34.35, pit_floor + 2.4, 40.0), PI * 0.5], [Vector3(10.62, pit_floor + step + 2.2, 34.5), PI * 0.5],
			[Vector3(3.42, pit_floor + step * 2.0 + 2.2, 45.5), -PI * 0.5], [Vector3(3.42, top + 2.3, 37.6), -PI * 0.5]]:
		var lamp := lamp_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		group.add_child(lamp)
		lamp.owner = root
		lamp.global_position = spot[0]
		lamp.rotation.y = spot[1]
		# The shaft's foot is dark until someone lights it.
		if spot.size() > 2:
			lamp.set(&"start_lit", spot[2])
	# Two guards: one walks the ring of the hall with a torch, the other
	# keeps the yard in front of the pen.
	var guard_scene := load("res://scenes/ai/guard.tscn") as PackedScene
	_pit_guard(guard_scene, "PitGuardRing", "PitsRing", true, Color(0.95, 0.85, 0.78), [
		[Vector3(31.3, pit_floor, -9.0), 2.5, true], [Vector3(62.2, pit_floor, -9.0), 2.0, true],
		[Vector3(62.2, pit_floor, 27.0), 1.0, false], [Vector3(31.3, pit_floor, 27.0), 2.5, true]])
	# The yard's is the commander of the pits: he walks the yard and stands
	# a while at his post, the table where he keeps his half of the tally.
	_pit_guard(guard_scene, "PitGuardYard", "PitsYard", false, Color(0.62, 0.5, 0.46), [
		[Vector3(64.0, pit_floor, -1.0), 4.0, true], [Vector3(63.6, pit_floor, 15.0), 3.0, true],
		[Vector3(67.4, pit_floor, 24.4), 7.0, false, PI]])
	_commander_post(group, Vector3(67.4, pit_floor, 25.6))
	# The inner gate in the doorway at the top of the stairs.
	var gate := TallyGate.new()
	gate.name = "InnerGate"
	group.add_child(gate)
	gate.owner = root
	gate.global_position = Vector3(2.42, top, 35.0)
	# The other way past the inner wall: the crossbow gallery, west of the pits.
	_crossbow_gallery(group, pit_floor, top)
	_log.append("under the mountain: the workers' shaft and lift, the army pits (%d trenches), the pen, the commander's post, the stair well and the inner gate" % trench_x.size())

## The other way past the inner wall: the crossbow gallery, the wall's own
## guarded way, west of the pits (x 9..25, z -20..24). In from the foot of
## the workers' shaft, under the ledge; plates down the middle of the floor,
## each firing a crossbow set in a side wall (one shot; crouch and the bolt
## goes over; stone armour and it glances off); pillars to stand behind; a
## craftsman who didn't make it. Off its north end the armoury of stone
## armour; out of its south end a passage to a ladder up through a hatch into
## the tunnel behind the inner gate, by the mechanism's ladder: no tally
## needed this way.
func _crossbow_gallery(group: Node3D, pit_floor: float, top: float) -> void:
	const F := LevelOpening.Face
	var timber := load("res://assets/materials/level/timber.tres") as Material
	var stone := load("res://assets/materials/level/walls.tres") as Material
	var flag := load("res://assets/materials/level/floortiles1.tres") as Material
	_dressed(_kit_box(group, "GalleryPassage", Vector3(32.75, pit_floor, -17.5), Vector3(3.5, 3.43, 15.5), true, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	var hall := _kit_box(group, "CrossbowGallery", Vector3(17.0, pit_floor, 2.0), Vector3(16.0, 7.0, 44.0), false, 0, [
		LevelOpening.make(F.EAST, Vector2(-19.5, 0.0), Vector2(3.5, 3.43), false),
		LevelOpening.make(F.NORTH, Vector2(0.0, 0.0), Vector2(3.0, 3.2), false),
		LevelOpening.make(F.SOUTH, Vector2(-6.0, 0.0), Vector2(3.0, 3.2), false),
	])
	_dressed(hall, timber)
	for k in 10:
		_kit_solid(group, "GalleryBeam%d" % k, Vector3(17.0, pit_floor + 6.55, -18.0 + k * 4.4), Vector3(16.0, 0.45, 0.5), timber)
	# Two rows of pillars to stand behind, between the crossbows' lines of fire.
	for k in 6:
		for x in [12.4, 21.6]:
			_masonry(_kit_solid(group, "GalleryPillar%d_%d" % [k, int(x)], Vector3(x, pit_floor, -15.4 + k * 7.24), Vector3(1.1, 7.0, 1.1), stone), null)
	# The armoury of stone armour, off the north end.
	_dressed(_kit_box(group, "Armoury", Vector3(17.0, pit_floor, -25.0), Vector3(10.0, 4.2, 10.0), false, 0, [
		LevelOpening.make(F.SOUTH, Vector2(0.0, 0.0), Vector2(3.0, 3.2), false),
	]), timber)
	var stands := Node3D.new()
	stands.name = "ArmourStands"
	group.add_child(stands)
	stands.owner = root
	var visual := load("res://scenes/items/visuals/stone_armor.tscn") as PackedScene
	var pickup_scene := load("res://scenes/items/pickup.tscn") as PackedScene
	var taken := 0
	for row in 2:
		for k in 4:
			var at := Vector3(13.2 + k * 2.55, pit_floor, -28.2 + row * 3.6)
			_kit_solid(stands, "Post%d_%d" % [row, k], at, Vector3(0.14, 1.85, 0.14), timber)
			_kit_solid(stands, "Bar%d_%d" % [row, k], at + Vector3(0.0, 1.62, 0.0), Vector3(0.12, 0.12, 0.85), timber)
			var hang := at + Vector3(0.0, 0.78, 0.0)
			# Two to take (one each, together); the rest hang there for the dead.
			if (row == 1 and k in [1, 2]):
				var p := pickup_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Pickup
				p.name = "StoneArmor%d" % taken
				stands.add_child(p)
				p.owner = root
				p.item_id = &"stone_armor"
				p.dialogue = &"armour_taken" if taken == 0 else &""
				p.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), hang)
				taken += 1
			else:
				var v := visual.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
				v.name = "Armour%d_%d" % [row, k]
				stands.add_child(v)
				v.owner = root
				v.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.5), hang)
	# The traps: a plate in the aisle, its crossbow in a side wall at chest
	# height, the sides taking turns.
	var traps := Node3D.new()
	traps.name = "GalleryTraps"
	group.add_child(traps)
	traps.owner = root
	var plate_scene := load("res://scenes/world/pressure_plate.tscn") as PackedScene
	var bow_scene := load("res://scenes/world/wall_crossbow.tscn") as PackedScene
	var zs := [-11.8, -4.6, 2.8, 10.0, 17.2]
	for i in zs.size():
		var z: float = zs[i]
		var x := 17.0 + (1.2 if i % 2 else -1.2)
		var plate := plate_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		plate.name = "Plate%d" % (i + 1)
		traps.add_child(plate)
		plate.owner = root
		plate.global_position = Vector3(x, pit_floor + 0.01, z)
		var west := i % 2 == 0
		var bow := bow_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		bow.name = "Crossbow%d" % (i + 1)
		traps.add_child(bow)
		bow.owner = root
		# It shoots along its -z: from the west wall east, from the east wall west.
		bow.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5 if west else PI * 0.5), Vector3(9.5 if west else 24.5, pit_floor + 2.2, z))
		var links: Array[NodePath] = [plate.get_path_to(bow)]
		plate.set(&"crossbow_paths", links)
	# One who didn't make it, shot down by the third.
	var fallen := (load("res://scenes/ai/craftsman.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Worker
	fallen.name = "GalleryFallen"
	traps.add_child(fallen)
	fallen.owner = root
	fallen.global_position = Vector3(18.6, pit_floor, 4.1)
	fallen.rotation.y = deg_to_rad(250.0)
	fallen.work_anim = &"collapse"
	fallen.after_sealing_anim = &"collapse"
	fallen.dead = true
	fallen.bolts = 2
	fallen.holds_tool = false
	# Out of the south end: a passage south, then west to the ladder's well.
	_dressed(_kit_box(group, "GalleryExitSouth", Vector3(11.0, pit_floor, 27.5), Vector3(3.0, 3.2, 7.0), false, 1 << F.NORTH, [
		LevelOpening.make(F.WEST, Vector2(2.0, 0.0), Vector2(3.0, 3.2), false),
	]), stone)
	_dressed(_kit_box(group, "GalleryExitWest", Vector3(5.625, pit_floor, 29.5), Vector3(3.0, 3.2, 7.75), true, (1 << F.NORTH) | (1 << F.SOUTH), []), stone)
	var rise := top - pit_floor
	# Boarded over under the tunnel's floor (its roof stops where that floor's
	# 0.6 m begins, so nothing stands proud of it), the hatch cut through both.
	_dressed(_kit_box(group, "HatchWell", Vector3(0.25, pit_floor, 29.5), Vector3(3.0, rise - 0.6, 3.0), false, 0, [
		LevelOpening.make(F.EAST, Vector2(0.0, 0.0), Vector2(3.0, 3.2), false),
		LevelOpening.make(F.CEILING, Vector2(0.0, -0.55), Vector2(1.4, 1.4), false),
	]), timber)
	var ladder := (load("res://scenes/world/climb_ladder.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as ClimbLadder
	ladder.name = "HatchLadder"
	group.add_child(ladder)
	ladder.owner = root
	ladder.global_position = Vector3(0.25, pit_floor, 28.42)
	ladder.top = Vector3(0.0, rise, 0.0)
	ladder.landing = Vector3(0.0, rise + 0.05, 2.25)
	ladder.rungs = true
	# The hatch's lid, swung open over its hinge on the west side of the hole
	# and leaning back toward the tunnel wall, battens toward the hole.
	var lid := StaticBody3D.new()
	lid.name = "HatchLid"
	group.add_child(lid)
	lid.owner = root
	lid.global_transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(16.0)), Vector3(-0.45, top, 28.95))
	var lid_shape := CollisionShape3D.new()
	lid_shape.name = "Shape"
	var lid_box := BoxShape3D.new()
	lid_box.size = Vector3(0.07, 1.4, 1.4)
	lid_shape.shape = lid_box
	lid_shape.position = Vector3(-0.035, 0.7, 0.0)
	lid.add_child(lid_shape)
	lid_shape.owner = root
	for part in [["Boards", Vector3(0.07, 1.4, 1.4), Vector3(-0.035, 0.7, 0.0)], ["Batten0", Vector3(0.05, 0.13, 1.3), Vector3(0.025, 0.3, 0.0)], ["Batten1", Vector3(0.05, 0.13, 1.3), Vector3(0.025, 1.1, 0.0)]]:
		var board := MeshInstance3D.new()
		board.name = part[0]
		var mesh := BoxMesh.new()
		mesh.size = part[1]
		board.mesh = mesh
		board.material_override = timber
		board.position = part[2]
		lid.add_child(board)
		board.owner = root
	# Light: lamps on the side walls, between the pillars.
	var lamp_scene := load("res://scenes/world/wall_lamp.tscn") as PackedScene
	for spot in [[Vector3(9.4, pit_floor + 2.6, -8.2), -PI * 0.5], [Vector3(24.6, pit_floor + 2.6, 6.4), PI * 0.5],
			[Vector3(9.4, pit_floor + 2.6, 13.6), -PI * 0.5], [Vector3(17.0, pit_floor + 2.4, -29.6), PI],
			[Vector3(11.0, pit_floor + 2.3, 30.6), 0.0]]:
		var lamp := lamp_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		group.add_child(lamp)
		lamp.owner = root
		lamp.global_position = spot[0]
		lamp.rotation.y = spot[1]
	# A word on coming in, in the armoury, and the step moving on: reaching
	# the gallery counts as getting down; coming up through the hatch, as
	# getting past the wall.
	var words := [
		["GalleryEnter", &"gallery_enter", &"talk_liang", &"", &"", Vector3(23.0, pit_floor + 2.0, -17.5), Vector3(3.0, 4.0, 3.5)],
		["GalleryReached", &"", &"", &"descend", &"descend", Vector3(30.0, pit_floor + 2.0, -17.5), Vector3(3.0, 4.0, 3.5)],
		["ArmouryEnter", &"armoury_enter", &"talk_liang", &"", &"", Vector3(17.0, pit_floor + 2.0, -21.5), Vector3(4.0, 4.0, 2.0)],
		["HatchUp", &"", &"", &"past_wall", &"past_wall", Vector3(0.25, top + 1.5, 30.6), Vector3(2.8, 3.0, 1.6)],
	]
	for w in words:
		var t := StoryTrigger.new()
		t.name = String(w[0])
		t.dialogue = w[1]
		t.quest_from = w[2]
		t.quest_step = w[3]
		t.completes_step = w[4]
		group.add_child(t)
		t.owner = root
		t.global_position = w[5]
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = w[6]
		shape.shape = box
		t.add_child(shape)
		shape.owner = root
	_log.append("crossbow gallery: %d plates and crossbows, the armoury, the hatch ladder up behind the inner wall" % zs.size())
	_gallery_watch(group, pit_floor)

## The gallery's own watch, and what can be done about it: a timber walkway
## along each long wall at mid-height with a crossbowman pacing it (he shoots
## what he sees on the floor below, though not under his own walkway, and
## the stone armour's clatter carries up to him); a crossbow on a turning
## stand by the way in, one bolt in it, to be loosed at the gong in the
## north-west corner (both men go to look at it) or at the lamp hung over
## the way out (shot down, the way out is dark); and the way out itself,
## its roof fallen on a beam: crawled under, and nobody crawls in stone.
func _gallery_watch(group: Node3D, pit_floor: float) -> void:
	var timber := load("res://assets/materials/level/timber.tres") as Material
	var stone := load("res://assets/materials/level/walls.tres") as Material
	var walk_top := pit_floor + 3.4
	# West: x 9..11.2 the length of the hall. East: x 22.8..25, from south of
	# the way in (its opening is under where the walkway would be).
	var walks := [["WalkWest", 10.1, -17.0, 19.0, 11.15, 11.0, -16.0], ["WalkEast", 23.9, -14.5, 19.0, 22.86, 23.0, -13.0]]
	for w in walks:
		var length: float = w[3] - w[2]
		var mid: float = (w[2] + w[3]) * 0.5
		_kit_solid(group, w[0], Vector3(w[1], walk_top - 0.25, mid), Vector3(2.2, 0.25, length), timber)
		_kit_solid(group, w[0] + "Parapet", Vector3(w[4], walk_top, mid), Vector3(0.12, 0.95, length), timber)
		# Posts under its edge, clear of the wall crossbows' lines.
		var k := 0
		var z: float = w[6]
		while z < w[3]:
			_kit_solid(group, "%sPost%d" % [w[0], k], Vector3(w[5], pit_floor, z), Vector3(0.28, walk_top - 0.25 - pit_floor, 0.28), timber)
			z += 6.0
			k += 1
	# The crossbowmen: up and down their walkway, a look over the floor at
	# each end.
	var scene := load("res://scenes/ai/guard.tscn") as PackedScene
	var bows := [["GalleryBowWest", 10.1, -15.5, 17.5, Color(0.8, 0.72, 0.62)], ["GalleryBowEast", 23.9, -13.0, 17.5, Color(0.7, 0.66, 0.7)]]
	for b in bows:
		_pit_guard(scene, b[0], b[0], false, b[4], [[Vector3(b[1], walk_top, b[2]), 3.0, true], [Vector3(b[1], walk_top, b[3]), 3.0, true]])
		var bow := root.get_node("Guards/" + String(b[0])) as Guard
		bow.ranged = true
		bow.carries_ji = false
		bow.held_scene = load("res://scenes/items/visuals/held_crossbow.tscn")
		bow.held_offset = Vector3(0.0, 0.05, 0.08)
		bow.held_rotation = Vector3(0.0, 180.0, 0.0)
		bow.sight_range = 34.0
		bow.own_barks = {
			&"spotted": ["XBOW_SPOTTED_1", "XBOW_SPOTTED_2"],
			&"noise": ["XBOW_NOISE_1", "XBOW_NOISE_2"],
			&"glance": ["XBOW_GLANCE_1"],
			&"lost": ["XBOW_LOST_1"],
			&"calm": ["XBOW_CALM_1"],
		}
	# The gong in the north-west corner, its face to the way in.
	var gong := Gong.new()
	gong.name = "GalleryGong"
	group.add_child(gong)
	gong.owner = root
	gong.global_position = _floor_at(Vector3(11.1, pit_floor + 0.5, -18.6))
	gong.rotation.y = PI * 0.5
	var listeners: Array[NodePath] = []
	for b in bows:
		listeners.append(gong.get_path_to(root.get_node("Guards/" + String(b[0]))))
	gong.listener_paths = listeners
	# The lamp hung over the way out, and what a bolt hits of it.
	var lamp := (load("res://scenes/world/wall_lamp.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	lamp.name = "ExitLamp"
	group.add_child(lamp)
	lamp.owner = root
	lamp.global_position = Vector3(11.0, pit_floor + 3.7, 23.55)
	var target := StaticBody3D.new()
	target.name = "BoltTarget"
	target.collision_layer = 1
	target.collision_mask = 0
	lamp.add_child(target)
	target.owner = root
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.7, 0.7)
	cs.shape = box
	target.add_child(cs)
	cs.owner = root
	cs.position = Vector3(0.0, 0.05, 0.1)
	# The crossbow on its stand, by the way in, in the dark of the corner.
	var swivel := SwivelCrossbow.new()
	swivel.name = "GallerySwivel"
	group.add_child(swivel)
	swivel.owner = root
	swivel.global_position = _floor_at(Vector3(20.6, pit_floor + 0.5, -18.6))
	var targets: Array[NodePath] = [swivel.get_path_to(gong), swivel.get_path_to(lamp)]
	swivel.target_paths = targets
	var names: Array[String] = ["SWIVEL_GONG", "SWIVEL_LAMP"]
	swivel.target_names = names
	# The way out's roof down on a beam: a stack of its blocks either side, the
	# beam across them, the rest of the roof heaped on it to the top. Under
	# the beam, a crawl.
	for side in [["FallStackWest", 9.95], ["FallStackEast", 12.05]]:
		_masonry(_kit_solid(group, side[0], Vector3(side[1], pit_floor, 24.95), Vector3(0.9, 1.15, 1.0), stone), null)
	_kit_solid(group, "FallBeam", Vector3(11.0, pit_floor + 1.15, 24.8), Vector3(3.0, 0.32, 0.4), timber)
	var heap := Rubble.new()
	heap.name = "FallHeap"
	heap.size = Vector3(3.0, 3.2 - 1.47, 1.1)
	heap.spill = 0.35
	heap.props = 1
	heap.material = stone
	heap.pattern_seed = 24
	group.add_child(heap)
	heap.owner = root
	heap.global_position = Vector3(11.0, pit_floor + 1.47, 24.85)
	# Words: on the stand, and at the fall.
	for w in [["SwivelNear", &"gallery_swivel", Vector3(20.6, pit_floor + 1.5, -17.0), Vector3(3.5, 3.0, 3.0)], ["GalleryFall", &"gallery_fall", Vector3(11.0, pit_floor + 1.5, 22.3), Vector3(4.0, 3.0, 2.0)]]:
		var t := StoryTrigger.new()
		t.name = String(w[0])
		t.dialogue = w[1]
		t.quest_from = &"descend"
		group.add_child(t)
		t.owner = root
		t.global_position = w[2]
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var tbox := BoxShape3D.new()
		tbox.size = w[3]
		shape.shape = tbox
		t.add_child(shape)
		shape.owner = root
	_log.append("crossbow gallery: two crossbowmen on walkways, the gong, the turning crossbow, the lamp over the fallen way out")

## The commander's post in the yard: a table with a lamp and a lacquered box,
## his half of the tiger tally on it.
func _commander_post(group: Node3D, at: Vector3) -> void:
	var timber := load("res://assets/materials/level/timber.tres") as Material
	var red := load("res://assets/materials/props/lacquer_red.tres") as Material
	var post := Node3D.new()
	post.name = "CommanderPost"
	group.add_child(post)
	post.owner = root
	post.global_position = at
	_kit_solid(post, "Top", at + Vector3(0.0, 0.86, 0.0), Vector3(1.4, 0.06, 0.8), timber)
	for k in 4:
		var corner := Vector3(-0.6 if k % 2 == 0 else 0.6, 0.0, -0.32 if k < 2 else 0.32)
		_kit_solid(post, "Leg%d" % k, at + corner, Vector3(0.08, 0.86, 0.08), timber)
	_kit_solid(post, "Box", at + Vector3(0.25, 0.92, 0.0), Vector3(0.36, 0.12, 0.26), red)
	var lamp := (load("res://scenes/world/oil_lamp_prop.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	lamp.name = "Lamp"
	post.add_child(lamp)
	lamp.owner = root
	lamp.global_position = at + Vector3(-0.45, 0.92, 0.1)
	var half := (load("res://scenes/items/pickup.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Pickup
	half.name = "PitTally"
	post.add_child(half)
	half.owner = root
	half.item_id = &"tally_pit"
	half.sets_flag = &"has_tally_pit"
	half.dialogue = &"tally_pit_taken"
	half.global_transform = Transform3D(Basis(Vector3.UP, 0.3), at + Vector3(0.25, 1.04, 0.0))

func _pit_guard(scene: PackedScene, guard_name: String, route_name: String, torch: bool, tint: Color, points: Array) -> void:
	var route := PatrolRoute.new()
	route.name = route_name
	root.get_node("Routes").add_child(route)
	route.owner = root
	for i in points.size():
		var m := Marker3D.new()
		m.name = "P%02d" % i
		route.add_child(m)
		m.owner = root
		m.global_position = points[i][0]
		m.set_meta(&"wait", points[i][1])
		m.set_meta(&"look", points[i][2])
		# A post: he stands facing this way.
		if points[i].size() > 3:
			m.rotation.y = points[i][3]
			m.set_meta(&"face", true)
	var guard := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	guard.name = guard_name
	root.get_node("Guards").add_child(guard)
	guard.owner = root
	guard.global_position = points[0][0]
	guard.set(&"route_path", guard.get_path_to(route))
	guard.set(&"carries_torch", torch)
	guard.set(&"armor_tint", tint)

## Act V: Wei at the last door out of the burial chamber, the south-west
## door to the drain's tunnel, while two of his men brick it up from the
## walkway (WeiLastDoor): the scene's area on the walkway before the door,
## Wei and his men, their marks, the wall begun across the door, the bricks
## and the mortar, and the beats the men keep round the walkway if the
## craftsman runs. (The tunnel beyond is too low for them to work in.)
func _wei_at_the_last_door() -> void:
	for path in ["WeiLastDoor", "Guards/WeiLast", "Guards/WeiLastManA", "Guards/WeiLastManB", "Routes/LastDoorStrip", "Routes/LastDoorCauseway"]:
		var old := root.get_node_or_null(path)
		if old != null:
			old.get_parent().remove_child(old)
			old.free()
	var door := WeiLastDoor.new()
	door.name = "WeiLastDoor"
	root.add_child(door)
	door.owner = root
	door.global_position = Vector3(-15.5, 9.0, 127.5)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(15.0, 3.6, 8.0)
	shape.shape = box
	door.add_child(shape)
	shape.owner = root
	# Between the treasures down the walkway and its south wall, a strip
	# clear to stand in.
	var marks := {
		"Post": Vector3(-12.8, 8.5, 129.95), "Watch": Vector3(-1.5, 8.5, 115.5),
		"Work0": Vector3(-17.2, 8.5, 130.0), "Work1": Vector3(-15.3, 8.5, 130.0),
		# Out on the causeway into the mercury, over the tiger (down its
		# middle: lamp posts stand along its sides).
		"Edge0": Vector3(-1.5, 8.5, 118.5), "Edge1": Vector3(-1.5, 8.5, 116.3), "Edge2": Vector3(-1.5, 8.5, 120.7),
	}
	for key in marks:
		var m := Marker3D.new()
		m.name = key
		door.add_child(m)
		m.owner = root
		m.global_position = _floor_at(marks[key])
		_log.append("last door: %s at %s" % [key, m.global_position.snapped(Vector3.ONE * 0.01)])
	# The door's opening runs between its stone jambs, x -16.9 to -14.6.
	var wall_at := _floor_at(Vector3(-16.5, 7.6, 130.55))
	var wall_mark := Marker3D.new()
	wall_mark.name = "Wall"
	door.add_child(wall_mark)
	wall_mark.owner = root
	wall_mark.global_position = wall_at + Vector3.UP * 0.4
	# Where the tiger comes down: on the mercury off the causeway's west side.
	var float_mark := Marker3D.new()
	float_mark.name = "Float"
	door.add_child(float_mark)
	float_mark.owner = root
	float_mark.global_position = Vector3(-7.0, 0.93, 118.5)
	# Up the walkway to the outer passage: east behind the treasures down
	# the south walkway, and on round out of sight. (A guard's way round the
	# chamber ends at its corner: the walkways are too narrow for him past
	# the treasures.)
	var leave := Node3D.new()
	leave.name = "Leave"
	door.add_child(leave)
	leave.owner = root
	var leave_points := [Vector3(-10.5, 8.5, 129.6), Vector3(8.0, 8.5, 129.5), Vector3(18.3, 8.5, 129.5)]
	for i in leave_points.size():
		var m := Marker3D.new()
		m.name = "P%d" % i
		leave.add_child(m)
		m.owner = root
		m.global_position = _floor_at(leave_points[i])
	# The beats they keep if he runs, in what of the chamber they can walk
	# (the strip behind the treasures and the causeway): one up and down the
	# strip past the door, to be slipped by behind his back; one between the
	# causeway and the strip's east end, by the causeway's foot both ways.
	var beats := {
		"LastDoorStrip": [[Vector3(-21.0, 8.5, 129.4), 2.5, true], [Vector3(-8.0, 8.5, 129.4), 2.0, true]],
		"LastDoorCauseway": [[Vector3(-1.5, 8.5, 120.5), 2.5, true], [Vector3(-1.5, 8.5, 129.2), 0.0, false], [Vector3(12.0, 8.5, 129.4), 2.0, true], [Vector3(-1.5, 8.5, 129.2), 0.0, false]],
	}
	var rings: Array[NodePath] = []
	for beat in beats:
		var route := PatrolRoute.new()
		route.name = beat
		root.get_node("Routes").add_child(route)
		route.owner = root
		var spots: Array = beats[beat]
		for i in spots.size():
			var m := Marker3D.new()
			m.name = "P%02d" % i
			route.add_child(m)
			m.owner = root
			m.global_position = _floor_at(spots[i][0])
			m.set_meta(&"wait", spots[i][1])
			m.set_meta(&"look", spots[i][2])
		rings.append(door.get_path_to(route))
	# Wei as he was at his desk, and his two men with torches.
	var scene := load("res://scenes/ai/guard.tscn") as PackedScene
	var wei := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Guard
	wei.name = "WeiLast"
	root.get_node("Guards").add_child(wei)
	wei.owner = root
	wei.global_position = door.get_node("Post").global_position
	wei.armor_tint = Color(0.42, 0.22, 0.2)
	wei.carries_ji = false
	wei.held_scene = load("res://scenes/items/visuals/register.tscn")
	wei.held_offset = Vector3(0.0, 0.06, 0.04)
	wei.held_rotation = Vector3(0.0, 0.0, 90.0)
	wei.voice = &"wei"
	wei.own_barks = {&"lost": ["WEI_LOST_1"]}
	var men: Array[NodePath] = []
	for i in 2:
		var man := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Guard
		man.name = "WeiLastMan%s" % ["A", "B"][i]
		root.get_node("Guards").add_child(man)
		man.owner = root
		man.global_position = door.get_node("Work%d" % i).global_position
		man.carries_torch = true
		man.armor_tint = Color(0.95, 0.9, 0.85)
		men.append(door.get_path_to(man))
	door.wei_path = door.get_path_to(wei)
	door.men_paths = men
	door.desk_wei_path = door.get_path_to(root.get_node("Guards/Wei"))
	door.post_path = ^"Post"
	door.watch_path = ^"Watch"
	var work: Array[NodePath] = [^"Work0", ^"Work1"]
	door.work_paths = work
	door.wall_path = ^"Wall"
	var edges: Array[NodePath] = [^"Edge0", ^"Edge1", ^"Edge2"]
	door.edge_paths = edges
	door.float_path = ^"Float"
	door.leave_path = ^"Leave"
	door.gap_path = ^"Gap"
	door.ring_paths = rings
	# What they're at: the first courses across the door from its west jamb
	# (a stride of it still open), a heap of bricks beside it and a trough
	# of mortar.
	var brick := load("res://assets/materials/level/brick.tres") as Material
	var bricks := Node3D.new()
	bricks.name = "Bricks"
	door.add_child(bricks)
	bricks.owner = root
	var rng := RandomNumberGenerator.new()
	rng.seed = 210
	var laid := 0
	for course in 4:
		var count := 2 if course < 3 else 1
		for k in count:
			var along := -16.88 + 0.17 + k * 0.36 + (0.09 if course % 2 else 0.0)
			_brick(bricks, "Wall%d_%d" % [course, k], Vector3(along, wall_at.y + 0.06 + course * 0.115, wall_at.z + rng.randf_range(-0.01, 0.01)), rng.randf_range(-0.02, 0.02), brick)
			laid += 1
	var heap_at := _floor_at(Vector3(-19.0, 8.5, 130.25))
	for layer in 4:
		for k in 5 - layer:
			_brick(bricks, "Heap%d_%d" % [layer, k], heap_at + Vector3((k - (4 - layer) * 0.5) * 0.36, 0.06 + layer * 0.115, (0.18 if k % 2 else 0.0) + rng.randf_range(-0.02, 0.02)), rng.randf_range(-0.06, 0.06), brick)
	var trough := MeshInstance3D.new()
	trough.name = "Trough"
	var trough_mesh := BoxMesh.new()
	trough_mesh.size = Vector3(0.9, 0.3, 0.5)
	trough.mesh = trough_mesh
	trough.material_override = load("res://assets/materials/level/timber.tres")
	bricks.add_child(trough)
	trough.owner = root
	trough.global_position = _floor_at(Vector3(-18.6, 8.5, 129.25)) + Vector3.UP * 0.15
	var mud := MeshInstance3D.new()
	mud.name = "Mortar"
	var mud_mesh := BoxMesh.new()
	mud_mesh.size = Vector3(0.8, 0.04, 0.4)
	mud.mesh = mud_mesh
	mud.material_override = load("res://assets/materials/level/dirt.tres")
	bricks.add_child(mud)
	mud.owner = root
	mud.global_position = trough.global_position + Vector3.UP * 0.14
	# Solid, so nobody walks through them (and the navmesh goes round).
	var body := StaticBody3D.new()
	body.name = "Body"
	bricks.add_child(body)
	body.owner = root
	for part in [["WallShape", Vector3(-16.47, wall_at.y + 0.25, wall_at.z), Vector3(0.82, 0.5, 0.22)], ["HeapShape", heap_at + Vector3(0.0, 0.23, 0.09), Vector3(1.8, 0.46, 0.5)], ["TroughShape", trough.global_position, Vector3(0.9, 0.3, 0.5)]]:
		var cs := CollisionShape3D.new()
		cs.name = part[0]
		var cbox := BoxShape3D.new()
		cbox.size = part[2]
		cs.shape = cbox
		body.add_child(cs)
		cs.owner = root
		cs.global_position = part[1]
	# The jade slabs down the south walkway stand 0.4-0.6 m: a man steps onto
	# them, a guard's body can't, and the navmesh (it climbs half a metre)
	# would walk him onto one. Shown to the guards and their navmesh alone
	# as what they are to them, things to go round.
	var slabs := StaticBody3D.new()
	slabs.name = "JadeSlabs"
	slabs.collision_layer = 0
	slabs.set_collision_layer_value(Guard.BLOCKERS_LAYER, true)
	slabs.collision_mask = 0
	door.add_child(slabs)
	slabs.owner = root
	for x in [[-22.1, -20.0], [-13.9, -11.8], [-5.6, -3.5], [0.6, 2.6], [8.8, 10.9], [17.1, 19.1]]:
		var cs := CollisionShape3D.new()
		cs.name = "Slab%d" % slabs.get_child_count()
		var cbox := BoxShape3D.new()
		cbox.size = Vector3(x[1] - x[0] + 0.1, 1.5, 2.1)
		cs.shape = cbox
		slabs.add_child(cs)
		cs.owner = root
		cs.global_position = Vector3((x[0] + x[1]) * 0.5, 7.54 + 0.75, 127.05)
	# The way from the strip out onto the causeway, for their scripted
	# walks: along the strip, then straight through the gap between the
	# jade slabs.
	var gap := Node3D.new()
	gap.name = "Gap"
	door.add_child(gap)
	gap.owner = root
	for i in 2:
		var m := Marker3D.new()
		m.name = "P%d" % i
		gap.add_child(m)
		m.owner = root
		m.global_position = _floor_at([Vector3(-1.5, 8.5, 129.3), Vector3(-1.5, 8.5, 126.5)][i])
	_log.append("last door: Wei, two men, %d bricks laid" % laid)

func _brick(parent: Node3D, brick_name: String, at: Vector3, yaw: float, mat: Material) -> void:
	var b := MeshInstance3D.new()
	b.name = brick_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.11, 0.17)
	b.mesh = mesh
	b.material_override = mat
	parent.add_child(b)
	b.owner = root
	b.global_position = at
	b.rotation.y = yaw

## A LevelBox built like the workshop: stone blocks, flagstones, and boards
## or slabs overhead (by the ceiling's material).
func _dressed(box: LevelBox, ceiling: Material) -> LevelBox:
	box.masonry = true
	box.wall_material = load("res://assets/materials/level/walls.tres")
	box.floor_material = load("res://assets/materials/level/floortiles1.tres")
	var variants: Array[Material] = [load("res://assets/materials/level/floortiles2.tres"), load("res://assets/materials/level/floottiles3.tres")]
	box.floor_variants = variants
	box.ceiling_material = ceiling
	return box

## A LevelSolid in courses of blocks, flagstones on top if `top` is given.
func _masonry(solid: LevelSolid, top: Material) -> LevelSolid:
	solid.masonry = true
	solid.top_material = top
	return solid

func _kit_solid(parent: Node3D, solid_name: String, bottom_centre: Vector3, solid_size: Vector3, mat: Material) -> LevelSolid:
	var s := LevelSolid.new()
	s.name = solid_name
	s.size = solid_size
	if mat != null:
		s.material = mat
	parent.add_child(s)
	s.owner = root
	s.global_position = bottom_centre
	return s

func _kit_ramp(parent: Node3D, ramp_name: String, foot: Vector3, yaw: float, ramp_rise: float, ramp_run: float) -> LevelRamp:
	var r := LevelRamp.new()
	r.name = ramp_name
	r.width = 3.4
	r.rise = ramp_rise
	r.run = ramp_run
	r.steps = 14
	parent.add_child(r)
	r.owner = root
	r.global_position = foot
	r.rotation.y = yaw
	return r

## A LevelBox on `floor_centre`, its length along world z, or along x.
func _kit_box(parent: Node3D, box_name: String, floor_centre: Vector3, box_size: Vector3, along_x: bool, open: int, holes: Array) -> LevelBox:
	var box := LevelBox.new()
	box.name = box_name
	box.size = box_size
	box.open_faces = open
	var typed: Array[LevelOpening] = []
	for h in holes:
		typed.append(h)
	box.openings = typed
	parent.add_child(box)
	box.owner = root
	box.global_position = floor_centre
	box.rotation.y = PI * 0.5 if along_x else 0.0
	return box

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
	var liang := root.get_node("Liang") as Node3D
	liang.set(&"anims", {"sit": "sit", "talk": "talk", "surprised": "surprised", "frustrated": "frustrated"})
	# His feet on the floor beside the stool he sits on (Chair_038, its seat
	# 0.45 up): the sit pose puts him on it. He was half a metre down in the
	# flagstones, sitting on the floor with his legs in it.
	# (From under the table beside him, and the same every run.)
	var at := liang.global_position + liang.global_basis.x * 0.8
	var beside := _floor_at(Vector3(at.x, -1.1, at.z))
	liang.global_position.y = beside.y
	_log.append("liang: seated talk, on his stool at %.2f" % beside.y)

## Act I: the escort keeps the craftsmen in (ExitWatch). He stands in the
## workshop's south door, the way to the trap corridor and the archives, and
## the doorway behind him is closed to the player until the sealing, when he
## walks in with the captain as before. The doorway is measured where the
## passage is narrowest.
func _exit_watch() -> void:
	var space := root.get_world_3d().direct_space_state
	var best := {}
	for i in 15:
		var z := -1.5 + i * 0.5
		var mid := Vector3(-58.1, 1.3, z)
		var left := _wall_along(space, mid, Vector3.LEFT, 7.0)
		var right := _wall_along(space, mid, Vector3.RIGHT, 7.0)
		var width := right.x - left.x
		if best.is_empty() or width < float(best["width"]):
			best = {"width": width, "z": z, "x": (left.x + right.x) * 0.5}
	var gap_z: float = best["z"]
	var gap_x: float = best["x"]
	var width: float = best["width"]
	var post := _floor_at(Vector3(gap_x, 0.0, gap_z - 0.9))
	var escort := root.get_node("Guards/GuardEscort") as Node3D
	escort.global_position = post
	escort.rotation.y = 0.0
	var story := root.get_node("Story")
	var w := story.get_node_or_null("ExitWatch") as ExitWatch
	if w == null:
		w = ExitWatch.new()
		w.name = "ExitWatch"
		story.add_child(w)
		w.owner = root
	w.global_position = post + Vector3(0.0, 1.5, -2.0)
	w.guard_path = w.get_path_to(escort)
	var cs := w.get_node_or_null("Shape") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "Shape"
		w.add_child(cs)
		cs.owner = root
	var area := BoxShape3D.new()
	area.size = Vector3(width + 2.0, 3.0, 3.6)
	cs.shape = area
	var blocker := w.get_node_or_null("Blocker") as StaticBody3D
	if blocker == null:
		blocker = StaticBody3D.new()
		blocker.name = "Blocker"
		w.add_child(blocker)
		blocker.owner = root
		var bs := CollisionShape3D.new()
		bs.name = "Shape"
		blocker.add_child(bs)
		bs.owner = root
	blocker.collision_layer = ExitWatch.BLOCK_LAYER
	blocker.collision_mask = 0
	blocker.global_position = Vector3(gap_x, post.y + 1.7, gap_z)
	var wall := BoxShape3D.new()
	wall.size = Vector3(width + 0.4, 3.4, 0.5)
	(blocker.get_node("Shape") as CollisionShape3D).shape = wall
	_log.append("exit watch: the escort in the workshop's south door, %.1f m across at z %.1f" % [width, gap_z])

## Act II: the great corridor's traps, rethought as the builders' machines.
## The old single plates (each with its crossbow, to be stepped round or cut)
## and the cracking tiles (marked with a seal) were easy to pass. Now two
## stretches of floor are laid as one trap each (TrapField): flagstones all
## alike, most of them corded to a battery of crossbows high in the walls
## (TrapBattery) that looses at whoever stands there, at the chest, the
## waist and the knee. The builders' own way across is marked with their
## workshop's sign, the master's; crouched, he can knock and hear what a
## stone is; a shard spends a volley for the few seconds the winch takes.
## The east stretch lies over the old pits: their stones tip (TiltSlab). At
## each stretch's near end the builders' brake, held, keeps it all slack
## (co-op: one holds, the other crosses); at its far end their pin locks it
## for good (TrapLever). The pits keep their spikes; the dead keep their
## places. The workshop's floor bears the same sign, for him to know it.
func _corridor_mechanisms() -> void:
	var traps := root.get_node("CorridorTraps")
	var space := root.get_world_3d().direct_space_state
	for n in ["Plate1", "Plate2", "Plate3", "Crossbow1", "Crossbow2", "Crossbow3"]:
		var old := traps.get_node_or_null(n)
		if old != null:
			traps.remove_child(old)
			old.free()
	# The pits: where the tiles lay (first run) or where their slabs are.
	var holes: Array[Vector3] = []
	for i in range(1, 8):
		var tile := traps.get_node_or_null("Tile%d" % i) as Node3D
		var slab := traps.get_node_or_null("Slab%d" % i) as Node3D
		if tile != null:
			holes.append(tile.global_position)
			traps.remove_child(tile)
			tile.free()
		elif slab != null:
			holes.append(slab.global_position)
	var slabs: Array[TiltSlab] = []
	for i in holes.size():
		var slab := traps.get_node_or_null("Slab%d" % (i + 1)) as TiltSlab
		if slab == null:
			slab = TiltSlab.new()
			slab.name = "Slab%d" % (i + 1)
			traps.add_child(slab)
			slab.owner = root
		# Level with the floor beside the pit.
		var beside := _floor_at(holes[i] + Vector3(1.4, 0.0, 0.0))
		slab.global_position = Vector3(holes[i].x, beside.y, holes[i].z)
		slab.size = 1.5
		slab.stone_seed = 700 + i
		slabs.append(slab)
	var no_slabs: Array[TiltSlab] = []
	var west := _trap_field(traps, space, "West", -50.5, -26.5, no_slabs, 31, -1)
	var east := _trap_field(traps, space, "East", -18.5, 7.0, slabs, 47, 0)
	# Their pins past each stretch (the brake is the winch's, in its niche).
	_trap_lever(traps, "PinWest", TrapLever.Kind.PIN, west, Vector3(-25.6, 0.0, west.global_position.z + 0.45), 0.0)
	_trap_lever(traps, "PinEast", TrapLever.Kind.PIN, east, Vector3(7.9, 0.0, east.global_position.z - 0.9), -PI * 0.5)
	for gone in ["BrakeWest", "BrakeEast"]:
		var old := traps.get_node_or_null(gone)
		if old != null:
			traps.remove_child(old)
			old.free()
	var workshop := root.get_node("Rooms/01_TerracottaWorkshop")
	for k in 3:
		var sign := workshop.get_node_or_null("WorkshopSign%d" % k)
		if sign != null:
			workshop.remove_child(sign)
			sign.free()
	_log.append("corridor: two trapped stretches (ways of %d and %d stones), %d tipping slabs, pins" % [west.way.size(), east.way.size(), slabs.size()])

## One trapped stretch of the corridor from x0 to x1: its stones measured
## between the walls, the builders' way laid across them, its battery in
## both walls. `end_row`: the row the way must leave by at the east end (-1:
## any).
func _trap_field(traps: Node, space: PhysicsDirectSpaceState3D, side: String, x0: float, x1: float, slabs: Array[TiltSlab], seed_value: int, end_row: int) -> TrapField:
	const CELL := 1.5
	var columns := int(round((x1 - x0) / CELL))
	# The walls: where level rays across the corridor stop, the usual value.
	var norths: Array[float] = []
	var souths: Array[float] = []
	for c in columns:
		var x := x0 + (c + 0.5) * CELL
		var floor_y := _floor_at(Vector3(x, 0.0, 15.5)).y
		var mid := Vector3(x, floor_y + 1.2, 15.5)
		norths.append(_wall_along(space, mid, Vector3.FORWARD, 9.0).z)
		souths.append(_wall_along(space, mid, Vector3.BACK, 9.0).z)
	norths.sort()
	souths.sort()
	var z_north: float = norths[norths.size() / 2]
	var z_south: float = souths[souths.size() / 2]
	var rows := int(floor((z_south - z_north - 0.3) / CELL))
	var z0 := z_north + ((z_south - z_north) - rows * CELL) * 0.5
	var field := traps.get_node_or_null("Field" + side) as TrapField
	if field == null:
		field = TrapField.new()
		field.name = "Field" + side
		traps.add_child(field)
		field.owner = root
	field.global_position = Vector3(x0, 0.0, z0)
	field.columns = columns
	field.rows = rows
	field.cell = CELL
	# Each stone's floor; a stone that would overlap a pit's slab is laid
	# round it (TRIGGER: what's left of it still gives).
	var heights := PackedFloat32Array()
	var cells := PackedByteArray()
	heights.resize(columns * rows)
	cells.resize(columns * rows)
	var blocked := {}
	for r in rows:
		for c in columns:
			var i := r * columns + c
			var centre := Vector3(x0 + (c + 0.5) * CELL, 0.0, z0 + (r + 0.5) * CELL)
			heights[i] = _floor_at(centre + Vector3.UP * 0.6).y
			cells[i] = TrapField.Cell.TRIGGER
			for slab in slabs:
				if absf(slab.global_position.x - centre.x) < (CELL + slab.size) * 0.5 - 0.05 and absf(slab.global_position.z - centre.z) < (CELL + slab.size) * 0.5 - 0.05:
					blocked[i] = true
					heights[i] = slab.global_position.y
	# Laid level across each column, on the highest of the old floor under
	# it: no stone sunk in it, none standing proud of its neighbours.
	for c in columns:
		var top := -INF
		for r in rows:
			if not blocked.has(r * columns + c):
				top = maxf(top, heights[r * columns + c])
		for r in rows:
			if not blocked.has(r * columns + c) and top > -INF:
				heights[r * columns + c] = top
	# The builders' way: west to east, a column at a time, now and then a
	# step or two across, stone to stone by their sides (never corner to
	# corner), and never by a pit.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var row := rng.randi_range(1, rows - 2)
	while blocked.has(row * columns):
		row = (row + 1) % rows
	var way: Array[Vector2i] = []
	for c in columns:
		cells[row * columns + c] = TrapField.Cell.SAFE
		way.append(Vector2i(c, row))
		var goal := row
		if c == columns - 1:
			if end_row >= 0:
				goal = end_row
		elif rng.randf() < 0.6:
			goal = clampi(row + rng.randi_range(-2, 2), 0, rows - 1)
		# How far this column can be walked along from here.
		var lo := row
		while lo > 0 and not blocked.has((lo - 1) * columns + c):
			lo -= 1
		var hi := row
		while hi < rows - 1 and not blocked.has((hi + 1) * columns + c):
			hi += 1
		goal = clampi(goal, lo, hi)
		# And the next column open where this one is left.
		if c < columns - 1:
			var best := -1
			for d in rows:
				for cand in [goal - d, goal + d]:
					if best < 0 and cand >= lo and cand <= hi and not blocked.has(cand * columns + c + 1):
						best = cand
			if best >= 0:
				goal = best
		while row != goal:
			row += 1 if goal > row else -1
			cells[row * columns + c] = TrapField.Cell.SAFE
			way.append(Vector2i(c, row))
	# Where the way turns, the stone in the corner is the builders' too: a
	# turn two stones wide, nothing to clip going round it (and room for the
	# navmesh, which keeps an agent's width off every trigger stone).
	for k in range(1, way.size() - 1):
		var a := way[k - 1]
		var b := way[k]
		var c2 := way[k + 1]
		if (b - a) != (c2 - b):
			var corner := a + (c2 - b)
			var ci := corner.y * columns + corner.x
			if corner.x >= 0 and corner.x < columns and corner.y >= 0 and corner.y < rows and not blocked.has(ci):
				cells[ci] = TrapField.Cell.SAFE
	field.heights = heights
	field.cells = cells
	field.stone_seed = seed_value
	var order := PackedInt32Array()
	for v in way:
		order.append(v.y * columns + v.x)
	field.way = order
	var slab_paths: Array[NodePath] = []
	for slab in slabs:
		slab_paths.append(field.get_path_to(slab))
	field.slab_paths = slab_paths
	# The battery: a crossbow every three stones in each wall, high up.
	var battery := traps.get_node_or_null("Battery" + side) as TrapBattery
	if battery == null:
		battery = TrapBattery.new()
		battery.name = "Battery" + side
		traps.add_child(battery)
		battery.owner = root
	battery.global_position = Vector3(x0, 0.0, z0)
	var bow_scene := load("res://scenes/world/wall_crossbow.tscn") as PackedScene
	var k := 0
	for c in range(1, columns, 3):
		for wall in 2:
			var name := "Bow%d" % k
			k += 1
			var bow := battery.get_node_or_null(name) as WallCrossbow
			if bow == null:
				bow = bow_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as WallCrossbow
				bow.name = name
				battery.add_child(bow)
				bow.owner = root
			var x := x0 + (c + 0.5) * CELL + (0.75 if wall == 1 else 0.0)
			var floor_y := _floor_at(Vector3(x, 0.0, 15.5)).y
			# North wall faces south (+z), south wall north; it looses along -z.
			var z := (z_north + 0.25) if wall == 0 else (z_south - 0.25)
			bow.global_position = Vector3(x, floor_y + 2.7, z)
			bow.rotation = Vector3(0.0, PI if wall == 0 else 0.0, 0.0)
			bow.reachable = false
	field.battery_path = field.get_path_to(battery)
	return field

func _trap_lever(traps: Node, lever_name: String, kind: TrapLever.Kind, field: TrapField, at: Vector3, yaw: float) -> void:
	var lever := traps.get_node_or_null(lever_name) as TrapLever
	if lever == null:
		lever = TrapLever.new()
		lever.name = lever_name
		traps.add_child(lever)
		lever.owner = root
	lever.kind = kind
	lever.global_position = _floor_at(at)
	lever.rotation.y = yaw
	var paths: Array[NodePath] = [lever.get_path_to(field)]
	lever.field_paths = paths

## The corridor's trapped floors are crossed by the masons' work song
## (MasonsSong), found a few lines at a time. Old Bai, who laid them, works
## in the workshop (Sculptor2, a TalkingWorker now), and his crew cut the
## middle of the first verse into the stone bench beside him. His son lies
## on the first floor's way, halfway across, with the strip of bamboo at his
## belt; the craftsman who watched him die kneels a stone off the way (the
## Mourner, talking too). By the first floor's west end, three pillars stand
## against the walls, alike; the north one nearest the floor is hollow: the
## battery's winch (WinchNiche), found by the draught on a lamp's flame.
## (North of the entry the wall runs only from the workshop's passage to the
## floor: room for the one; the two alike stand across, on the south wall.)
func _masons_song() -> void:
	var west := root.get_node("CorridorTraps/FieldWest") as TrapField
	var room := root.get_node("Rooms/01_TerracottaWorkshop")
	var bai := _make_talker(room.get_node("Sculptor2") as Worker, &"bai")
	# The masons' bench: a block of dressed stone behind him, scratched.
	var bench := room.get_node_or_null("MasonsBench") as LevelSolid
	if bench == null:
		bench = LevelSolid.new()
		bench.name = "MasonsBench"
		room.add_child(bench)
		bench.owner = root
	bench.size = Vector3(1.3, 0.55, 0.5)
	bench.material = load("res://assets/materials/level/walls.tres")
	bench.masonry = true
	var bench_at := _floor_at(bai.global_position + Vector3(1.5, 0.0, 0.7))
	bench.global_position = bench_at
	bench.rotation = Vector3.ZERO
	var lines := bench.get_node_or_null("Scratches") as MeshInstance3D
	if lines == null:
		lines = MeshInstance3D.new()
		lines.name = "Scratches"
		bench.add_child(lines)
		lines.owner = root
	lines.mesh = _scratches_mesh()
	lines.position = Vector3(0.0, 0.551, 0.12)
	var read := bench.get_node_or_null("Verse") as Readable
	if read == null:
		read = Readable.new()
		read.name = "Verse"
		bench.add_child(read)
		read.owner = root
	read.source = &"bench"
	read.position = Vector3(0.0, 0.6, 0.0)
	# The son, on the way halfway across, as he fell; the man who saw it, a
	# stone off the way beside him.
	var fallen := root.get_node("TheFallen")
	var son := fallen.get_node("ShotAtPlate3") as Worker
	var k := int(west.way.size() * 0.45)
	var at := west.centre_global(west.way[k])
	var ahead := west.centre_global(west.way[mini(k + 1, west.way.size() - 1)])
	son.global_position = Vector3(at.x, at.y - TrapField.LIFT, at.z)
	son.rotation = Vector3(0.0, atan2(ahead.x - at.x, ahead.z - at.z) + PI * 0.5, 0.0)
	var slip := son.get_node_or_null("Slip") as Readable
	if slip == null:
		slip = Readable.new()
		slip.name = "Slip"
		son.add_child(slip)
		slip.owner = root
	slip.source = &"slip"
	slip.search = true
	slip.radius = 0.6
	slip.position = Vector3(0.0, 0.3, 0.0)
	var mourner := _make_talker(fallen.get_node("Mourner") as Worker, &"mourner")
	var spot := _off_the_way(west, k)
	mourner.global_position = Vector3(spot.x, spot.y - TrapField.LIFT, spot.z)
	mourner.rotation = Vector3(0.0, atan2(at.x - spot.x, at.z - spot.z) - PI * 0.5, 0.0)
	# The pillars: the hollow one north, nearest the floor; two alike.
	var traps := root.get_node("CorridorTraps")
	var space := root.get_world_3d().direct_space_state
	var gone := traps.get_node_or_null("PillarNorth")
	if gone != null:
		traps.remove_child(gone)
		gone.free()
	var pillars := [["Winch", -53.2, true, false], ["PillarSouthWest", -57.4, false, true], ["PillarSouth", -53.2, false, true]]
	for p in pillars:
		var niche := traps.get_node_or_null(String(p[0])) as WinchNiche
		if niche == null:
			niche = WinchNiche.new()
			niche.name = String(p[0])
			traps.add_child(niche)
			niche.owner = root
		var x: float = p[1]
		var floor_y := _floor_at(Vector3(x, 0.0, 15.5)).y
		var wall := _wall_along(space, Vector3(x, floor_y + 1.2, 15.5), Vector3.BACK if p[3] else Vector3.FORWARD, 9.0)
		niche.global_position = Vector3(x, floor_y, wall.z)
		niche.rotation = Vector3(0.0, PI if p[3] else 0.0, 0.0)
		niche.real = p[2]
		if p[2]:
			niche.field_path = niche.get_path_to(west)
	_log.append("the masons' song: Bai at his bench, the bench, his son on the way (stone %d of %d), the mourner, the hollow pillar" % [k, west.way.size()])

## A craftsman who can be talked to, his clips and his place kept.
func _make_talker(w: Worker, talker: StringName) -> TalkingWorker:
	if not (w is TalkingWorker):
		var keep := {}
		for prop in ["anims", "work_anim", "after_sealing_anim", "freeze_after", "holds_tool", "dead", "bolts"]:
			keep[prop] = w.get(prop)
		w.set_script(load("res://Scripts/ai/talking_worker.gd"))
		for prop in keep:
			w.set(prop, keep[prop])
	w.set(&"talker", talker)
	return w as TalkingWorker

## A safe stone beside the way near its `k`th stone, but not on it (where
## someone can kneel without standing in the way); else the stone before.
func _off_the_way(field: TrapField, k: int) -> Vector3:
	var on_way := {}
	for i in field.way:
		on_way[i] = true
	var here := field.way[k]
	var best := -1
	var best_d := INF
	for i in field.cells.size():
		if field.kind(i) != TrapField.Cell.SAFE or on_way.has(i):
			continue
		var d := field.centre(i).distance_to(field.centre(here))
		if d < best_d:
			best_d = d
			best = i
	if best >= 0 and best_d < field.cell * 3.0:
		return field.centre_global(best)
	return field.centre_global(field.way[maxi(k - 2, 0)])

## Lines scratched along the top of the masons' bench: their verse.
func _scratches_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 4:
		var z := -0.15 + row * 0.07
		var w := 0.95 - 0.12 * float(row % 2)
		for seg in 5:
			var x0 := -w * 0.5 + seg * (w / 5.0) + 0.02
			var x1 := x0 + w / 5.0 - 0.05
			st.set_normal(Vector3.UP)
			for v in [Vector3(x0, 0.0, z), Vector3(x1, 0.0, z), Vector3(x1, 0.0, z + 0.012), Vector3(x0, 0.0, z), Vector3(x1, 0.0, z + 0.012), Vector3(x0, 0.0, z + 0.012)]:
				st.add_vertex(v)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.085, 0.07)
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	return mesh

## Where a level ray along `dir` from `from` meets a wall (or `reach` on).
func _wall_along(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1))
	return hit.position if not hit.is_empty() else from + dir * reach

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

## The jam's big decorative crossbows doubled the traps' own (or hung on the
## wrong wall, never firing): each trap now shows its own Qin crossbow.
func _one_crossbow_per_trap() -> void:
	var map := root.get_node("MapWithoutTreasure")
	for n in ["rope_crossbow_0_004", "rope_crossbow_0_007", "rope_crossbow_0_009", "rope_crossbow_0_013", "rope_crossbow_0_015"]:
		var mi := map.get_node_or_null(n) as Node3D
		if mi != null:
			mi.visible = false
	_log.append("corridor: the jam's decorative crossbows hidden")

## The jar and the cloth could only be taken after examining the
## counterweight upstairs, and looking at them before that showed nothing:
## players stood over the cloth not knowing why. They can be taken as soon
## as you're in the mechanism room (RequireItems still moves the story on
## once you have examined the counterweight and carry both).
func _jar_and_cloth_any_time() -> void:
	for n in ["Mechanism/Jar", "Mechanism/Cloth"]:
		var p := root.get_node_or_null(n) as Pickup
		if p != null:
			p.quest_from = &"reach_mechanism"
	_log.append("mechanism: jar and cloth can be taken any time")

## The great corridor is Act II's: the way from the workshop to the archives,
## with its plates and crossbows. The craftsman's word on them comes as he
## steps into it from the workshop door (it waited for Act III before, at a
## point he had already passed, and spoke of a route to the mechanism that
## never existed); a few shards lie there to try the trick on. Nobody comes
## in from the east end. At the west end, the door to the Mercury Hall is
## nailed shut, and he says so.
func _corridor_on_the_way_to_the_archives() -> void:
	var story := root.get_node("Story")
	var enter := story.get_node("CorridorEnter") as StoryTrigger
	enter.global_position = Vector3(-58.4, 1.5, 12.0)
	enter.quest_from = &"find_liang"
	enter.quest_step = &""
	enter.chapter = 0
	enter.hint = "HINT_PLATES"
	var shape := enter.get_node("Shape") as CollisionShape3D
	var box := BoxShape3D.new()
	box.size = Vector3(9.0, 3.0, 3.0)
	shape.shape = box
	var east := story.get_node_or_null("CorridorEnterEast")
	if east != null:
		story.remove_child(east)
		east.free()
	var door := story.get_node_or_null("BarredDoor") as StoryTrigger
	if door == null:
		door = StoryTrigger.new()
		door.name = "BarredDoor"
		story.add_child(door)
		door.owner = root
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var b := BoxShape3D.new()
		b.size = Vector3(4.2, 3.0, 4.0)
		cs.shape = b
		door.add_child(cs)
		cs.owner = root
	door.global_position = Vector3(-72.6, 1.5, 28.0)
	door.quest_from = &"find_liang"
	door.dialogue = &"barred_door"
	var shards := root.get_node_or_null("CorridorShards") as Pickup
	if shards == null:
		shards = (load("res://scenes/items/pickup.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Pickup
		shards.name = "CorridorShards"
		root.add_child(shards)
		shards.owner = root
	shards.item_id = &"ceramic"
	shards.count = 3
	shards.global_transform = Transform3D(Basis(Vector3.UP, 0.6), _floor_at(Vector3(-60.6, 0.2, 7.0)) + Vector3.UP * 0.02)
	_log.append("corridor: its word on entering from the workshop (Act II), shards by the door, the barred door to the Mercury Hall")

## Act II: Overseer Wei keeps his desk at the far end of the archives,
## before the sealed door between the two tripod lamps, reading out the
## names on his list and striking them off (WeiDesk). His half of the tiger
## tally lies on it, and the workers' register. He faces the room from
## behind it and only leaves it to look into a noise. A word from the
## craftsman as he first sees him, with the hint that a thrown shard draws a
## guard off.
func _wei_at_his_desk() -> void:
	var at := _floor_at(Vector3(8.2, 0.5, -60.3))
	var desk := root.get_node_or_null("WeiDesk") as WeiDesk
	if desk == null:
		desk = WeiDesk.new()
		desk.name = "WeiDesk"
		root.add_child(desk)
		desk.owner = root
	desk.global_position = at
	var routes := root.get_node("Routes")
	var route := routes.get_node_or_null("WeiDesk") as PatrolRoute
	if route == null:
		route = PatrolRoute.new()
		route.name = "WeiDesk"
		routes.add_child(route)
		route.owner = root
		var m := Marker3D.new()
		m.name = "Post"
		route.add_child(m)
		m.owner = root
	var post := route.get_node("Post") as Marker3D
	post.global_position = at + Vector3(0.0, 0.0, -1.05)
	post.rotation.y = PI
	post.set_meta(&"wait", 600.0)
	post.set_meta(&"look", false)
	post.set_meta(&"face", true)
	var wei := root.get_node("Guards/Wei") as Guard
	wei.route_path = wei.get_path_to(route)
	wei.global_position = post.global_position
	wei.rotation.y = PI
	# He speaks for himself: he knows whose name is still on his list.
	wei.voice = &"wei"
	wei.own_barks = {
		&"spotted": ["WEI_SPOTTED_1", "WEI_SPOTTED_2"],
		&"noise": ["WEI_NOISE_1"],
		&"calm": ["WEI_CALM_1"],
		&"lost": ["WEI_LOST_1"],
	}
	desk.wei_path = desk.get_path_to(wei)
	# On the desk: his half of the tally, and the register beside it.
	var half := root.get_node_or_null("WeiTally") as Pickup
	if half == null:
		half = (load("res://scenes/items/pickup.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Pickup
		half.name = "WeiTally"
		root.add_child(half)
		half.owner = root
	half.item_id = &"tally_wei"
	half.sets_flag = &"has_tally_wei"
	half.dialogue = &"tally_wei_taken"
	half.global_transform = Transform3D(Basis(Vector3.UP, -0.25), at + Vector3(0.32, WeiDesk.TOP + 0.002, 0.08))
	var register := root.get_node("Register") as Node3D
	register.global_transform = Transform3D(Basis(Vector3.UP, 0.35), at + Vector3(-0.2, WeiDesk.TOP + 0.002, 0.05))
	var story := root.get_node("Story")
	# The tally is one of two ways past the inner wall now, no step of its own.
	var in_hand := story.get_node_or_null("TallyInHand")
	if in_hand != null:
		story.remove_child(in_hand)
		in_hand.free()
	var seen := story.get_node_or_null("WeiSeen") as StoryTrigger
	if seen == null:
		seen = StoryTrigger.new()
		seen.name = "WeiSeen"
		story.add_child(seen)
		seen.owner = root
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(36.0, 3.0, 3.0)
		cs.shape = box
		seen.add_child(cs)
		cs.owner = root
	seen.global_position = Vector3(8.2, 1.5, -49.5)
	seen.quest_from = &"find_liang"
	seen.dialogue = &"wei_seen"
	seen.hint = "HINT_THROW"
	_log.append("archives: Wei at his desk, with his half of the tally and the register")
