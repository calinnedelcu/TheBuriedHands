extends Node3D

signal mercury_poured()

@export var pour_duration: float = 1.5
@export var prompt_pour: String = "Toarnă mercurul (ține E)"
@export var prompt_no_vase: String = "Ai nevoie de o vază cu mercur"
@export var prompt_empty_vase: String = "Vaza e goală"
@export var prompt_already_active: String = "Mecanismul este deja activat"
@export var flow_group: String = "mercury_flow"
@export var pour_stream: AudioStream

@onready var _interactable: Interactable = $InteractBody/Interactable
@onready var _audio: AudioStreamPlayer3D = $Audio

var _pour_progress: float = 0.0
var _hold_timeout: float = 0.0
var _activated: bool = false

func _ready() -> void:
	_interactable.hold_action = true
	_interactable.prompt_text = prompt_no_vase
	_interactable.held.connect(_on_held)
	if pour_stream != null:
		_audio.stream = pour_stream

func _process(delta: float) -> void:
	_refresh_prompt()
	_hold_timeout = maxf(0.0, _hold_timeout - delta)
	if _hold_timeout <= 0.0:
		if _audio.playing:
			_audio.stop()
		_pour_progress = 0.0

func _on_held(_by: Node, dt: float) -> void:
	if _activated:
		_pour_progress = 0.0
		if _audio.playing:
			_audio.stop()
		return

	_hold_timeout = 0.2
	var vase: MercuryVase = _get_held_vase()
	if vase == null or not vase.is_filled:
		return
	if not _audio.playing:
		_audio.play()
	_pour_progress += dt
	if _pour_progress >= pour_duration:
		_pour_progress = 0.0
		_audio.stop()
		_hold_timeout = 0.0
		vase.empty()
		_activated = true
		mercury_poured.emit()
		_trigger_flow()

func _trigger_flow() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(flow_group):
		if node.has_method("start_flow"):
			node.start_flow()

func _refresh_prompt() -> void:
	if not is_inside_tree():
		return
	if _activated:
		_interactable.prompt_text = prompt_already_active
		return

	var vase: MercuryVase = _get_held_vase()
	if vase == null:
		_interactable.prompt_text = prompt_no_vase
	elif not vase.is_filled:
		_interactable.prompt_text = prompt_empty_vase
	else:
		_interactable.prompt_text = prompt_pour

func _get_held_vase() -> MercuryVase:
	if not is_inside_tree():
		return null
	var nodes: Array[Node] = get_tree().get_nodes_in_group("mercury_vase_held")
	return nodes[0] as MercuryVase if not nodes.is_empty() else null
