extends Node
## Dev test: the great corridor's trapped floors (TrapField) against the
## real player, one thing at a time from a fresh start of Act II:
##   a trigger stone hurts (the battery's volley, whatever his stance, one
##   hit of three); the third wrong stone kills;
##   the builders' marked way across is safe, stone by stone;
##   a shard thrown on a trigger stone spends the volley, the field is safe
##   till the winch winds it again, then it looses again;
##   a knock tells a stone: solid, a trigger, hollow over a pit;
##   a pit's slab tips him onto the spikes;
##   the winch's brake held (in the hollow pillar) keeps the first floor
##   slack (a partner crosses); a chisel in its pawl kills it for good, and
##   the far pin locks the second floor for good;
##   the navmesh keeps to the marked way (guards and bots walk it).
## Also the east end's old single plates still fire their crossbows.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/trap_test_runner.gd

const T := "CorridorTraps/"

var failures := 0
var level: Node3D
var player: Player
var west: TrapField
var east: TrapField

func _ready() -> void:
	_run.call_deferred()

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	await _fresh()
	_check("two trapped floors, each with a way across", west.safe_path().size() > 10 and east.safe_path().size() > 10)
	_paving_is_level_and_walked_on()
	_crossbows_in_their_niches()
	await _trigger_kills()
	await _fresh()
	await _the_way_across(west)
	await _the_way_across(east)
	await _fresh()
	await _shard_spends_it()
	await _fresh()
	_knocks()
	await _slab_tips()
	await _fresh()
	await _brake_and_pin()
	await _fresh()
	_navmesh_keeps_to_the_way()
	await _old_plates()
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## Every stone is walked on at the height it shows, none floating or sunk:
## a ray down onto each stone's middle meets the paving at its top.
func _paving_is_level_and_walked_on() -> void:
	var space := level.get_world_3d().direct_space_state
	for field in [west, east]:
		var f := field as TrapField
		var off := 0
		var n := 0
		var spread := 0.0
		for i in f.cells.size():
			if f.kind(i) == TrapField.Cell.NONE or f.kind(i) == TrapField.Cell.PIT:
				continue
			var c := f.centre_global(i)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 1.0, c + Vector3.DOWN * 2.0, 1))
			n += 1
			# A stone beside a pit's slab can have no middle: skip those.
			if hit.is_empty() or hit.collider.get_parent() != f.get_node("Paving"):
				continue
			spread = maxf(spread, absf(hit.position.y - c.y))
			if absf(hit.position.y - c.y) > 0.01:
				off += 1
		_check("%s: %d stones all walked on at the height they show (worst %.3f m, %d off)" % [f.name, n, spread, off], off == 0)

## The battery's crossbows sit in the wall's niches: behind the wall's face,
## not in front of it, none inside the masonry.
func _crossbows_in_their_niches() -> void:
	var space := level.get_world_3d().direct_space_state
	var bad := 0
	var total := 0
	for b in ["BatteryWest", "BatteryEast"]:
		for bow in level.get_node(T + b).get_children():
			if not (bow is WallCrossbow):
				continue
			total += 1
			var p := (bow as Node3D).global_position
			# Nothing solid within a hand of it (it isn't buried), and the
			# corridor's open on its firing side.
			var ball := SphereShape3D.new()
			ball.radius = 0.12
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = ball
			q.transform = Transform3D(Basis(), p)
			q.collision_mask = 1
			# (The jam's own decorative crossbows, hidden, keep their colliders
			# in the old niches: not walls.)
			var inside := space.intersect_shape(q, 4)
			var buried := false
			for r in inside:
				if not String((r.collider as Node).name).contains("crossbow"):
					buried = true
			var dir := -(bow as Node3D).global_basis.z
			var ahead := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + dir * 0.4, p + dir * 3.0, 1))
			var clear := ahead.is_empty() or (ahead.position as Vector3).distance_to(p) > 2.0
			if buried or not clear:
				bad += 1
				print("  bow %s at %s buried %s clear %s" % [bow.name, p, buried, clear])
	_check("%d battery crossbows, each in its niche (%d wrong)" % [total, bad], total >= 10 and bad == 0)

