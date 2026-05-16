class_name GuardConversationSequence
extends Node

## Auto-triggered conversation between two guards. Cand obiectivul curent devine
## `trigger_objective_id`, gardienii se misca unul spre celalalt, se intorc fata
## in fata, iar camera player-ului se blocheaza zoom-ata pe midpoint pe toata
## durata replicilor. La final → next objective.

@export var trigger_objective_id: String = ""
@export var guard_a_path: NodePath
@export var guard_b_path: NodePath

@export_group("Movement")
@export var move_distance_each: float = 2.4
@export var move_duration: float = 1.6
@export var face_duration: float = 0.5
@export var pre_dialogue_delay: float = 0.25

@export_group("Camera")
@export var camera_zoom_fov: float = 38.0
@export var camera_pan_duration: float = 0.9
@export var camera_return_duration: float = 0.6
@export var midpoint_height_offset: float = 1.4
@export var auto_focus: bool = true

@export_group("Dialogue")
## Speaker-prefixed lines, ex: "Gardianul 1: ...". Daca e gol, foloseste baked.
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 5.5
@export var dialogue_inter_pause: float = 0.35
@export var baked_dialogue_key: String = ""

@export_group("Objective")
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
@export var complete_trigger_objective: bool = false

@export_group("Exit Walk")
## Daca e setat, dupa ultima replica gardienii merg unul dupa altul prin
## waypoint-urile copil (Node3D-uri) ale acestui nod. Raman la ultimul WP.
@export var exit_path: NodePath
@export var exit_speed_mps: float = 1.7
@export var exit_b_lag: float = 0.9
@export var exit_rotation_time_max: float = 0.45

@export_group("Monologue After Objective")
## Dupa ce obiectivul `objective_after_id` e setat, dupa acest delay (secunde)
## protagonistul rosteste un monolog interior care ghideaza jucatorul.
@export var monologue_delay: float = 5.0
@export_multiline var monologue_text: String = ""

var _playing: bool = false
var _consumed: bool = false

func _ready() -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null:
		push_warning("[GuardConversation] /root/Objectives missing")
		return
	if not objectives.is_connected("objective_changed", Callable(self, "_on_objective_changed")):
		objectives.connect("objective_changed", Callable(self, "_on_objective_changed"))
	print("[GuardConversation] ready, listening for objective '%s' (guards: %s / %s)" % [trigger_objective_id, guard_a_path, guard_b_path])
	# Daca obiectivul declansator e deja activ in momentul _ready (ex. salvare),
	# putem porni cu un mic delay ca sa prindem si re-load-urile / scene reloads.
	if trigger_objective_id != "" and objectives.has_method("current_id"):
		var current := str(objectives.call("current_id"))
		if current == trigger_objective_id and not _consumed:
			_consumed = true
			print("[GuardConversation] trigger objective already active at ready — starting after delay")
			call_deferred("_run_sequence")

func _on_objective_changed(id: String, _text: String) -> void:
	print("[GuardConversation] objective_changed: '%s' (waiting for '%s', consumed=%s, playing=%s)" % [id, trigger_objective_id, _consumed, _playing])
	if _consumed or _playing:
		return
	if trigger_objective_id == "" or id != trigger_objective_id:
		return
	_consumed = true
	# Defer ca sa nu lansam coroutine + tween-uri direct din signal handler-ul
	# Objectives.objective_changed. set_objective() poate fi apelat din contexte
	# fragile (input handler, alta coroutine) si re-entrancy-ul cu tween_property
	# cauza crash in Godot 4.6 cand erau implicate camera/rotation pe player.
	call_deferred("_run_sequence")

