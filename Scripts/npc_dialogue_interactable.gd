class_name NpcDialogueInteractable
extends Interactable

@export var continue_prompt_text: String = "Continuă"
@export var dialogue_lines: PackedStringArray = []
@export var dialogue_line_duration: float = 5.5
@export var disable_after_finished: bool = true
## Fallback hardcoded folosit cand `dialogue_lines` e gol (ex. dupa ce un
## save Godot strica array-ul). Permite NPC-ului sa ramana functional fara
## sa depinda exclusiv de .tscn.
@export var fallback_dialogue_lines: PackedStringArray = []
## Cheie care selecteaza un set de replici hardcodate in `_get_baked_lines()`.
## Folosit ca PLASA DE SIGURANTA FINALA cand atat `dialogue_lines` cat si
## `fallback_dialogue_lines` au fost golite din .tscn (problema recurenta cu
## auto-save / agenti externi care curata array-urile). Setezi cheia in .tscn
## sau folosim `initial_objective_id` automat.
@export var baked_dialogue_key: String = ""

@export_group("Objective Gate")
@export var required_objective_id: String = ""

@export_group("Initial Objective")
@export var set_initial_objective_on_ready: bool = false
@export var initial_objective_id: String = ""
@export_multiline var initial_objective_text: String = ""
## Daca e true, obiectivul initial apare abia dupa ce monologul de intro
## (scene_intro_dialogue) termina toate replicile.
@export var wait_for_intro: bool = false

@export_group("Focus Cinematic")
## La setarea obiectivului initial, camera face un pan scurt catre NPC. Player-ul
## nu mai e bulversat de "unde e ucenicul?". Daca e deja cu fata spre tinta,
## cinematic-ul se sare automat (din player_controller.play_cinematic_focus).
@export var focus_player_on_objective: bool = false
## Optional: nod 3D care defineste tinta cinematic-ului. Daca e gol, folosim
## global position-ul parintelui (interaction body-ul NPC-ului) cu un offset
## vertical pentru piept.
@export var focus_target_path: NodePath = NodePath("")
@export var focus_target_offset: Vector3 = Vector3(0.0, 1.2, 0.0)
@export var focus_delay: float = 0.55
@export var focus_pan_duration: float = 0.75
@export var focus_hold_time: float = 0.65
## FOV catre care zoomam in timpul cinematic-ului. Mai mic = zoom mai puternic.
## Default 42° (de la ~70° default Godot) = ~1.7x zoom. Setezi 30° pentru zoom
## dramatic apropiat, 55° pentru zoom subtil.
@export var focus_zoom_fov: float = 42.0
@export var focus_zoom_return_duration: float = 0.55

@export_group("Objective After Dialogue")
@export var complete_objective_id: String = ""
@export var objective_after_id: String = ""
@export_multiline var objective_after_text: String = ""
@export var objective_after_if_lamp_id: String = ""
@export_multiline var objective_after_if_lamp_text: String = ""

@export_group("NPC Animation")
@export var animated_npc_path: NodePath = NodePath("")
@export var animated_npc_search_name: String = ""
@export var first_interaction_animation: StringName = &""
@export var dialogue_idle_animation: StringName = &""
@export var finished_animation: StringName = &""
@export_range(0.1, 3.0, 0.05) var first_interaction_animation_speed: float = 1.0
## Array paralel cu dialogue_lines: pentru fiecare index se poate seta o
## animație care suprascrie dialogue_idle_animation. Sirul gol = folosește
## dialogue_idle_animation. Dacă array-ul e mai scurt decât replicile,
## replicile fără corespondent rămân pe dialogue_idle_animation.
@export var per_line_animations: Array[StringName] = []
@export_range(0.0, 1.0, 0.05) var animation_blend: float = 0.15
@export var face_player_during_dialogue: bool = false
@export_range(-180.0, 180.0, 1.0) var face_player_yaw_offset_degrees: float = 0.0
@export_range(0.0, 1.5, 0.05) var face_player_turn_duration: float = 0.3
@export var restore_original_rotation_after_dialogue: bool = true
@export_range(0.0, 1.5, 0.05) var restore_rotation_duration: float = 0.35
## Negative value = wait for the current dialogue line duration before returning
## to `finished_animation`, so the NPC stays in dialogue idle while the last
## line is still visible.
@export var finished_animation_delay: float = -1.0

