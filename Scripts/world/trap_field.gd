@tool
class_name TrapField
extends Node3D
## A stretch of corridor floor the tomb's builders laid as a trap: a grid of
## flagstones that all look alike. Most are trigger stones, corded under the
## floor to a battery of crossbows (TrapBattery) that looses at whoever
## stands on one; some lie over pits and tip under a foot (TiltSlab, laid
## by the slabs themselves). Nothing marks the stones you may tread on: the
## builders, old Bai's crew of masons, walked out by their work song, which
## counts the way across (`way`, `moves()`; MasonsSong puts it into words
## and hands it out a few lines at a time). Crouched, you can knock on a
## stone and hear what it is. A shard thrown onto a trigger stone spends the
## volley, and the winch winds it again a few seconds later. At the far end
## the builders' pin locks it all for good (TrapLever); their winch, behind
## a false face in the wall (WinchNiche), can be jammed or held slack.
##
## Local space: x along the corridor (columns), z across it (rows), y up,
## the field's origin at the corner of column 0, row 0. `cells` is the
## layout, row by row: Cell values. `heights` is each cell's floor (local y).

enum Cell { SAFE, TRIGGER, PIT, NONE }

## The workshop's floor stones, the two shades close enough that no stone
## stands out (the third, much darker, would read as a sign).
const FLOOR_MATERIALS := [
	preload("res://assets/materials/level/floortiles1.tres"),
	preload("res://assets/materials/level/floortiles2.tres"),
]
const CLICK := preload("res://audio/sfx/impacts/impactPlate_light_000.ogg")
const KNOCK := preload("res://audio/sfx/impacts/impactSoft_medium_000.ogg")
const KNOCK_HOLLOW := preload("res://audio/sfx/impacts/impactPlank_medium_001.ogg")
const KNOCK_TRIGGER := preload("res://audio/sfx/impacts/impactMetal_light_000.ogg")
## How high above its stone a body may be and still weigh on it.
const STANDING := 0.45
## The stones' tops above the old floor they're laid on (no flicker where
## the two meet), and how thick they are (down past any unevenness under).
const LIFT := 0.025
const THICK := 0.5

@export var columns := 16:
	set(v):
		columns = maxi(v, 1)
		_queue_build()
@export var rows := 8:
	set(v):
		rows = maxi(v, 1)
		_queue_build()
@export var cell := 1.5:
	set(v):
		cell = maxf(v, 0.5)
		_queue_build()
@export var cells := PackedByteArray():
	set(v):
		cells = v
		_queue_build()
@export var heights := PackedFloat32Array():
	set(v):
		heights = v
		_queue_build()
@export var stone_seed := 0:
	set(v):
		stone_seed = v
		_queue_build()
@export var battery_path: NodePath
## The tilting slabs over this field's pits.
@export var slab_paths: Array[NodePath] = []
## The builders' way across, cell by cell in the order they walked it (from
## the near, west edge to the far one). Stones by its turns are safe too.
@export var way := PackedInt32Array()

## The builders' pin is in: nothing looses, nothing tips.
var locked := false
## Held slack by the brake: the stones click and nothing comes of it.
var slack := false

var _queued := false
var _bodies: Array[Node3D] = []
var _weighed := {}
var _pits: Array[Rect2] = []

func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"persistent")
	_make_runtime()
	_pits = _slab_rects()

func _queue_build() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_build.call_deferred()

# --- Layout ------------------------------------------------------------------------

func kind(index: int) -> int:
	return cells[index] if index >= 0 and index < cells.size() else Cell.NONE

func height(index: int) -> float:
	return heights[index] if index >= 0 and index < heights.size() else 0.0

func index_of(column: int, row: int) -> int:
	if column < 0 or row < 0 or column >= columns or row >= rows:
		return -1
	return row * columns + column

## The cell under a point (in the field's space), or -1.
func cell_at_local(p: Vector3) -> int:
	return index_of(floori(p.x / cell), floori(p.z / cell))

func cell_at(global_point: Vector3) -> int:
	return cell_at_local(to_local(global_point))

## The middle of a cell's top, in the field's space.
func centre(index: int) -> Vector3:
	var column := index % columns
	@warning_ignore("integer_division")
	var row := index / columns
	return Vector3((column + 0.5) * cell, height(index) + LIFT, (row + 0.5) * cell)