func _run_sequence() -> void:
	_playing = true
	print("[GuardConversation] _run_sequence started")
	var guard_a := get_node_or_null(guard_a_path) as Node3D
	var guard_b := get_node_or_null(guard_b_path) as Node3D
	if guard_a == null or guard_b == null:
		push_warning("[GuardConversation] guard paths invalid: %s / %s (a=%s b=%s)" % [guard_a_path, guard_b_path, guard_a, guard_b])
		_finish()
		return
	print("[GuardConversation] guards found: %s @ %s, %s @ %s" % [guard_a.name, guard_a.global_position, guard_b.name, guard_b.global_position])

	var start_a := guard_a.global_position
	var start_b := guard_b.global_position
	var midpoint := (start_a + start_b) * 0.5
	var dir_a_to_b := (start_b - start_a)
	dir_a_to_b.y = 0.0
	var dist := dir_a_to_b.length()
	if dist < 0.001:
		push_warning("[GuardConversation] guards overlap")
		_finish()
		return
	dir_a_to_b = dir_a_to_b / dist
	var step := minf(move_distance_each, dist * 0.45)
	var target_a := start_a + dir_a_to_b * step
	var target_b := start_b - dir_a_to_b * step

	# Oprim AnimationPlayer pe gardieni pe durata cinematicii. Animatia idle din
	# guard1-idle.glb scrie pe transform-ul root in fiecare frame si intra in
	# conflict cu tween_property pe global_position — bug Godot 4.6 cunoscut
	# care provoaca crash hard al engine-ului. Manual lerp + anim stopped =
	# stabilitate.
	var anim_a := _find_animation_player(guard_a)
	var anim_b := _find_animation_player(guard_b)
	if anim_a != null:
		anim_a.stop()
	if anim_b != null:
		anim_b.stop()

	# Camera lock — porneste in paralel cu mersul ca sa nu mai astepte player-ul.
	var camera_started := false
	if auto_focus:
		var player := get_tree().get_first_node_in_group("player")
		print("[GuardConversation] player found: %s" % player)
		if player != null and player.has_method("start_cinematic_lock"):
			var focus_pos := midpoint + Vector3.UP * midpoint_height_offset
			print("[GuardConversation] calling start_cinematic_lock at %s" % focus_pos)
			player.call("start_cinematic_lock", focus_pos, camera_zoom_fov, camera_pan_duration)
			camera_started = true
			print("[GuardConversation] start_cinematic_lock returned")

	print("[GuardConversation] manual move begin (target_a=%s target_b=%s)" % [target_a, target_b])
	await _move_two_manual(guard_a, target_a, guard_b, target_b, move_duration)
	print("[GuardConversation] manual move done")

	# Rotire fata in fata pe Y (cel mai scurt drum) — manual ca sa evitam tween
	# pe rotation:y peste un nod cu AnimationPlayer.
	var yaw_a := _shortest_yaw_to(guard_a, target_b)
	var yaw_b := _shortest_yaw_to(guard_b, target_a)
	await _rotate_two_manual(guard_a, yaw_a, guard_b, yaw_b, face_duration)
	print("[GuardConversation] face rotation done, starting dialogue")

	print("[GuardConversation] pre-dialogue delay (%.2fs)" % pre_dialogue_delay)
	if pre_dialogue_delay > 0.0:
		await _wait_seconds(pre_dialogue_delay)
	print("[GuardConversation] pre-delay done")

	# Replicile.
	var lines := _effective_lines()
	print("[GuardConversation] dialogue lines: %d" % lines.size())
	var events := get_node_or_null("/root/GameEvents")
	if events == null:
		push_warning("[GuardConversation] no GameEvents autoload — dialogue skipped")
	elif not events.has_method("show_dialogue"):
		push_warning("[GuardConversation] GameEvents missing show_dialogue method")
	else:
		for i in lines.size():
			var line := str(lines[i])
			print("[GuardConversation] line %d/%d: %s" % [i+1, lines.size(), line.substr(0, 50)])
			events.call("show_dialogue", line, dialogue_line_duration)
			if dialogue_line_duration > 0.0:
				await _dialogue_wait(dialogue_line_duration)
			if dialogue_inter_pause > 0.0:
				await _wait_seconds(dialogue_inter_pause)
		print("[GuardConversation] all lines done")

	# Eliberam camera inainte sa schimbam obiectivul, ca pop-up-ul de obiectiv
	# sa apara dupa ce input-ul a fost redat.
	if camera_started:
		var player2 := get_tree().get_first_node_in_group("player")
		if player2 != null and player2.has_method("end_cinematic_lock"):
			player2.call("end_cinematic_lock", camera_return_duration)
		await _wait_seconds(camera_return_duration)

	# Gardienii pleaca pe ruta de exit in fundal — nu asteptam sa termine,
	# player-ul primeste obiectivul nou imediat.
	_start_exit_walk(guard_a, guard_b)

	_finish()

	if monologue_text != "" and monologue_delay > 0.0:
		await _dialogue_wait(monologue_delay)
		var events_mono := get_node_or_null("/root/GameEvents")
		if events_mono != null and events_mono.has_method("show_dialogue"):
			events_mono.call("show_dialogue", monologue_text, dialogue_line_duration)
	elif monologue_delay > 0.0:
		# Fallback hardcodat daca monologue_text e gol in .tscn
		await _dialogue_wait(monologue_delay)
		var events_mono := get_node_or_null("/root/GameEvents")
		if events_mono != null and events_mono.has_method("show_dialogue"):
			events_mono.call("show_dialogue", "Meșteșugar: Trebuie să ajung în camera administrativă. Era undeva pe stânga din tunelul principal. Să am grijă să nu mă vadă gardienii.", dialogue_line_duration)

