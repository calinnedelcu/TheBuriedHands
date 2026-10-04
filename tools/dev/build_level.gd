extends Node
## Builds res://scenes/level/mausoleum.tscn from the jam-era tomb_layout.tscn:
## keeps the map geometry and lights, strips every jam gameplay node and puts
## the new systems in the same places. Safe to re-run: it always starts from
## tomb_layout.tscn.
## Usage: godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/build_level.gd

const SRC := "res://scenes/tomb_layout.tscn"
const OUT := "res://scenes/level/mausoleum.tscn"

const PLAYER := preload("res://scenes/player/player.tscn")
const GUARD := preload("res://scenes/ai/guard.tscn")
const PICKUP := preload("res://scenes/items/pickup.tscn")
const LAMP_STAND := preload("res://scenes/world/lamp_stand.tscn")
const WALL_LAMP := preload("res://scenes/world/wall_lamp.tscn")
const PLATE := preload("res://scenes/world/pressure_plate.tscn")
const CROSSBOW := preload("res://scenes/world/wall_crossbow.tscn")
const TILE := preload("res://scenes/world/collapsing_tile.tscn")
const SPIKES := preload("res://scenes/world/spike_pit.tscn")
const LADDER := preload("res://scenes/world/climb_ladder.tscn")
const STONE := preload("res://scenes/world/breakable_stone.tscn")
const COUNTERWEIGHT := preload("res://scenes/world/counterweight.tscn")

