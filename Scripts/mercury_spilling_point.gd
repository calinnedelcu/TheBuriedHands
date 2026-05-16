extends Node3D

signal mercury_poured()

@export var pour_duration: float = 3.0
@export var prompt_pour: String = "Toarnă mercurul (ține E)"
@export var prompt_no_vase: String = "Ai nevoie de o vază cu mercur"
@export var prompt_empty_vase: String = "Vaza e goală"
@export var flow_group: String = "mercury_flow"
@export var pour_stream: AudioStream

@onready var _interactable: Interactable = $InteractBody/Interactable
@onready var _audio: AudioStreamPlayer3D = $Audio

var _pour_progress: float = 0.0

func _ready() -> void:
	_interactable.hold_action = true
	_interactable.prompt_text = prompt_no_vase
	_interactable.held.connect(_on_held)
	if pour_stream != null:
		_audio.stream = pour_stream

func _process(_delta: float) -> void:
	_refresh_prompt()

func _on_held(_by: Node, dt: float) -> void:
	var vase := _get_held_vase()
	if vase == null or not vase.is_filled:
		_audio.stop()
		_pour_progress = 0.0
		return
	if not _audio.playing:
		_audio.play()
	_pour_progress += dt
	if _pour_progress >= pour_duration:
		_pour_progress = 0.0
		_audio.stop()
		vase.empty()
		var player: Node3D = get_tree().get_first_node_in_group("player")
		var drop_pos: Vector3 = player.global_position + Vector3(0.6, 0.0, 0.0) if player != null else global_position
		vase.drop_at(drop_pos)
		mercury_poured.emit()
		_trigger_flow()

func _trigger_flow() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(flow_group):
		if node.has_method("start_flow"):
			node.start_flow()

func _refresh_prompt() -> void:
	if not is_inside_tree():
		return
	var vase := _get_held_vase()
	if vase == null:
		_interactable.prompt_text = prompt_no_vase
	elif not vase.is_filled:
		_interactable.prompt_text = prompt_empty_vase
	else:
		_interactable.prompt_text = prompt_pour

func _get_held_vase() -> MercuryVase:
	if not is_inside_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("mercury_vase_held")
	return nodes[0] as MercuryVase if not nodes.is_empty() else null