## A new game at Act II's start, the player out of harm's way.
func _fresh() -> void:
	Game.new_game()
	Game.set_flag(&"intro_done")
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.4)
	Dialogue.stop()
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	Quest.start_at(&"find_liang")
	for g in get_tree().get_nodes_in_group(&"guards"):
		(g as Guard).sight_range = 0.0
		(g as Guard).hearing_scale = 0.0
	west = level.get_node(T + "FieldWest") as TrapField
	east = level.get_node(T + "FieldEast") as TrapField
	player.global_position = Vector3(-54.0, 0.4, 15.5)
	await _wait(0.4)

func _stand(at: Vector3) -> void:
	player.global_position = at + Vector3.UP * 0.05
	player.velocity = Vector3.ZERO

## Off the way, on a trigger stone: a volley is one hit, a third of his
## strength; three wrong stones kill him (not one).
func _trigger_kills() -> void:
	var battery := west.get_node(west.battery_path) as TrapBattery
	player.health = player.max_health
	var hits := 0
	for n in 3:
		var cell := _first_of(west, TrapField.Cell.TRIGGER, 5 + n * 4)
		_stand(Vector3(-54.0, 0.4, 15.5))
		await _wait(0.5)
		_wind(battery)
		var before := player.health
		_stand(west.centre_global(cell))
		await _wait(1.3)
		if n < 2:
			_check("wrong stone %d: hurt by a volley (health %.1f -> %.1f), alive" % [n + 1, before, player.health], not Game.is_dead() and player.health < before - 0.5 and player.health > 0.0)
			hits += 1
		else:
			_check("the third wrong stone kills (health %.1f)" % player.health, Game.is_dead() or player.health <= 0.0)
	_check("a volley took about a third of his health each time", hits == 2)

## The winch wound (another volley ready), as if the reload time had run.
func _wind(battery: TrapBattery) -> void:
	battery.armed = true
	for cb in battery.crossbows():
		cb.rearm()

## Stone by stone along the marked way: alive at the far side.
func _the_way_across(field: TrapField) -> void:
	player.health = player.max_health
	for p in field.safe_path():
		_stand(p)
		await _wait(0.12)
	await _wait(0.6)
	_check("%s: the marked way across is safe (health %.1f)" % [field.name, player.health], not Game.is_dead() and player.health >= player.max_health - 0.01)

## A shard on a trigger stone: the volley spent on it, the field safe while
## the winch winds, deadly again after.
func _shard_spends_it() -> void:
	var battery := level.get_node(T + "BatteryWest") as TrapBattery
	var cell := _first_of(west, TrapField.Cell.TRIGGER, 3)
	var shard := RigidBody3D.new()
	shard.set_script(preload("res://Scripts/items/thrown_item.gd"))
	shard.set(&"item_id", &"ceramic")
	level.add_child(shard)
	shard.global_position = west.centre_global(cell) + Vector3.UP * 1.0
	await _wait(1.2)
	_check("a shard on a trigger stone spends the volley", not battery.armed)
	var other := _first_of(west, TrapField.Cell.TRIGGER, 9)
	_stand(west.centre_global(other))
	await _wait(0.8)
	_check("while the winch winds, a trigger stone is harmless (health %.1f)" % player.health, not Game.is_dead() and player.health > 0.0)
	_stand(Vector3(-54.0, 0.4, 15.5))
	await _wait(battery.reload_time)
	_check("wound again", battery.armed)
	var before := player.health
	_stand(west.centre_global(other))
	await _wait(1.0)
	_check("and it looses again (health %.1f -> %.1f)" % [before, player.health], player.health < before - 0.5)

## A knock answers what a stone is.
func _knocks() -> void:
	var safe := west.safe_path()[3]
	var trigger := west.centre_global(_first_of(west, TrapField.Cell.TRIGGER, 4))
	var slab := level.get_node(T + "Slab1") as TiltSlab
	_check("a marked stone knocks solid", west.kind_at(safe) == TrapField.Cell.SAFE)
	_check("a trigger stone knocks with a click", west.kind_at(trigger) == TrapField.Cell.TRIGGER)
	_check("a slab knocks hollow", east.kind_at(slab.global_position + Vector3(0.2, 0.0, 0.2)) == TrapField.Cell.PIT)