var _line_index: int = 0
var _finished: bool = false
var _first_animation_played: bool = false
var _animation_sequence_active: bool = false
var _cached_npc_node: Node3D = null
var _cached_animation_player: AnimationPlayer = null
var _original_npc_rotation := Vector3.ZERO
var _has_original_npc_rotation: bool = false
var _npc_turn_tween: Tween = null

func _ready() -> void:
	# Avertisment vizibil daca toate sursele de replici sunt goale — sa nu mai
	# pierdem ore intrebandu-ne de ce E nu face nimic pe NPC.
	if _effective_lines().is_empty():
		push_warning("[npc_dialogue] '%s' nu are replici (dialogue_lines, fallback_dialogue_lines si baked_dialogue_key='%s' sunt toate goale)." % [name, baked_dialogue_key if baked_dialogue_key != "" else initial_objective_id])
	if not set_initial_objective_on_ready or initial_objective_text == "":
		return
	if wait_for_intro:
		var events := get_node_or_null("/root/GameEvents")
		if events != null and not bool(events.get("intro_done")):
			await events.intro_finished
	_apply_initial_objective()

func _apply_initial_objective() -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null or not objectives.has_method("set_objective"):
		return
	if objectives.has_method("current_id") and objectives.current_id() != "":
		return
	objectives.set_objective(initial_objective_id, initial_objective_text)
	if focus_player_on_objective:
		_trigger_focus_cinematic()

func _trigger_focus_cinematic() -> void:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player == null or not player.has_method("play_cinematic_focus"):
		return
	var target_node: Node3D = null
	if not focus_target_path.is_empty():
		target_node = get_node_or_null(focus_target_path) as Node3D
	if target_node == null:
		target_node = get_parent() as Node3D
	if target_node == null:
		return
	var target_pos: Vector3 = target_node.global_position + focus_target_offset
	if focus_delay > 0.0:
		await get_tree().create_timer(focus_delay).timeout
	if not is_instance_valid(player):
		return
	# Daca intre timp obiectivul a fost schimbat (ex. debug skip sau quest
	# avansat de alt sistem), nu mai porni cinematic-ul — ar bloca input-ul
	# fara motiv.
	var objectives := get_node_or_null("/root/Objectives")
	if objectives != null and objectives.has_method("current_id") and initial_objective_id != "":
		if str(objectives.call("current_id")) != initial_objective_id:
			return
	player.call("play_cinematic_focus", target_pos, focus_pan_duration, focus_hold_time, focus_zoom_fov, focus_zoom_return_duration)

func get_prompt(_by: Node) -> String:
	if _animation_sequence_active:
		return ""
	if _finished and disable_after_finished:
		return ""
	if _line_index > 0 and _line_index < _effective_lines().size():
		return continue_prompt_text
	return prompt_text

func can_interact(_by: Node) -> bool:
	if _animation_sequence_active:
		return false
	if not super.can_interact(_by) or _effective_lines().is_empty():
		return false
	if _finished and disable_after_finished:
		return false
	if required_objective_id != "":
		var objectives := get_node_or_null("/root/Objectives")
		if objectives == null or not objectives.has_method("current_id"):
			return false
		if str(objectives.call("current_id")) != required_objective_id:
			return false
	return true

func interact(by: Node) -> void:
	if not can_interact(by):
		return
	_used = true
	interacted.emit(by)
	if _should_play_first_animation():
		_play_first_animation_then_dialogue(by)
		return
	if _line_index == 0:
		_start_dialogue_turn_toward_player(by)
	_ensure_dialogue_idle_animation()
	_advance_dialogue(by)

func _advance_dialogue(by: Node) -> void:
	_show_current_line()
	_line_index += 1
	if _line_index >= _effective_lines().size():
		_finished = true
		_apply_objective_after_dialogue(by)
		_return_to_finished_animation_after_dialogue()
		if disable_after_finished:
			enabled = false

func reset_dialogue() -> void:
	_line_index = 0
	_finished = false
	_first_animation_played = false
	_animation_sequence_active = false
	enabled = true
	reset()