func _start_exit_walk(guard_a: Node3D, guard_b: Node3D) -> void:
	if exit_path.is_empty():
		return
	var waypoints := _exit_waypoints()
	if waypoints.is_empty():
		push_warning("[GuardConversation] exit_path invalid: %s" % exit_path)
		return
	print("[GuardConversation] starting exit walk with %d waypoints" % waypoints.size())
	_walk_along(guard_a, waypoints, 0.0)
	_walk_along(guard_b, waypoints, exit_b_lag)

func _exit_waypoints() -> Array[Vector3]:
	var waypoints: Array[Vector3] = []
	if exit_path.is_empty():
		return waypoints
	var path_node := get_node_or_null(exit_path)
	if path_node == null:
		return waypoints
	for child in path_node.get_children():
		if child is Node3D:
			waypoints.append((child as Node3D).global_position)
	return waypoints

func _walk_along(guard: Node3D, waypoints: Array[Vector3], start_delay: float) -> void:
	if guard == null:
		return
	if start_delay > 0.0:
		await _wait_seconds(start_delay)
	var prev_yaw := guard.rotation.y
	for wp in waypoints:
		if not is_instance_valid(guard):
			return
		var current_pos := guard.global_position
		var dist := current_pos.distance_to(wp)
		if dist < 0.05:
			continue
		var duration := dist / maxf(0.2, exit_speed_mps)
		var to_wp := wp - current_pos
		to_wp.y = 0.0
		var target_yaw := prev_yaw
		if to_wp.length_squared() > 0.0001:
			var raw_yaw := atan2(-to_wp.x, -to_wp.z)
			target_yaw = prev_yaw + wrapf(raw_yaw - prev_yaw, -PI, PI)
		var rot_time := minf(exit_rotation_time_max, duration * 0.4)
		await _rotate_one_manual(guard, target_yaw, rot_time)
		prev_yaw = target_yaw
		await _move_one_manual(guard, wp, duration)

func _move_one_manual(node: Node3D, target: Vector3, duration: float) -> void:
	if node == null:
		return
	if duration <= 0.0:
		node.global_position = target
		return
	var start_pos := node.global_position
	var t0 := Time.get_ticks_msec()
	var dur_ms := duration * 1000.0
	while true:
		await get_tree().process_frame
		if not is_instance_valid(node):
			return
		var elapsed := float(Time.get_ticks_msec() - t0)
		var t := clampf(elapsed / dur_ms, 0.0, 1.0)
		node.global_position = start_pos.lerp(target, t)
		if t >= 1.0:
			return

func _rotate_one_manual(node: Node3D, target_yaw: float, duration: float) -> void:
	if node == null:
		return
	if duration <= 0.0:
		node.rotation.y = target_yaw
		return
	var start_yaw := node.rotation.y
	var t0 := Time.get_ticks_msec()
	var dur_ms := duration * 1000.0
	while true:
		await get_tree().process_frame
		if not is_instance_valid(node):
			return
		var elapsed := float(Time.get_ticks_msec() - t0)
		var t := clampf(elapsed / dur_ms, 0.0, 1.0)
		var s := t * t * (3.0 - 2.0 * t)
		node.rotation.y = lerpf(start_yaw, target_yaw, s)
		if t >= 1.0:
			return

func _finish() -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives != null:
		if complete_trigger_objective and trigger_objective_id != "" and objectives.has_method("complete_objective"):
			objectives.call("complete_objective", trigger_objective_id)
		if objective_after_id != "" and objective_after_text != "" and objectives.has_method("set_objective"):
			objectives.call("set_objective", objective_after_id, objective_after_text)
	_playing = false

## Manual movement: lerp pe global_position prin process_frame. Evita
## tween_property care provoaca crash pe nodurile cu AnimationPlayer activ.
func _move_two_manual(a: Node3D, target_a: Vector3, b: Node3D, target_b: Vector3, duration: float) -> void:
	if duration <= 0.0:
		if a != null: a.global_position = target_a
		if b != null: b.global_position = target_b
		return
	var start_a := a.global_position
	var start_b := b.global_position
	var t0 := Time.get_ticks_msec()
	var dur_ms := duration * 1000.0
	while true:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0)
		var t := clampf(elapsed / dur_ms, 0.0, 1.0)
		# Smoothstep (similar TRANS_SINE EASE_IN_OUT).
		var s := t * t * (3.0 - 2.0 * t)
		if a != null and is_instance_valid(a):
			a.global_position = start_a.lerp(target_a, s)
		if b != null and is_instance_valid(b):
			b.global_position = start_b.lerp(target_b, s)
		if t >= 1.0:
			return