var root: Node3D
var _report: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	root = (load(SRC) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	get_tree().root.add_child(root)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	root.name = "Mausoleum"
	root.set_script(load("res://Scripts/world/level.gd"))

	var data := _record()
	_strip()
	await get_tree().physics_frame
	_build_core(data)
	_build_workshop(data)
	_build_archives(data)
	_build_liang(data)
	_build_corridor(data)
	_build_mechanism(data)
	_build_mercury(data)
	_build_treasury_and_exit(data)
	_build_lights()

	get_tree().root.remove_child(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	print("pack err=", err)
	print("save err=", ResourceSaver.save(packed, OUT), " -> ", OUT)
	for line in _report:
		print("  ", line)
	root.free()
	get_tree().quit()

# --- Recording old positions --------------------------------------------------------

func _g(path: String) -> Transform3D:
	var n := root.get_node_or_null(path) as Node3D
	if n == null:
		push_warning("missing " + path)
		return Transform3D()
	return n.global_transform

func _gp(path: String) -> Vector3:
	return _g(path).origin

func _children_positions(path: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := root.get_node_or_null(path)
	if n == null:
		return out
	for c in n.get_children():
		if c is Node3D:
			out.append((c as Node3D).global_position)
	return out

func _record() -> Dictionary:
	var d := {}
	d.spawn = _g("player")
	d.apprentice = _g("ucenic")
	d.liang = _g("monk")
	d.workers = [_g("mester-mestesugar-real"), _g("mester-mestesugar-real2"), _g("mester-mestesugar-real3")]
	d.talk_a = _gp("Rooms/01_TerracottaWorkshop/TerracottaGuard04")
	d.talk_b = _gp("Rooms/01_TerracottaWorkshop/TerracottaGuard07")
	d.guard_exit = _children_positions("Rooms/01_TerracottaWorkshop/GuardExitPath")
	d.statue = _g("Rooms/01_TerracottaWorkshop/WorkshopQuestProps/TerracottaWorkTarget")
	d.applied_bowl = _g("Rooms/01_TerracottaWorkshop/WorkshopQuestProps/TerracottaWorkTarget/AppliedClayBowlModel")
	d.bowl = _g("Rooms/01_TerracottaWorkshop/WorkshopQuestProps/ClaySlipStation")
	d.lamps = {}
	for n in ["WorkshopLamp_W", "WorkshopLamp_W2", "WorkshopLamp_E", "WorkshopLamp_E2"]:
		d.lamps[n] = _g("Rooms/01_TerracottaWorkshop/" + n)
	d.tools = {}
	var tools := root.get_node_or_null("Rooms/01_TerracottaWorkshop/FunctionalToolPickups")
	if tools != null:
		for c in tools.get_children():
			d.tools[String(c.name)] = [(c as Node3D).global_transform, String(c.get("item_id"))]
	d.routes = {}
	for area in ["PatrolArea1", "PatrolArea2", "PatrolArea3", "PatrolArea4", "PatrolArea5"]:
		d.routes[area] = _children_positions(area + "/Waypoints")
	d.plates = []
	d.crossbows = []
	for i in range(1, 6):
		var base := "MapWithoutTreasure/CrossbowTrap_Admin_0%d" % i
		d.plates.append(_g(base + "/PressurePlate"))
		d.crossbows.append(_g(base + "/Housing/Muzzle"))
	d.tiles = []
	for n in ["TrapTile2", "TrapTile3", "TrapTile4", "TrapTile5", "TrapTile6", "TrapTile7", "TrapTile8"]:
		d.tiles.append(_g("MapWithoutTreasure/" + n))
	d.spikes = []
	for n in ["SpikeTrap", "SpikeTrap2", "SpikeTrap3", "SpikeTrap4", "SpikeTrap5", "SpikeTrap6", "SpikeTrap7"]:
		d.spikes.append(_g("MapWithoutTreasure/" + n))
	d.ladders = []
	for path in ["MapWithoutTreasure/Ladder2", "Ladder", "Ladder2"]:
		d.ladders.append({
			"body": _g(path + "/Body"),
			"top": _gp(path + "/TopExit"),
			"bottom": _gp(path + "/BottomExit"),
			"root": _g(path),
		})
	d.stone_rock = "MapWithoutTreasure/TunnelEntrance2"
	d.stone = _g("MapWithoutTreasure/TunnelEntrance2")
	d.vase = _g("MercuryVase")
	d.cloth = _g("VaporMask")
	d.spill = _g("MapWithoutTreasure/MercurySpillingPoint")
	d.extract = [_g("MercuryExtractingPoint"), _g("MercuryExtractingPoint2")]
	d.vapor = []
	for path in ["MapWithoutTreasure/MercuryVaporZone", "MapWithoutTreasure/MercuryVaporZone2", "MapWithoutTreasure/MercuryVaporZone3"]:
		d.vapor.append({"area": _shapes(path + "/Area"), "sources": _children_positions(path + "/Sources")})
	d.mercury_floors = []
	for path in ["MapWithoutTreasure/Cube_215/MercuryFloor", "MapWithoutTreasure/Cube_215/MercuryFloor2", "MapWithoutTreasure/Cube_215/MercuryFloor3"]:
		d.mercury_floors.append(_shapes(path + "/Area"))
	d.trig_mech = _g("MechanismRoomEntranceTrigger")
	d.trig_mercury = _g("MercuryRoomFillingTrigger")
	d.trig_treasury = _g("TreasureRoomEntryTrigger")
	d.exit_trigger = _g("ExitLightGate3/Trigger")
	d.exit_light = _gp("ExitLightGate3/LightMarker")
	return d

## Copies the collision shapes of an Area3D as [shape, global transform] pairs.
func _shapes(path: String) -> Array:
	var out := []
	var area := root.get_node_or_null(path)
	if area == null:
		push_warning("missing area " + path)
		return out
	for c in area.get_children():
		if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
			out.append([(c as CollisionShape3D).shape.duplicate(), (c as CollisionShape3D).global_transform])
	return out

# --- Removing the jam-era gameplay -------------------------------------------------------

const DELETE := [
	"player", "OverviewCamera", "HUD", "samurai_armor_3d_model", "PauseMenu", "FailScreen", "IntroMonologue",
	"TestGuardArea", "PatrolArea1", "PatrolArea2", "PatrolArea3", "PatrolArea4", "PatrolArea5",
	"ucenic", "monk", "ApprenticeInteractBody", "LiangInteractBody",
	"mester-mestesugar-real", "mester-mestesugar-real2", "mester-mestesugar-real3",
	"MercuryVase", "VaporMask", "Ladder", "Ladder2", "MercuryExtractingPoint", "MercuryExtractingPoint2",
	"MechanismRoomEntranceTrigger", "MercuryRoomFillingTrigger", "TreasureRoomEntryTrigger",
	"MercuryRoomMusic", "MercuryRoomMusic2", "ExitLightGate3",
	"TreasureRoomUpdated/TreasureRoomMusic",
	"MapWithoutTreasure/AdministrativeSneakingMusic",
	"MapWithoutTreasure/Ladder2", "MapWithoutTreasure/MercurySpillingPoint",
	"MapWithoutTreasure/MercuryVaporZone", "MapWithoutTreasure/MercuryVaporZone2", "MapWithoutTreasure/MercuryVaporZone3",
	"MapWithoutTreasure/Cube_215/MercuryFloor", "MapWithoutTreasure/Cube_215/MercuryFloor2", "MapWithoutTreasure/Cube_215/MercuryFloor3",
	"MapWithoutTreasure/Cube_215/ExitLightGate", "MapWithoutTreasure/Cube_215/ExitLightGate2",
	"MapWithoutTreasure/TunnelEntrance2/BreakableInteractable", "MapWithoutTreasure/TunnelEntrance2/BreakPromptRange",
	"MapWithoutTreasure/TunnelEntrance2/BreakableRockGlow",
	"Rooms/01_TerracottaWorkshop/WorkshopMusic", "Rooms/01_TerracottaWorkshop/WorkshopMusic2",
	"Rooms/01_TerracottaWorkshop/FunctionalToolPickups", "Rooms/01_TerracottaWorkshop/GuardWaypoints",
	"Rooms/01_TerracottaWorkshop/GuardLive2", "Rooms/01_TerracottaWorkshop/GuardExitPath",
	"Rooms/01_TerracottaWorkshop/WorkshopLamp_W", "Rooms/01_TerracottaWorkshop/WorkshopLamp_W2",
	"Rooms/01_TerracottaWorkshop/WorkshopLamp_E", "Rooms/01_TerracottaWorkshop/WorkshopLamp_E2",
	"Rooms/01_TerracottaWorkshop/WorkshopQuestProps",
]

func _strip() -> void:
	for path in DELETE:
		_delete(path)
	for i in range(1, 8):
		_delete("Rooms/01_TerracottaWorkshop/TerracottaGuard0%d" % i)
	for i in range(1, 6):
		_delete("MapWithoutTreasure/CrossbowTrap_Admin_0%d" % i)
	for n in ["TrapTile2", "TrapTile3", "TrapTile4", "TrapTile5", "TrapTile6", "TrapTile7", "TrapTile8", "SpikeTrap", "SpikeTrap2", "SpikeTrap3", "SpikeTrap4", "SpikeTrap5", "SpikeTrap6", "SpikeTrap7"]:
		_delete("MapWithoutTreasure/" + n)
	# The jam's runtime sconce light builder is replaced by WallLamp nodes.
	var map := root.get_node("MapWithoutTreasure")
	map.set_script(null)

func _delete(path: String) -> void:
	var n := root.get_node_or_null(path)
	if n == null:
		_report.append("delete: missing " + path)
		return
	n.get_parent().remove_child(n)
	n.free()

# --- Helpers -----------------------------------------------------------------------------

func _own(node: Node) -> void:
	node.owner = root
	for c in node.get_children():
		if c.owner == null:
			_own(c)

func _add(parent: Node, node: Node, xform := Transform3D.IDENTITY, set_xform := true) -> Node:
	parent.add_child(node, true)
	node.owner = root
	if set_xform and node is Node3D:
		(node as Node3D).global_transform = xform
	return node

func _group(name: String, parent: Node = null) -> Node3D:
	var p := parent if parent != null else root
	var existing := p.get_node_or_null(name)
	if existing != null:
		return existing
	var n := Node3D.new()
	n.name = name
	_add(p, n, Transform3D.IDENTITY, false)
	return n

func _yaw_of(b: Basis) -> float:
	var x := b.x.normalized()
	return atan2(-x.z, x.x)

func _floor(at: Vector3, up := 3.0, down := 12.0) -> Vector3:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * up, at + Vector3.DOWN * down, 1))
	return hit.position if not hit.is_empty() else at

func _route(name: String, parent: Node, points: Array[Vector3], waits := {}) -> PatrolRoute:
	var r := Node3D.new()
	r.name = name
	r.set_script(load("res://Scripts/ai/patrol_route.gd"))
	_add(parent, r, Transform3D.IDENTITY, false)
	for i in points.size():
		var m := Marker3D.new()
		m.name = "P%02d" % i
		_add(r, m, Transform3D(Basis(), _floor(points[i])))
		if waits.has(i):
			m.set_meta(&"wait", waits[i])
			m.set_meta(&"look", true)
	return r as PatrolRoute

func _guard(name: String, parent: Node, at: Vector3, route: PatrolRoute, yaw := 0.0) -> Guard:
	var g := GUARD.instantiate() as Guard
	g.name = name
	_add(parent, g, Transform3D(Basis(Vector3.UP, yaw), _floor(at) + Vector3.UP * 0.05))
	if route != null:
		g.route_path = g.get_path_to(route)
	return g

func _pickup(name: String, parent: Node, item: StringName, xform: Transform3D, props := {}) -> Pickup:
	var p := PICKUP.instantiate() as Pickup
	p.name = name
	p.item_id = item
	for k in props:
		p.set(k, props[k])
	_add(parent, p, xform)
	return p

func _trigger(name: String, parent: Node, xform: Transform3D, size: Vector3, props: Dictionary) -> StoryTrigger:
	var t := Area3D.new()
	t.name = name
	t.set_script(load("res://Scripts/level/story_trigger.gd"))
	for k in props:
		t.set(k, props[k])
	_add(parent, t, xform)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	_add(t, cs, Transform3D.IDENTITY, false)
	return t as StoryTrigger

func _npc_model(parent: Node3D, scene: String, old: Transform3D) -> Node3D:
	var m: Node3D = (load(scene) as PackedScene).instantiate()
	m.name = "Model"
	var s := old.basis.x.length()
	_add(parent, m, Transform3D.IDENTITY, false)
	m.scale = Vector3.ONE * s
	return m

func _body_with_usable(parent: Node, name: String, shape: Shape3D, offset: Vector3, layer := 16, delegate := ^"../..") -> DelegateUsable:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = layer
	body.collision_mask = 0
	_add(parent, body, Transform3D.IDENTITY, false)
	body.position = offset
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = shape
	_add(body, cs, Transform3D.IDENTITY, false)
	var u := Node.new()
	u.name = "Usable"
	u.set_script(load("res://Scripts/interaction/delegate_usable.gd"))
	u.set(&"delegate_path", delegate)
	_add(body, u, Transform3D.IDENTITY, false)
	return u as DelegateUsable

func _capsule(r: float, h: float) -> CapsuleShape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	return c

func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b

# --- Core ------------------------------------------------------------------------------

func _build_core(d: Dictionary) -> void:
	var player := PLAYER.instantiate()
	player.name = "Player"
	var spawn: Transform3D = d.spawn
	_add(root, player, Transform3D(Basis(Vector3.UP, spawn.basis.get_euler().y), _floor(spawn.origin)))
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.agent_height = 3.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 4.0
	region.navigation_mesh = nm
	_add(root, region, Transform3D.IDENTITY, false)
	var dir := Node.new()
	dir.name = "Story"
	dir.set_script(load("res://Scripts/level/story_director.gd"))
	_add(root, dir, Transform3D.IDENTITY, false)

# --- Act I: the workshop ------------------------------------------------------------------

func _build_workshop(d: Dictionary) -> void:
	var ws := root.get_node("Rooms/01_TerracottaWorkshop")
	var story := root.get_node("Story")
	# Apprentice.
	var appr := Node3D.new()
	appr.name = "Apprentice"
	appr.set_script(load("res://Scripts/level/apprentice_npc.gd"))
	var at: Transform3D = d.apprentice
	_add(ws, appr, Transform3D(Basis(Vector3.UP, _yaw_of(at.basis)), at.origin))
	_npc_model(appr, "res://TripoModels/ucenic.glb", at)
	appr.set(&"speaker_id", &"apprentice")
	appr.set(&"anims", {"point": "NlaTrack_001_Armature", "bow": "NlaTrack_002_Armature", "work": "NlaTrack_003_Armature", "idle": "NlaTrack_004_Armature", "idle_hips": "NlaTrack_005_Armature", "talk": "NlaTrack_Armature", "scared": "NlaTrack_002_Armature"})
	appr.set(&"idle_anim", &"work")
	_body_with_usable(appr, "TalkBody", _capsule(0.6, 2.6), Vector3(0, 1.3, 0), 4 | 16)
	# Where he cowers after the sealing: the west corner, face to the wall.
	var hide := Marker3D.new()
	hide.name = "ApprenticeHideSpot"
	_add(ws, hide, Transform3D(Basis(Vector3.UP, PI), _floor(Vector3(-79.5, 0.0, -11.5))))
	appr.set(&"hide_spot_path", appr.get_path_to(hide))
	# The statue.
	var statue := Node3D.new()
	statue.name = "ClayStatue"
	statue.set_script(load("res://Scripts/level/clay_statue.gd"))
	var st: Transform3D = d.statue
	_add(ws, statue, Transform3D(Basis(Vector3.UP, st.basis.get_euler().y), st.origin))
	var placed := (load("res://scenes/items/claybowl.glb") as PackedScene).instantiate() as Node3D
	placed.name = "PlacedBowl"
	_add(statue, placed, Transform3D(Basis().scaled(Vector3.ONE * 0.6), _floor(st.origin + Vector3(0.9, 1.0, 0.4), 0.5, 2.0)))
	statue.set(&"placed_bowl_path", NodePath("PlacedBowl"))
	_body_with_usable(statue, "Body", _box(Vector3(1.6, 2.2, 1.6)), Vector3(0, 0.6, 0))
	# The bowl of slip, far end of the workshop.
	var bt: Transform3D = d.bowl
	_pickup("SlipBowl", ws, &"clay_bowl", Transform3D(Basis(), bt.origin), {"quest_step": &"fetch_slip", "completes_step": &"fetch_slip", "dialogue": &"bowl_taken"})
	# The chisel that rolls under the bench by the statue.
	_pickup("FallenChisel", ws, &"chisel", Transform3D(Basis(Vector3.UP, 1.2), _floor(st.origin + Vector3(-1.4, 0.0, 1.1), 0.6, 3.0)), {"quest_from": &"find_chisel", "completes_step": &"find_chisel", "dialogue": &"chisel_found"})
	# Lamps.
	var lamps: Dictionary = d.lamps
	var oils := {"WorkshopLamp_W": 100.0, "WorkshopLamp_W2": 45.0, "WorkshopLamp_E": 30.0, "WorkshopLamp_E2": 55.0}
	for n in lamps:
		var lt: Transform3D = lamps[n]
		var stand := LAMP_STAND.instantiate()
		stand.name = n.replace("WorkshopLamp", "LampStand")
		stand.set(&"oil", oils[n])
		if n == "WorkshopLamp_W":
			stand.set(&"start_lit", true)
			stand.set(&"completes_step", &"take_lamp")
			stand.set(&"dialogue", &"lamp_taken")
		_add(ws, stand, Transform3D(Basis(Vector3.UP, lt.basis.get_euler().y), lt.origin))
	# Ceramic shards to throw, on the east tables.
	for name in d.tools:
		var entry: Array = d.tools[name]
		if entry[1] == "ceramic":
			_pickup("Shards_" + name, ws, &"ceramic", entry[0], {"count": 4})
	# Workers.
	var anims := {"work": "NlaTrack_001_Armature", "idle": "NlaTrack_002_Armature", "collapse": "NlaTrack_003_Armature", "kneel": "NlaTrack_004_Armature", "walk": "NlaTrack_Armature"}
	var work_anims := [&"work", &"kneel", &"work"]
	for i in d.workers.size():
		var wt: Transform3D = d.workers[i]
		var w := Node3D.new()
		w.name = "Worker%d" % (i + 1)
		w.set_script(load("res://Scripts/ai/worker.gd"))
		_add(ws, w, Transform3D(Basis(Vector3.UP, _yaw_of(wt.basis)), wt.origin))
		_npc_model(w, "res://TripoModels/mester-mestesugar-real.glb", wt)
		w.set(&"anims", anims)
		w.set(&"work_anim", work_anims[i])
		w.set(&"after_sealing_anim", &"kneel")
	# The two guards of the sealing scene wait in the corridor, out of sight.
	var exit_points: Array[Vector3] = d.guard_exit
	var guards := _group("Guards")
	var ga := _guard("GuardCaptain", guards, exit_points[6], null, PI)
	var gb := _guard("GuardEscort", guards, exit_points[7], null, PI)
	var spots := _group("SealingMarks", ws)
	var spot_a := Marker3D.new()
	spot_a.name = "TalkSpotA"
	_add(spots, spot_a, Transform3D(Basis(), _floor(Vector3(-57.0, 0, -6.0))))
	var spot_b := Marker3D.new()
	spot_b.name = "TalkSpotB"
	_add(spots, spot_b, Transform3D(Basis(), _floor(Vector3(-59.5, 0, -4.2))))
	var exit_route := Node3D.new()
	exit_route.name = "GuardExit"
	_add(spots, exit_route, Transform3D.IDENTITY, false)
	for i in exit_points.size():
		if i % 2 == 0 or i == exit_points.size() - 1:
			var m := Marker3D.new()
			m.name = "E%02d" % i
			_add(exit_route, m, Transform3D(Basis(), _floor(exit_points[i])))
	var dust := root.get_node_or_null("Rooms/01_TerracottaWorkshop/Dust")
	var seq := Node.new()
	seq.name = "SealingSequence"
	seq.set_script(load("res://Scripts/level/sealing_sequence.gd"))
	_add(story, seq, Transform3D.IDENTITY, false)
	seq.set(&"guard_a_path", seq.get_path_to(ga))
	seq.set(&"guard_b_path", seq.get_path_to(gb))
	seq.set(&"talk_spot_a_path", seq.get_path_to(spot_a))
	seq.set(&"talk_spot_b_path", seq.get_path_to(spot_b))
	seq.set(&"exit_path", seq.get_path_to(exit_route))
	if dust != null:
		seq.set(&"dust_path", seq.get_path_to(dust))
	seq.set(&"after_route_a", 0)
	seq.set(&"after_route_b", 0)
	_report.append("workshop: apprentice, statue, bowl, chisel, %d lamps, %d workers, sealing guards" % [lamps.size(), d.workers.size()])

# --- Act II: the archives ----------------------------------------------------------------

func _build_archives(d: Dictionary) -> void:
	var guards := _group("Guards")
	var routes := _group("Routes")
	var r: Dictionary = d.routes
	var r1 := _route("ArchiveSouth", routes, r["PatrolArea1"], {1: 2.5})
	var r2 := _route("ArchiveEast", routes, r["PatrolArea2"], {0: 2.0, 2: 2.0})
	var r3 := _route("ArchiveNorthWest", routes, r["PatrolArea3"], {0: 3.0, 1: 3.0})
	var r5 := _route("ArchiveNorthEast", routes, r["PatrolArea5"], {1: 2.5})
	var r4 := _route("ArchiveDoor", routes, r["PatrolArea4"], {0: 2.0})
	_guard("ArchiveGuard1", guards, r["PatrolArea1"][0], r1)
	_guard("ArchiveGuard2", guards, r["PatrolArea2"][0], r2)
	_guard("ArchiveGuard3", guards, r["PatrolArea3"][0], r3)
	_guard("ArchiveGuard4", guards, r["PatrolArea5"][0], r5)
	# The sealing-scene guards take over the door route and the corridor watch.
	var captain := guards.get_node("GuardCaptain") as Guard
	captain.route_path = captain.get_path_to(r4)
	var corridor := _route("CorridorWatch", routes, [Vector3(-2.0, 0, 16.3), Vector3(16.0, 0, 16.3)], {0: 3.0, 1: 3.0})
	var escort := guards.get_node("GuardEscort") as Guard
	escort.route_path = escort.get_path_to(corridor)
	# The workers' register — optional evidence.
	_pickup("Register", root, &"register", Transform3D(Basis(Vector3.UP, 0.4), _floor(Vector3(19.5, 3.0, -50.5), 3.0, 5.0) + Vector3.UP * 0.02), {"quest_from": &"find_liang", "dialogue": &"evidence_found", "sets_flag": &"has_evidence"})
	var story := root.get_node("Story")
	_trigger("ArchivesEnter", story, Transform3D(Basis(), Vector3(6.0, 1.5, -2.0)), Vector3(10, 3, 3), {"quest_from": &"find_liang", "dialogue": &"archives_enter"})
	# Shards to throw.
	_pickup("ArchiveShards", root, &"ceramic", Transform3D(Basis(), _floor(Vector3(-6.0, 3.0, -8.0))), {"count": 3})
	_report.append("archives: 4 patrols + 2 sealing guards, register, enter trigger")

# --- Liang ---------------------------------------------------------------------------------

func _build_liang(d: Dictionary) -> void:
	var liang := Node3D.new()
	liang.name = "Liang"
	liang.set_script(load("res://Scripts/ai/npc.gd"))
	var lt: Transform3D = d.liang
	_add(root, liang, Transform3D(Basis(Vector3.UP, _yaw_of(lt.basis)), lt.origin))
	var m := _npc_model(liang, "res://TripoModels/monk.glb", lt)
	m.scale = Vector3.ONE * 3.0
	liang.set(&"speaker_id", &"liang")
	liang.set(&"anims", {"sit": "NlaTrack_001_Armature", "talk": "NlaTrack_002_Armature", "frustrated": "NlaTrack_Armature", "surprised": "NlaTrack_Armature"})
	liang.set(&"idle_anim", &"sit")
	liang.set(&"face_player", false)
	liang.set(&"dialogue", &"liang_talk")
	liang.set(&"talk_step", &"talk_liang")
	liang.set(&"completes_step", &"talk_liang")
	_body_with_usable(liang, "TalkBody", _capsule(0.7, 2.6), Vector3(0, 2.0, 0), 4 | 16)
	var story := root.get_node("Story")
	_trigger("LiangRoomEnter", story, Transform3D(Basis(), Vector3(lt.origin.x, 2.0, lt.origin.z + 8.0)), Vector3(14, 4, 6), {"quest_step": &"find_liang", "completes_step": &"find_liang"})
	# One wedge and one mallet on Liang's benches (tools are carried one of each).
	var placed := {}
	for name in d.tools:
		var entry: Array = d.tools[name]
		var pos: Vector3 = (entry[0] as Transform3D).origin
		if pos.x > 25.0 and entry[1] in ["hammer", "wedge"] and not placed.has(entry[1]):
			placed[entry[1]] = true
			_pickup("Tool_" + name, root, StringName(entry[1]), entry[0])
	# The stone over the service shaft.
	var stone := STONE.instantiate()
	stone.name = "ShaftStone"
	var s: Transform3D = d.stone
	_add(root, stone, Transform3D(Basis(), _floor(s.origin, 1.0, 3.0)))
	stone.set(&"external_rock_path", stone.get_path_to(root.get_node(d.stone_rock)))
	stone.set(&"external_body_path", stone.get_path_to(root.get_node(d.stone_rock + "/TunnelEntrance2_col")))
	_report.append("liang: npc, room trigger, tools, shaft stone")

# --- Act III: the crossbow corridor ------------------------------------------------------

func _build_corridor(d: Dictionary) -> void:
	var traps := _group("CorridorTraps")
	for i in d.plates.size():
		var pt: Transform3D = d.plates[i]
		var plate := PLATE.instantiate()
		plate.name = "Plate%d" % (i + 1)
		_add(traps, plate, Transform3D(Basis(), _floor(pt.origin, 1.0, 2.0) + Vector3.UP * 0.01))
		# A crossbow in the north wall shooting south across the plate, at chest height.
		var cb := CROSSBOW.instantiate()
		cb.name = "Crossbow%d" % (i + 1)
		var wall := _wall_toward(pt.origin + Vector3.UP * 2.2, Vector3(0, 0, -1))
		_add(traps, cb, Transform3D(Basis(Vector3.UP, PI), wall + Vector3(0, 0, 0.5)))
		plate.set(&"crossbow_paths", [plate.get_path_to(cb)])
	for i in d.tiles.size():
		var tt: Transform3D = d.tiles[i]
		var tile := TILE.instantiate()
		tile.name = "Tile%d" % (i + 1)
		_add(traps, tile, Transform3D(Basis(), tt.origin))
	for i in d.spikes.size():
		var spk: Transform3D = d.spikes[i]
		var pit := SPIKES.instantiate()
		pit.name = "Spikes%d" % (i + 1)
		_add(traps, pit, Transform3D(Basis(), spk.origin))
	var story := root.get_node("Story")
	_trigger("CorridorEnter", story, Transform3D(Basis(), Vector3(-40.0, 1.5, 13.0)), Vector3(4, 3, 12), {"quest_from": &"reach_mechanism", "dialogue": &"corridor_enter"})
	_trigger("CorridorEnterEast", story, Transform3D(Basis(), Vector3(22.0, 1.5, 13.0)), Vector3(4, 3, 12), {"quest_from": &"reach_mechanism", "dialogue": &"corridor_enter"})
	_report.append("corridor: %d plates/crossbows, %d tiles, %d spike pits" % [d.plates.size(), d.tiles.size(), d.spikes.size()])

func _wall_toward(from: Vector3, dir: Vector3) -> Vector3:
	var space := (root as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 20.0, 1))
	return hit.position if not hit.is_empty() else from + dir * 6.0