func _should_play_first_animation() -> bool:
	return not _first_animation_played and _line_index == 0 and first_interaction_animation != &""

func _play_first_animation_then_dialogue(by: Node) -> void:
	_first_animation_played = true
	_animation_sequence_active = true
	if face_player_during_dialogue:
		await _turn_npc_toward_player(by, true)
	if _play_npc_animation(first_interaction_animation, false, true, first_interaction_animation_speed):
		await _wait_for_animation(first_interaction_animation, first_interaction_animation_speed)
	_animation_sequence_active = false
	if not is_inside_tree() or not can_interact(by):
		return
	_ensure_dialogue_idle_animation()
	_advance_dialogue(by)

func _ensure_dialogue_idle_animation() -> void:
	var anim_name: StringName = _get_line_animation_override(_line_index)
	if anim_name == &"":
		anim_name = dialogue_idle_animation
	if anim_name == &"":
		return
	var animation_player := _get_npc_animation_player()
	var resolved_animation := _resolve_animation_name(animation_player, anim_name)
	if resolved_animation != &"" and animation_player.current_animation == resolved_animation:
		return
	_play_npc_animation(anim_name, true, false, 1.0)

func _get_line_animation_override(line_index: int) -> StringName:
	if line_index >= 0 and line_index < per_line_animations.size():
		var ov := per_line_animations[line_index]
		if ov != &"":
			return ov
	return &""

func _return_to_finished_animation_after_dialogue() -> void:
	if finished_animation == &"":
		return
	var delay := finished_animation_delay
	if delay < 0.0:
		delay = dialogue_line_duration
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not is_inside_tree():
		return
	if restore_original_rotation_after_dialogue:
		await _turn_npc_to_original_rotation(true)
	_play_npc_animation(finished_animation, true, false, 1.0)

func _turn_npc_toward_player(by: Node, wait_for_turn: bool) -> void:
	await _turn_npc_toward_player_impl(by, wait_for_turn)

func _start_dialogue_turn_toward_player(by: Node) -> void:
	if not face_player_during_dialogue:
		return
	var npc := _get_npc_node()
	var player_node := _resolve_player(by) as Node3D
	if npc == null or player_node == null:
		return
	_capture_original_npc_rotation(npc)
	var to_player := player_node.global_position - npc.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return
	to_player = to_player.normalized()
	var target_yaw := atan2(-to_player.x, -to_player.z) + deg_to_rad(face_player_yaw_offset_degrees)
	_begin_npc_turn_to_yaw(target_yaw, face_player_turn_duration)

func _turn_npc_toward_player_impl(by: Node, wait_for_turn: bool) -> void:
	var npc := _get_npc_node()
	var player_node := _resolve_player(by) as Node3D
	if npc == null or player_node == null:
		return
	_capture_original_npc_rotation(npc)
	var to_player := player_node.global_position - npc.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return
	to_player = to_player.normalized()
	var target_yaw := atan2(-to_player.x, -to_player.z) + deg_to_rad(face_player_yaw_offset_degrees)
	await _turn_npc_to_yaw(target_yaw, face_player_turn_duration, wait_for_turn)

func _turn_npc_to_original_rotation(wait_for_turn: bool) -> void:
	var npc := _get_npc_node()
	if npc == null or not _has_original_npc_rotation:
		return
	await _turn_npc_to_yaw(_original_npc_rotation.y, restore_rotation_duration, wait_for_turn)
	if is_instance_valid(npc):
		npc.rotation = _original_npc_rotation

func _turn_npc_to_yaw(target_yaw: float, duration: float, wait_for_turn: bool) -> void:
	var tween := _begin_npc_turn_to_yaw(target_yaw, duration)
	if wait_for_turn and tween != null:
		await tween.finished