func centre_global(index: int) -> Vector3:
	return to_global(centre(index))

## The builders' way across, stone by stone in walking order (for the bots
## and the tests); without a recorded way, every safe stone west to east.
func safe_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	if not way.is_empty():
		for i in way:
			out.append(centre_global(i))
		return out
	for column in columns:
		for row in rows:
			var i := index_of(column, row)
			if kind(i) == Cell.SAFE:
				out.append(centre_global(i))
	return out

## The way as the masons counted it: [&"start", row from the river (north)
## wall, 1 first], then runs of [&"east" / &"river" / &"mountain", stones].
## Facing the sunrise (east, on from the workshop), the Wei river is on the
## left, Mount Li on the right, as the tomb lies.
func moves() -> Array:
	var out: Array = []
	if way.is_empty():
		return out
	@warning_ignore("integer_division")
	out.append([&"start", way[0] / columns + 1])
	for k in range(1, way.size()):
		var a := way[k - 1]
		var b := way[k]
		var dir := &"east"
		if b - a == -columns:
			dir = &"river"
		elif b - a == columns:
			dir = &"mountain"
		if out.size() > 1 and out[out.size() - 1][0] == dir:
			out[out.size() - 1][1] += 1
		else:
			out.append([dir, 1])
	return out

# --- Looks --------------------------------------------------------------------------

func _build() -> void:
	_queued = false
	for c in get_children():
		if c.has_meta(&"generated"):
			c.free()
	if cells.size() != columns * rows:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var batch := Masonry.Batch.new()
	var pits := _slab_rects()
	for i in cells.size():
		var k := kind(i)
		if k == Cell.NONE or k == Cell.PIT:
			continue
		# The workshop's flagstones, all alike; a stone by a pit's slab is
		# cut round it.
		var top := centre(i)
		var whole := Rect2(top.x - cell * 0.5, top.z - cell * 0.5, cell, cell)
		for piece in _cut_round(whole, pits):
			_lay(batch, rng, piece, top.y)
	batch.build(self)

## One flagstone over `r` (x, z in the field's space), its top at `top`.
func _lay(batch: Masonry.Batch, rng: RandomNumberGenerator, r: Rect2, top: float) -> void:
	var slabs := Masonry.stones("floor")
	var size := Vector3(r.size.x - 0.04, THICK, r.size.y - 0.04)
	var at := Vector3(r.get_center().x, top - THICK * 0.5 + rng.randf_range(-0.004, 0.004), r.get_center().y)
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	var shade := rng.randf_range(0.86, 1.1)
	var mat: Material = FLOOR_MATERIALS[rng.randi() % FLOOR_MATERIALS.size()]
	if slabs.is_empty():
		batch.add(mat, Masonry.piece(at, Vector3.RIGHT, Vector3.UP, Vector3.BACK, size, rng.randf_range(-0.01, 0.01)), shade)
	else:
		var pick: Array = slabs[rng.randi() % slabs.size()]
		batch.add(mat, Masonry.piece(at, Vector3.RIGHT * turn, Vector3.UP, Vector3.BACK * turn, size / (pick[1] as Vector3), rng.randf_range(-0.01, 0.01)), shade, pick[0])

## The slabs' footprints (x, z in the field's space).
func _slab_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	for path in slab_paths:
		var slab := get_node_or_null(path) as TiltSlab
		if slab != null and slab.is_inside_tree():
			var c := to_local(slab.global_position)
			out.append(Rect2(c.x - slab.size * 0.5, c.z - slab.size * 0.5, slab.size, slab.size))
	return out