## Onto a pit's slab: it tips, he falls on the spikes.
func _slab_tips() -> void:
	await _fresh()
	var slab := level.get_node(T + "Slab1") as TiltSlab
	_stand(slab.global_position + Vector3(0.3, 0.0, 0.0))
	await _wait(4.0)
	_check("a slab tips him onto the spikes (y %.1f)" % player.global_position.y, Game.is_dead())

## The hollow pillar's winch: its brake held, the first floor's stones click
## and nothing comes of it (the partner crosses); let go, armed again; the
## chisel in its pawl, never again (and the chisel is gone). The second
## floor's pin: locked, slabs and all.
func _brake_and_pin() -> void:
	var niche := level.get_node(T + "Winch") as WinchNiche
	niche.felt = true
	player.inventory.add(&"chisel")
	player.global_position = niche.global_position + niche.global_basis.z * 2.0 + Vector3.UP * 0.3
	await _wait(0.3)
	niche.usable_hold_done(player)
	_check("the chisel has the loose stones out", niche.opened)
	niche.usable_tap(player)
	_check("the winch's brake held: the first floor slack", west.slack)
	_stand(west.centre_global(_first_of(west, TrapField.Cell.TRIGGER, 2)))
	await _wait(0.8)
	_check("held: a trigger stone does nothing (alive)", not Game.is_dead() and player.health > 0.0)
	niche.usable_tap(player)
	_check("let go: armed again", not west.slack)
	niche.usable_hold_done(player)
	_check("the chisel in the pawl: never again, and no chisel", west.locked and niche.jammed and not player.inventory.has_item(&"chisel"))
	_stand(west.centre_global(_first_of(west, TrapField.Cell.TRIGGER, 7)))
	await _wait(0.8)
	_check("jammed: a trigger stone does nothing", not Game.is_dead() and player.health > 0.0)
	var pin := level.get_node(T + "PinEast") as TrapLever
	var slab := level.get_node(T + "Slab2") as TiltSlab
	pin.usable_hold_done(player)
	_check("the far pin locks the second floor for good", east.locked and pin.pulled)
	player.health = player.max_health
	_stand(east.centre_global(_first_of(east, TrapField.Cell.TRIGGER, 6)))
	await _wait(0.8)
	_stand(slab.global_position + Vector3(0.3, 0.0, 0.0))
	await _wait(1.5)
	_check("locked: nothing fires, nothing tips", not Game.is_dead() and player.health > 0.0)

## A path for an agent across each field keeps to its marked stones.
func _navmesh_keeps_to_the_way() -> void:
	var map := level.get_world_3d().navigation_map
	for field in [west, east]:
		var way := (field as TrapField).safe_path()
		var from := NavigationServer3D.map_get_closest_point(map, way[0] - Vector3((field as TrapField).cell, 0, 0))
		var to := NavigationServer3D.map_get_closest_point(map, way[way.size() - 1] + Vector3(0.0, 0.0, 0.0))
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var short := path[path.size() - 1].distance_to(to) if path.size() > 0 else INF
		_check("%s: the navmesh's way gets across (ends %.1f m short)" % [(field as TrapField).name, short], short < 0.6)
		var off := 0
		for i in range(1, path.size()):
			var a: Vector3 = path[i - 1]
			var b: Vector3 = path[i]
			for k in 10:
				var p := a.lerp(b, k / 10.0)
				var kind := (field as TrapField).kind_at(p)
				if kind == TrapField.Cell.TRIGGER or kind == TrapField.Cell.PIT:
					off += 1
		_check("%s: the navmesh's way stays on the marked stones (%d points off, %d long)" % [(field as TrapField).name, off, path.size()], path.size() > 1 and off == 0)

## The east end's single plates (past the archives' turn) still fire.
func _old_plates() -> void:
	for i in [4, 5]:
		await _fresh()
		var plate := level.get_node(T + "Plate%d" % i) as Node3D
		_stand(plate.global_position + Vector3.UP * 0.3)
		await _wait(1.2)
		_check("plate %d fires its crossbow (health %.1f/%.1f)" % [i, player.health, player.max_health], player.health < player.max_health or Game.is_dead())

## The `n`th cell of `kind` in `field`, counting from the west.
func _first_of(field: TrapField, kind: int, n: int) -> int:
	var seen := 0
	for c in field.columns:
		for r in field.rows:
			var i := field.index_of(c, r)
			if field.kind(i) == kind:
				if seen == n:
					return i
				seen += 1
	return -1