func _begin_npc_turn_to_yaw(target_yaw: float, duration: float) -> Tween:
	var npc := _get_npc_node()
	if npc == null:
		return null
	if _npc_turn_tween != null and _npc_turn_tween.is_running():
		_npc_turn_tween.kill()
	_npc_turn_tween = null

	var current_yaw := npc.rotation.y
	var nearest_target_yaw := current_yaw + wrapf(target_yaw - current_yaw, -PI, PI)
	if duration <= 0.0:
		npc.rotation.y = nearest_target_yaw
		return null

	_npc_turn_tween = create_tween()
	_npc_turn_tween.tween_property(npc, "rotation:y", nearest_target_yaw, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _npc_turn_tween

func _capture_original_npc_rotation(npc: Node3D) -> void:
	if _has_original_npc_rotation or npc == null:
		return
	_original_npc_rotation = npc.rotation
	_has_original_npc_rotation = true

func _play_npc_animation(animation_name: StringName, loop: bool, restart: bool, speed: float) -> bool:
	var animation_player := _get_npc_animation_player()
	var resolved_animation := _resolve_animation_name(animation_player, animation_name)
	if resolved_animation == &"":
		return false
	var animation := animation_player.get_animation(resolved_animation)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	animation_player.play(resolved_animation, animation_blend, speed)
	if restart:
		animation_player.seek(0.0, true)
	return true

func _wait_for_animation(animation_name: StringName, speed: float) -> void:
	var animation_player := _get_npc_animation_player()
	var resolved_animation := _resolve_animation_name(animation_player, animation_name)
	if resolved_animation == &"":
		return
	var animation := animation_player.get_animation(resolved_animation)
	if animation == null:
		return
	var duration: float = animation.length / max(0.01, absf(speed))
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout

func _resolve_animation_name(animation_player: AnimationPlayer, requested: StringName) -> StringName:
	if animation_player == null or requested == &"":
		return &""
	if animation_player.has_animation(requested):
		return requested

	var requested_text := String(requested)
	var requested_normalized := requested_text.replace(".", "_")
	for available in animation_player.get_animation_list():
		var available_text := String(available)
		if available_text.replace(".", "_") == requested_normalized:
			return StringName(available_text)
	return &""

func _get_npc_animation_player() -> AnimationPlayer:
	if _cached_animation_player != null and is_instance_valid(_cached_animation_player):
		return _cached_animation_player
	var target := _get_npc_node()
	if target == null:
		return null
	_cached_animation_player = _find_animation_player(target)
	return _cached_animation_player

func _get_npc_node() -> Node3D:
	if _cached_npc_node != null and is_instance_valid(_cached_npc_node):
		return _cached_npc_node
	var target: Node = null
	if not animated_npc_path.is_empty():
		target = get_node_or_null(animated_npc_path)
	if target == null and animated_npc_search_name != "":
		var scene_root := get_tree().current_scene if is_inside_tree() else null
		if scene_root != null:
			target = scene_root.find_child(animated_npc_search_name, true, false)
	if target == null:
		target = get_parent()
	_cached_npc_node = target as Node3D
	return _cached_npc_node

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _show_current_line() -> void:
	var events := get_node_or_null("/root/GameEvents")
	if events != null and events.has_method("show_dialogue"):
		var lines: PackedStringArray = _effective_lines()
		if _line_index < lines.size():
			events.show_dialogue(str(lines[_line_index]), dialogue_line_duration)

func _effective_lines() -> PackedStringArray:
	if not dialogue_lines.is_empty():
		return dialogue_lines
	if not fallback_dialogue_lines.is_empty():
		return fallback_dialogue_lines
	# Plasa de siguranta finala — replici imuabile, traiesc in cod, nu pot fi
	# sterse de save-uri de Godot sau de alti agenti care editeaza .tscn.
	var key: String = baked_dialogue_key if baked_dialogue_key != "" else initial_objective_id
	return _get_baked_lines(key)

func _get_baked_lines(key: String) -> PackedStringArray:
	match key:
		"talk_to_apprentice":
			return PackedStringArray([
				"Ucenic: Maestre, după ritual ne lasă să mergem acasă?",
				"Meșteșugar: După un asemenea mormânt, nimeni nu mai pleacă neschimbat.",
				"Ucenic: Mai avem nevoie de barbotină pentru picioarele soldatului. O aduceți din magazie?",
				"Meșteșugar: Va trebui să iau bolul cu barbotina din camera din celălalt capăt.",
			])
		"talk_to_liang":
			return PackedStringArray([
				"Liang: Tu?! Ești nebun? Cum ai trecut de gardieni?",
				"Meșteșugar: M-am strecurat pe la administrație. Nu sunt atât de atenți.",
				"Liang: Dar nu înțeleg... De ce ai venit aici? Nu lasă pe nimeni să intre sau să iasă din atelier.",
				"Meșteșugar: Liang, ascultă-mă. Nu pot să rămân aici să aștept să se termine aerul. Trebuie să ies. Acum.",
				"Liang: Să ieși...? Pe unde? Tot ce am construit în ultimii zece ani a fost gândit ca nimeni, niciodată, să nu poată să intre după moartea Împăratului.",
				"Meșteșugar: Dar tu ai desenat jumătate din pasajele ascunse. Știi unde sunt punctele slabe.",
				"Liang: Am lucrat la pasaje, da... dar m-au pus să lucrez pe bucăți. O secțiune aici, una dincolo. Ne-au orbit cu detalii ca să nu vedem întregul.",
				"Meșteșugar: Nu mă minți. Spune-mi tot ce știi. Trebuie să fie o cale de scăpare undeva prin tunelurile astea.",
				"Liang: Majoritatea sunt capcane moarte. Dacă pui piciorul greșit, te transformi în perniță de ace. Iar restul duc în locuri unde moartea e și mai lentă.",
				"Liang: Există un drum prin tunelul secret din spate. Te scoate aproape de tezaur, dar trece pe lângă Camera cu Mercur.",
				"Meșteșugar: Mercur...? Râurile acelea ca de argint despre care mi-ai mai vorbit?",
				"Liang: Aerul de acolo e greu, metalic. Treci repede. Vaporii de mercur sunt toxici; dacă zăbovești, nu mai ieși viu.",
				"Meșteșugar: Există altă cale? Un drum secret? Orice altceva?",
				"Liang: Mai mult de atât nu știu.",
				"Meșteșugar: Atunci vino cu mine. Dacă știi drumul, avem o șansă să vedem lumina din nou.",
				"Liang: Nu pot, prietene. Spatele mi-e frânt și genunchii nu mă mai țin să mă târăsc prin găurile acelea. Doar te-aș încetini.",
				"Meșteșugar: Liang...",
				"Liang: Dar tu trebuie să scapi. Există o cameră pe care arhitecții au conceput-o împotriva hoților. E un mecanism vechi, ascuns lângă încăperea unde se păstrează tezaurul.",
				"Liang: E o contragreutate. Ca s-o declanșezi pe dinăuntru, ai nevoie de ceva greu, dar nici eu nu știu exact ce.",
				"Meșteșugar: Ceva greu, zici?",
				"Liang: Când ajungi la Camera cu Mercur, acoperă-ți nasul și gura cu o cârpă umedă. Nu trage aer adânc în piept.",
				"Liang: Acum du-te. În camera alăturată e o piatră mare care blochează drumul. Sparge-o cu ciocanul și pana de lemn.",
				"Meșteșugar: Am uneltele. Mă descurc.",
				"Liang: Bine. După ce spargi piatra, drumul te va duce unde ai nevoie.",
				"Meșteșugar: Mulțumesc, Liang...",
			])
		_:
			return PackedStringArray()

func _apply_objective_after_dialogue(by: Node) -> void:
	var objectives := get_node_or_null("/root/Objectives")
	if objectives == null:
		return
	if complete_objective_id != "" and objectives.has_method("complete_objective"):
		objectives.complete_objective(complete_objective_id)
	var next_id := objective_after_id
	var next_text := objective_after_text
	if objective_after_if_lamp_text != "" and _player_has_lamp(by):
		next_id = objective_after_if_lamp_id
		next_text = objective_after_if_lamp_text
	if next_text != "" and objectives.has_method("set_objective"):
		objectives.set_objective(next_id, next_text)

func _player_has_lamp(by: Node) -> bool:
	var player_node := _resolve_player(by)
	if player_node == null:
		return false
	var inv: Node = player_node.get_node_or_null("Inventory")
	if inv != null and inv.has_method("find_lamp"):
		return inv.call("find_lamp") != null
	return false

func _resolve_player(by: Node) -> Node:
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			return n
		n = n.get_parent()
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null