func _rotate_two_manual(a: Node3D, yaw_a: float, b: Node3D, yaw_b: float, duration: float) -> void:
	if duration <= 0.0:
		if a != null: a.rotation.y = yaw_a
		if b != null: b.rotation.y = yaw_b
		return
	var start_ya := a.rotation.y
	var start_yb := b.rotation.y
	var t0 := Time.get_ticks_msec()
	var dur_ms := duration * 1000.0
	while true:
		await get_tree().process_frame
		var elapsed := float(Time.get_ticks_msec() - t0)
		var t := clampf(elapsed / dur_ms, 0.0, 1.0)
		var s := t * t * (3.0 - 2.0 * t)
		if a != null and is_instance_valid(a):
			a.rotation.y = lerpf(start_ya, yaw_a, s)
		if b != null and is_instance_valid(b):
			b.rotation.y = lerpf(start_yb, yaw_b, s)
		if t >= 1.0:
			return

## Workaround pentru un bug observat in Godot 4.6 unde get_tree().create_timer()
## intr-o coroutine pornita din lant signal-deferred + tween activ pe player nu
## mai fire-uieste timeout-ul. process_frame insa fire-uieste consistent.
func _wait_seconds(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	var dur_ms := seconds * 1000.0
	while Time.get_ticks_msec() - t0 < dur_ms:
		await get_tree().process_frame

## Versiune skippable a lui _wait_seconds. Cand jucatorul apasa J, iese
## anticipat din asteptare (replica curenta e sarita).
func _dialogue_wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var t0 := Time.get_ticks_msec()
	var dur_ms := seconds * 1000.0
	while Time.get_ticks_msec() - t0 < dur_ms:
		var events_node := get_node_or_null("/root/GameEvents")
		if events_node != null and events_node.has_method("is_dialogue_skip_pending") and events_node.call("is_dialogue_skip_pending"):
			if events_node.has_method("consume_dialogue_skip"):
				events_node.call("consume_dialogue_skip")
			return
		await get_tree().process_frame

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var sub := _find_animation_player(child)
		if sub != null:
			return sub
	return null

func _shortest_yaw_to(node: Node3D, target: Vector3) -> float:
	var to_t := target - node.global_position
	to_t.y = 0.0
	if to_t.length_squared() < 0.0001:
		return node.rotation.y
	var desired := atan2(-to_t.x, -to_t.z)
	var current := node.rotation.y
	return current + wrapf(desired - current, -PI, PI)

func _effective_lines() -> PackedStringArray:
	if not dialogue_lines.is_empty():
		return dialogue_lines
	var baked := _get_baked_lines(baked_dialogue_key)
	if not baked.is_empty():
		return baked
	push_warning("[GuardConversation] no dialogue lines (export empty, baked key '%s' returned nothing)" % baked_dialogue_key)
	return PackedStringArray()

# Plasa de siguranta: replici hardcodate, imune la stripping din .tscn (vezi
# feedback_dialogue_lines_stripping).
func _get_baked_lines(key: String) -> PackedStringArray:
	match key:
		"guards_gate_seal":
			return PackedStringArray([
				"Gardianul 1: Mă uit la poarta aceea de bronz și mă gândesc că n-o să mai vedem soarele de mâine. S-a dat ordinul de sigilare.",
				"Gardianul 2: Am auzit... Până se crapă de ziuă, sigilează totul. Mai mult de jumătate din sectoare sunt deja închise, printre care și al nostru.",
				"Gardianul 1: Era de așteptat. Un mormânt ca ăsta nu se lasă descuiat. Dar nu credeam că ne vor încuia și pe noi în el.",
				"Gardianul 2: Toți rămân sub munte. Nimic nu trebuie să părăsească aceste coridoare.",
				"Gardianul 1: Și dacă vreunul încearcă să iasă?",
				"Gardianul 2: Avem ordin clar: oricine se apropie de poarta principală trebuie doborât.",
				"Meșteșugar: Nu pot să cred. Ne vor îngropa aici... Nu pot rămâne.",
				"Meșteșugar: Poate Liang mă poate ajuta.",
			])
		_:
			return PackedStringArray()