# --- Act IV: mechanism chamber --------------------------------------------------------------

func _build_mechanism(d: Dictionary) -> void:
	var mech := _group("Mechanism")
	for i in d.ladders.size():
		var l: Dictionary = d.ladders[i]
		var ladder := LADDER.instantiate()
		ladder.name = "Ladder%d" % (i + 1)
		var bottom: Vector3 = l.bottom
		var top: Vector3 = l.top
		# The ladder faces away from the wall: its -Z points from the climber
		# toward the rungs, the same way the top exit steps off.
		var into := (top - bottom).slide(Vector3.UP)
		if into.length() < 0.05:
			into = -(l.root as Transform3D).basis.z.slide(Vector3.UP)
		into = into.normalized()
		var yaw := atan2(-into.x, -into.z)
		_add(mech, ladder, Transform3D(Basis(Vector3.UP, yaw), bottom))
		(ladder.get_node("Top") as Node3D).global_position = top
		(ladder.get_node("TopLanding") as Node3D).global_position = top + Vector3.UP * 0.3 + into * 0.9
		var shape := (ladder.get_node("Body/Shape") as CollisionShape3D)
		var h := top.y - bottom.y
		var box := BoxShape3D.new()
		box.size = Vector3(1.3, h, 0.7)
		shape.shape = box
		shape.position = Vector3(0, h * 0.5, 0)
		var model := (load("res://scenes/items/Ladder.glb") as PackedScene).instantiate() as Node3D
		model.name = "Model"
		_add(ladder, model, l.body)
	var story := root.get_node("Story")
	var tm: Transform3D = d.trig_mech
	_trigger("MechanismEnter", story, tm, Vector3(8, 4, 4), {"quest_step": &"reach_mechanism", "completes_step": &"reach_mechanism", "dialogue": &"mechanism_enter"})
	_trigger("TunnelsEnter", story, Transform3D(Basis(), Vector3(46.0, -5.5, -40.0)), Vector3(6, 3, 6), {"quest_from": &"talk_liang", "dialogue": &"tunnels_enter"})
	_pickup("Jar", mech, &"vase", Transform3D(Basis(), (d.vase as Transform3D).origin), {"quest_from": &"get_vase"})
	_pickup("Cloth", mech, &"cloth", Transform3D(Basis(), (d.cloth as Transform3D).origin), {"quest_from": &"get_vase"})
	var req := Node.new()
	req.name = "JarAndCloth"
	req.set_script(load("res://Scripts/level/require_items.gd"))
	req.set(&"step", &"get_vase")
	req.set(&"items", [&"vase", &"cloth"] as Array[StringName])
	_add(story, req, Transform3D.IDENTITY, false)
	var cw := COUNTERWEIGHT.instantiate()
	cw.name = "Counterweight"
	_add(mech, cw, Transform3D(Basis(), (d.spill as Transform3D).origin + Vector3.UP * 0.6))
	var balance := root.get_node_or_null("MapWithoutTreasure/Balanta")
	if balance != null:
		cw.set(&"balance_path", cw.get_path_to(balance))
	var jet := root.get_node_or_null("MapWithoutTreasure/MercuryFlowingPoint")
	if jet != null:
		cw.set(&"flow_paths", [cw.get_path_to(jet)])
	_report.append("mechanism: 3 ladders, triggers, jar/cloth, counterweight")