## `r` less whatever of the pits' slabs lies in it: the strips left round
## them, wide enough to be stones.
func _cut_round(r: Rect2, pits: Array[Rect2]) -> Array[Rect2]:
	var pieces: Array[Rect2] = [r]
	for pit in pits:
		var next: Array[Rect2] = []
		for p in pieces:
			if not p.intersects(pit):
				next.append(p)
				continue
			var cut := p.intersection(pit)
			# West and east of it, the whole depth; north and south, between.
			next.append(Rect2(p.position.x, p.position.y, cut.position.x - p.position.x, p.size.y))
			next.append(Rect2(cut.end.x, p.position.y, p.end.x - cut.end.x, p.size.y))
			next.append(Rect2(cut.position.x, p.position.y, cut.size.x, cut.position.y - p.position.y))
			next.append(Rect2(cut.position.x, cut.end.y, cut.size.x, p.end.y - cut.end.y))
		pieces = []
		for p in next:
			if p.size.x > 0.18 and p.size.y > 0.18:
				pieces.append(p)
	return pieces

# --- Running ------------------------------------------------------------------------

func _make_runtime() -> void:
	var width := columns * cell
	var depth := rows * cell
	var top := 0.0
	for h in heights:
		top = maxf(top, h)
	# Who stands on the field: players and what they throw (guards keep off).
	var watch := Area3D.new()
	watch.name = "Watch"
	watch.collision_layer = 0
	watch.collision_mask = 2 | 8
	watch.monitorable = false
	var ws := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(width, 2.4, depth)
	ws.shape = wbox
	ws.position = Vector3(width * 0.5, top + 1.0, depth * 0.5)
	watch.add_child(ws)
	add_child(watch)
	watch.body_entered.connect(func(b: Node3D) -> void:
		if not _bodies.has(b):
			_bodies.append(b))
	watch.body_exited.connect(func(b: Node3D) -> void:
		_bodies.erase(b))
	# The paving itself: a body for the stones (and what's left of one beside
	# a pit's slab), their tops where they show.
	var paving := StaticBody3D.new()
	paving.name = "Paving"
	paving.collision_layer = 1
	paving.collision_mask = 0
	var pits := _slab_rects()
	for i in cells.size():
		var k := kind(i)
		if k == Cell.NONE or k == Cell.PIT:
			continue
		var top_c := centre(i)
		var whole := Rect2(top_c.x - cell * 0.5, top_c.z - cell * 0.5, cell, cell)
		for piece in _cut_round(whole, pits):
			var ps := CollisionShape3D.new()
			var pb := BoxShape3D.new()
			pb.size = Vector3(piece.size.x, THICK, piece.size.y)
			ps.shape = pb
			ps.position = Vector3(piece.get_center().x, top_c.y - THICK * 0.5, piece.get_center().y)
			paving.add_child(ps)
	add_child(paving)
	# What a knock lands on: the interaction's aim sees it, nobody walks on it.
	var surface := StaticBody3D.new()
	surface.name = "Surface"
	surface.collision_layer = 16
	surface.collision_mask = 0
	var ss := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(width, 0.04, depth)
	ss.shape = sbox
	ss.position = Vector3(width * 0.5, top + 0.03, depth * 0.5)
	surface.add_child(ss)
	var usable := DelegateUsable.new()
	usable.name = "Usable"
	usable.prompt_key = "PROMPT_KNOCK"
	usable.highlight = false
	surface.add_child(usable)
	add_child(surface)
	# Where the navmesh is baked without (guards keep to the builders' way,
	# and so do the bots that walk it): every other stone, a run of them a
	# row at a time.
	for r in rows:
		var start := -1
		for c in columns + 1:
			var trap := c < columns and kind(index_of(c, r)) != Cell.SAFE
			if trap and start < 0:
				start = c
			elif not trap and start >= 0:
				var ob := NavigationObstacle3D.new()
				ob.name = "KeepOff%d_%d" % [r, start]
				ob.affect_navigation_mesh = true
				ob.avoidance_enabled = false
				ob.height = 2.0
				var y := height(index_of(start, r)) - 0.2
				ob.vertices = PackedVector3Array([Vector3(start * cell, 0, r * cell), Vector3(c * cell, 0, r * cell), Vector3(c * cell, 0, (r + 1) * cell), Vector3(start * cell, 0, (r + 1) * cell)])
				ob.position.y = y
				add_child(ob)
				start = -1

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or Net.is_client():
		return
	var now := {}
	for b in _bodies.duplicate():
		if not is_instance_valid(b) or not b.is_inside_tree():
			_bodies.erase(b)
			continue
		var lp := to_local(b.global_position)
		var i := cell_at_local(lp)
		if i < 0 or lp.y - height(i) > STANDING:
			continue
		# On a pit's slab it's the slab that answers: he falls.
		var on_slab := false
		for pit in _pits:
			on_slab = on_slab or pit.grow(0.1).has_point(Vector2(lp.x, lp.z))
		if on_slab:
			continue
		now[i] = b
		if not _weighed.has(i) and kind(i) == Cell.TRIGGER:
			Net.mirror(self, &"net_press", [i, String(b.name)])
			net_press(i, String(b.name))
	_weighed = now

