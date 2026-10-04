class_name Counterweight
extends Node3D
## Liang's counterweight. Pour a jar of mercury into its basin and the great
## balance tips, grinding the treasury gate open. The old balance model's
## animation plays out over `tip_seconds`.

const POUR_SOUND := preload("res://audio/sfx/mercury/flow.mp3")
const GEARS := preload("res://audio/sfx/mechanisms/ancient_mechanical_gears.mp3")

@export var balance_path: NodePath
@export var gate_paths: Array[NodePath] = []
## Nodes with start_flow() (mercury jets) to start when it tips.
@export var flow_paths: Array[NodePath] = []
@export var tip_seconds := 7.0

@onready var _usable: DelegateUsable = $Body/Usable
@onready var _audio: AudioStreamPlayer3D = $Audio

var tipped := false
var _anim: AnimationPlayer

func _ready() -> void:
	add_to_group(&"persistent")
	_usable.hold_time = 2.4
	var balance := get_node_or_null(balance_path)
	if balance != null:
		var found := balance.find_children("*", "AnimationPlayer", true, false)
		_anim = found[0] as AnimationPlayer if not found.is_empty() else null

func _process(_delta: float) -> void:
	# Examining is a press; pouring is a hold.
	_usable.hold_time = 0.0 if Quest.is_at(&"inspect_balance") else 2.4

func usable_prompt(user: Node) -> String:
	if tipped:
		return ""
	var p := user as Player
	if Quest.is_at(&"inspect_balance"):
		return tr("PROMPT_EXAMINE")
	if p != null and p.inventory.has_item(&"vase_full"):
		return tr("PROMPT_POUR")
	return tr("PROMPT_NEED_FULL_VASE") if Quest.has_reached(&"get_vase") else ""

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	if tipped or p == null:
		return false
	return Quest.is_at(&"inspect_balance") or p.inventory.has_item(&"vase_full")

func usable_show_blocked(_user: Node) -> bool:
	return not tipped and Quest.has_reached(&"get_vase")

func usable_use(_user: Node) -> void:
	if Quest.is_at(&"inspect_balance"):
		Story.fire(&"inspect_balance", &"balance_inspect")

func usable_hold_tick(_user: Node, _progress: float) -> void:
	if not _audio.playing:
		_audio.stream = POUR_SOUND
		_audio.play()

func usable_hold_cancelled(_user: Node) -> void:
	_audio.stop()

func usable_hold_done(user: Node) -> void:
	var p := user as Player
	if p == null or not p.inventory.remove(&"vase_full"):
		return
	_audio.stop()
	_tip(true)

func _tip(animate: bool) -> void:
	tipped = true
	if animate:
		Dialogue.play(&"poured")
		_audio.stream = GEARS
		_audio.play()
		var balance := get_node_or_null(balance_path)
		if balance != null and balance.has_method(&"start_flow"):
			balance.call(&"start_flow")
		elif _anim != null:
			var names := _anim.get_animation_list()
			if not names.is_empty():
				var anim := _anim.get_animation(names[0])
				_anim.play(names[0], 0.1, anim.length / tip_seconds)
		for path in flow_paths:
			var jet := get_node_or_null(path)
			if jet != null and jet.has_method(&"start_flow"):
				jet.call(&"start_flow")
		var player := get_tree().get_first_node_in_group(&"player") as Player
		if player != null:
			player.add_shake(0.5)
		await get_tree().create_timer(tip_seconds * 0.6, false).timeout
	else:
		if _anim != null and not _anim.get_animation_list().is_empty():
			var n := _anim.get_animation_list()[0]
			_anim.play(n)
			_anim.seek(_anim.get_animation(n).length, true)
			_anim.pause()
	for path in gate_paths:
		var gate := get_node_or_null(path)
		if gate != null and gate.has_method(&"open"):
			gate.call(&"open", animate)
	if animate:
		Quest.complete(&"pour_mercury")
		Game.advance_sealing(2)

func persist_save() -> Dictionary:
	return {"tipped": tipped}

func persist_load(data: Dictionary) -> void:
	if bool(data.get("tipped", false)) and not tipped:
		_tip(false)

func _first_anim_player() -> AnimationPlayer:
	var found := find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