# --- Act IV: the Mercury Hall -----------------------------------------------------------------

func _build_mercury(d: Dictionary) -> void:
	var hall := _group("MercuryHall")
	for i in d.vapor.size():
		var v: Dictionary = d.vapor[i]
		var zone := Area3D.new()
		zone.name = "Fumes%d" % (i + 1)
		zone.set_script(load("res://Scripts/world/vapor_zone.gd"))
		_add(hall, zone, Transform3D.IDENTITY, false)
		for pair in v.area:
			var cs := CollisionShape3D.new()
			cs.name = "Shape"
			cs.shape = pair[0]
			_add(zone, cs, pair[1])
		for p in v.sources:
			var m := Marker3D.new()
			m.name = "Source"
			_add(zone, m, Transform3D(Basis(), p))
		zone.set(&"ambient", 0.18 if i == 0 else 0.3)
	for i in d.mercury_floors.size():
		var pool := Area3D.new()
		pool.name = "Mercury%d" % (i + 1)
		pool.set_script(load("res://Scripts/world/mercury_pool.gd"))
		_add(hall, pool, Transform3D.IDENTITY, false)
		for pair in d.mercury_floors[i]:
			var cs := CollisionShape3D.new()
			cs.name = "Shape"
			cs.shape = pair[0]
			_add(pool, cs, pair[1])
	for i in d.extract.size():
		var et: Transform3D = d.extract[i]
		var pool := Area3D.new()
		pool.name = "FillPoint%d" % (i + 1)
		pool.set_script(load("res://Scripts/world/mercury_pool.gd"))
		pool.set(&"vapor", 0.0)
		pool.set(&"drag", 1.0)
		_add(hall, pool, Transform3D(Basis(), et.origin))
		var body := StaticBody3D.new()
		body.name = "UseBody"
		body.collision_layer = 16
		body.collision_mask = 0
		_add(pool, body, Transform3D(Basis(), et.origin + Vector3.UP * 0.8))
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _box(Vector3(1.6, 1.6, 1.6))
		_add(body, cs, Transform3D.IDENTITY, false)
		var u := Node.new()
		u.name = "Usable"
		u.set_script(load("res://Scripts/interaction/delegate_usable.gd"))
		u.set(&"delegate_path", ^"../..")
		u.set(&"highlight", false)
		_add(body, u, Transform3D.IDENTITY, false)
	var story := root.get_node("Story")
	_trigger("MercuryEnter", story, d.trig_mercury, Vector3(8, 4, 8), {"quest_from": &"fill_vase", "dialogue": &"mercury_enter"})
	_report.append("mercury: %d fume zones, %d pools, %d fill points" % [d.vapor.size(), d.mercury_floors.size(), d.extract.size()])