## A trigger stone gives under someone (or something): the click, then the
## battery, unless the field is locked or held slack.
func net_press(index: int, who: String) -> void:
	Sfx.play_at(CLICK, centre_global(index), 2.0, 0.06, &"Tomb", 22.0)
	if locked or slack:
		return
	var battery := get_node_or_null(battery_path) as TrapBattery
	if battery == null or not battery.can_loose():
		return
	var body := _body_named(who)
	await get_tree().create_timer(0.1, false).timeout
	if locked or slack:
		return
	var at := centre_global(index)
	# A shard that broke on the stone is gone by now: the volley goes where
	# it landed.
	if not is_instance_valid(body):
		body = null
	if body != null:
		at = body.global_position
	battery.loose_at(body, at)

func _body_named(who: String) -> Node3D:
	for b in _bodies:
		if is_instance_valid(b) and String(b.name) == who:
			return b
	for p in Net.players():
		if String(p.name) == who:
			return p
	return null

## The builders' pin: the battery unstrung and every slab pinned, for good.
func lock() -> void:
	locked = true
	var battery := get_node_or_null(battery_path) as TrapBattery
	if battery != null:
		battery.lock()
	for path in slab_paths:
		var slab := get_node_or_null(path) as TiltSlab
		if slab != null:
			slab.pin()

## The builders' brake, held or let go.
func set_slack(on: bool) -> void:
	slack = on
	var battery := get_node_or_null(battery_path) as TrapBattery
	if battery != null:
		battery.slack = on
	for path in slab_paths:
		var slab := get_node_or_null(path) as TiltSlab
		if slab != null:
			slab.held = on

# --- Knocking (crouched) ------------------------------------------------------------------

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null or not (p.is_crouching() or p.is_crawling()):
		return ""
	return tr("PROMPT_KNOCK")

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return p != null and (p.is_crouching() or p.is_crawling())

func usable_use(user: Node) -> void:
	var p := user as Player
	if p == null:
		return
	var at := _aimed_point(p)
	var i := cell_at(at) if at != Vector3.INF else -1
	if i < 0:
		return
	var what := kind_at(at)
	var sound: AudioStream = KNOCK
	var text := "KNOCK_SOLID"
	match what:
		Cell.TRIGGER:
			sound = KNOCK_TRIGGER
			text = "KNOCK_TRIGGER"
		Cell.PIT:
			sound = KNOCK_HOLLOW
			text = "KNOCK_HOLLOW"
	Sfx.play_at(sound, centre_global(i), -4.0, 0.08, &"Tomb", 12.0)
	Stealth.make_noise(centre_global(i), 5.0, p)
	if p.is_local:
		p.viewmodel.call(&"play_use")
		p.notice(text)

## What a stone at `at` is (a knock's answer): a pit's slab, whatever
## stone it shares a cell with; NONE off the field.
func kind_at(at: Vector3) -> int:
	var i := cell_at(at)
	if i < 0:
		return Cell.NONE
	var local := to_local(at)
	for pit in _slab_rects():
		if pit.has_point(Vector2(local.x, local.z)):
			return Cell.PIT
	return kind(i)

## Where on the field's top the player looks (INF if not on it).
func _aimed_point(p: Player) -> Vector3:
	if p.camera == null:
		return Vector3.INF
	var from := p.camera.global_position
	var params := PhysicsRayQueryParameters3D.create(from, from - p.camera.global_basis.z * 3.0, 16)
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	return hit.position if not hit.is_empty() else Vector3.INF

func persist_save() -> Dictionary:
	return {"locked": locked}

func persist_load(data: Dictionary) -> void:
	if bool(data.get("locked", false)) and not locked:
		lock()
