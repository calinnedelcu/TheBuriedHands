extends Node
## Dev test: the crossbow gallery's watch, one case per run (--case=):
##   gong    the turning crossbow loosed at the gong: it booms, and both
##           crossbowmen leave their beat to look at it.
##   lamp    turned on the lamp over the way out and loosed: the lamp falls
##           and goes out, and a man standing there is in the dark.
##   shoot   in the open and lit, a crossbowman sees him and shoots: hurt.
##   armour  the same in stone armour: the bolts glance off.
##   fall    the way out's roof is down on a beam: walking he can't get by,
##           crawling he can.
## godot --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/gallery_watch_runner.gd --case=gong|lamp|shoot|armour|fall

const G := "UnderTheMountain/"

var failures := 0
var level: Node3D
var player: Player
var bows: Array[Guard] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var case := "gong"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			case = arg.substr(7)
	Game.new_game()
	await Game.level_ready
	level = Game.level as Node3D
	player = get_tree().get_first_node_in_group(&"player") as Player
	await _wait(0.5)
	Dialogue.stop()
	Game.set_flag(&"guards_hostile")
	Game.advance_sealing(1)
	Quest.start_at(&"past_wall")
	# Beside the turning crossbow, behind it as it's first turned.
	player.global_position = Vector3(21.6, -25.9, -18.0)
	await _wait(1.0)
	bows = [level.get_node("Guards/GalleryBowWest") as Guard, level.get_node("Guards/GalleryBowEast") as Guard]
	_check("two crossbowmen on the walkways", bows[0].ranged and bows[1].ranged and bows[0].global_position.y > -23.0 and bows[1].global_position.y > -23.0)
	_check("no ji, a crossbow", not bows[0].carries_ji and bows[0].find_child("HeldHand", true, false) != null)
	match case:
		"gong":
			await _gong()
		"lamp":
			await _lamp()
		"shoot":
			await _shot_at(false)
		"armour":
			await _shot_at(true)
		"fall":
			await _fall()
	print("RESULT: %d failure(s)" % failures)
	Game._delete_save()
	get_tree().quit()

## Loosed at the gong, the walkways' men go to look at it.
func _gong() -> void:
	var swivel := level.get_node(G + "GallerySwivel") as SwivelCrossbow
	var gong := level.get_node(G + "GalleryGong") as Gong
	_check("the turning crossbow starts on the gong", swivel.aim == 0 and _aimed_at(swivel, gong.aim_point()))
	# Off down their walkways first (they start at the north ends).
	await _wait(9.0)
	var before := [_flat(bows[0], gong), _flat(bows[1], gong)]
	swivel.usable_hold_done(player)
	var heard := [false, false]
	var t := 0.0
	while t < 9.8:
		await _wait(0.2)
		t += 0.2
		for i in 2:
			heard[i] = heard[i] or bows[i].state in [Guard.State.SUSPICIOUS, Guard.State.INVESTIGATE, Guard.State.SEARCH]
		if int(t * 5.0) % 5 == 0:
			print("  t %.1f west %s aw %.2f %s | east %s aw %.2f %s" % [t, Guard.State.keys()[bows[0].state], bows[0].awareness, bows[0].global_position.snapped(Vector3.ONE * 0.1), Guard.State.keys()[bows[1].state], bows[1].awareness, bows[1].global_position.snapped(Vector3.ONE * 0.1)])
	_check("loosed, and the gong struck", swivel.loosed and gong.struck)
	_check("both men heard it", heard[0] and heard[1])
	var after := [_flat(bows[0], gong), _flat(bows[1], gong)]
	print("  to the gong before %s, after %s" % [before, after])
	_check("they came along their walkways to look", after[0] < before[0] - 3.0 or after[0] < 6.0)
	_check("both of them", after[1] < before[1] - 3.0 or after[1] < 6.0)

## Turned on the lamp over the way out and loosed: down and out, and the way
## out is dark.
func _lamp() -> void:
	var swivel := level.get_node(G + "GallerySwivel") as SwivelCrossbow
	var lamp := level.get_node(G + "ExitLamp") as WallLamp
	swivel.usable_tap(player)
	await _wait(1.2)
	_check("turned on the lamp over the way out", swivel.aim == 1 and _aimed_at(swivel, lamp.global_position))
	# Standing where he'd shed the armour, his own lamp out: how lit is he?
	player.inventory.take_lamp(100.0, false)
	player.global_position = Vector3(11.0, -25.9, 23.0)
	await _wait(0.8)
	var lit_before := player.exposure
	player.global_position = Vector3(21.6, -25.9, -18.0)
	await _wait(0.3)
	swivel.usable_hold_done(player)
	await _wait(2.0)
	_check("the lamp shot down and out", lamp.fallen and not lamp.lit)
	player.global_position = Vector3(11.0, -25.9, 23.0)
	await _wait(0.8)
	print("  exposure at the way out: %.2f before, %.2f after" % [lit_before, player.exposure])
	_check("the way out is dark now", player.exposure < 0.2 and player.exposure < lit_before - 0.2)

## In the open, lit, standing: a crossbowman sees him and shoots.
func _shot_at(armoured: bool) -> void:
	if armoured:
		player.inventory.add(&"stone_armor")
	player.inventory.take_lamp(100.0, true)
	var hp := player.health
	player.global_position = Vector3(17.0, -25.9, 2.0)
	var t := 0.0
	var chased := false
	while t < 16.0:
		await _wait(0.5)
		t += 0.5
		chased = chased or bows[0].state == Guard.State.CHASE or bows[1].state == Guard.State.CHASE
		if not armoured and player.health < hp:
			break
	_check("a crossbowman saw him", chased)
	if armoured:
		_check("the bolts glanced off the stone (health %.1f of %.1f)" % [player.health, hp], player.health >= hp - 0.01 and not Game.is_dead())
	else:
		_check("hit by a bolt from the walkway (health %.1f of %.1f)" % [player.health, hp], player.health < hp)
	_check("they stay up on their walkways", bows[0].global_position.y > -23.0 and bows[1].global_position.y > -23.0)

## Under the fallen roof only on his belly.
func _fall() -> void:
	player.global_position = Vector3(11.0, -25.9, 23.2)
	player.rotation.y = PI
	await _wait(0.4)
	await _forward(3.0)
	_check("on his feet he can't get by the fall (z %.1f)" % player.global_position.z, player.global_position.z < 24.6)
	player._set_stance(Player.Stance.CROUCH, true)
	await _wait(0.4)
	await _forward(3.0)
	_check("nor crouching (z %.1f)" % player.global_position.z, player.global_position.z < 24.6)
	player._set_stance(Player.Stance.CRAWL, true)
	await _wait(0.5)
	await _forward(6.0)
	_check("crawling, under the beam and through (z %.1f)" % player.global_position.z, player.global_position.z > 26.0)

func _forward(seconds: float) -> void:
	Input.action_press(&"move_forward")
	await _wait(seconds)
	Input.action_release(&"move_forward")
	await _wait(0.2)

func _aimed_at(swivel: SwivelCrossbow, at: Vector3) -> bool:
	var pivot := swivel.get_node("Pivot") as Node3D
	var forward := -pivot.global_basis.z
	return forward.angle_to((at - pivot.global_position).normalized()) < deg_to_rad(6.0)

func _flat(g: Guard, n: Node3D) -> float:
	return Vector2(g.global_position.x - n.global_position.x, g.global_position.z - n.global_position.z).length()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)