# --- Act V ---------------------------------------------------------------------------------------

func _build_treasury_and_exit(d: Dictionary) -> void:
	var story := root.get_node("Story")
	_trigger("TreasuryEnter", story, d.trig_treasury, Vector3(10, 4, 4), {"quest_from": &"find_drain", "dialogue": &"treasury_enter"})
	var drain := root.get_node_or_null("SqueezeTunnelCollapse")
	if drain != null:
		drain.name = "Drain"
		drain.set_script(load("res://Scripts/world/drain_crawl.gd"))
		for n in ["SqueezeAudio", "GravelAudio", "StonesAudio", "CinematicAudio", "PassageGate/GateVisual", "CollapseBlocker/CollisionShape3D", "EntryBody/Interactable", "SqueezeFocus", "CollapseFocus"]:
			var c := drain.get_node_or_null(n)
			if c != null:
				c.get_parent().remove_child(c)
				c.free()
		var entry := drain.get_node("EntryBody") as StaticBody3D
		entry.collision_layer = 16
		entry.collision_mask = 0
		var u := Node.new()
		u.name = "Usable"
		u.set_script(load("res://Scripts/interaction/delegate_usable.gd"))
		u.set(&"delegate_path", ^"../..")
		u.set(&"highlight", false)
		_add(entry, u, Transform3D.IDENTITY, false)
	var exit := Area3D.new()
	exit.name = "ExitLight"
	exit.set_script(load("res://Scripts/level/exit_light.gd"))
	_add(story, exit, d.exit_trigger)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _box(Vector3(6, 6, 3))
	_add(exit, cs, Transform3D.IDENTITY, false)
	var marker := Marker3D.new()
	marker.name = "Light"
	_add(exit, marker, Transform3D(Basis(), d.exit_light))
	exit.set(&"light_path", NodePath("Light"))
	_report.append("act V: treasury trigger, drain, exit")

# --- Lights ------------------------------------------------------------------------------------

func _build_lights() -> void:
	var swapped := 0
	for n in root.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		var s := l.get_script() as Script
		if s != null and s.resource_path.ends_with("static_lamp_flicker.gd"):
			l.set_script(load("res://Scripts/world/flicker_light.gd"))
			swapped += 1
	# Sconces of the map get a burning, refillable lamp.
	var map := root.get_node("MapWithoutTreasure")
	var lamps := _group("WallLamps")
	var count := 0
	for n in map.find_children("*tripo_node_e3fb4dc2*", "Node3D", true, false):
		var name := String(n.name).to_lower()
		if "_col" in name or "collision" in name or not (n is MeshInstance3D):
			continue
		var sconce := n as Node3D
		var wl := WALL_LAMP.instantiate()
		wl.name = "Sconce%02d" % count
		var top := sconce.global_transform * Vector3(0, 0.4, 0)
		_add(lamps, wl, Transform3D(Basis(), top))
		(wl.get_node("Model") as Node3D).visible = false
		wl.set(&"oil", [40.0, 60.0, 80.0][count % 3])
		count += 1
	_report.append("lights: %d flicker lights converted, %d sconces" % [swapped, count])
