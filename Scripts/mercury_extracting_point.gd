extends Node3D

@export var fill_duration: float = 2.5
@export var prompt_fill: String = "Umple vaza cu mercur (ține E)"
@export var prompt_no_vase: String = "Ai nevoie de o vază"
@export var prompt_full: String = "Vaza e deja plină"
@export var fill_stream: AudioStream

@onready var _interactable: Interactable = $InteractBody/Interactable
@onready var _audio: AudioStreamPlayer3D = $Audio

var _fill_progress: float = 0.0

func _ready() -> void:
	_interactable.hold_action = true
	_interactable.prompt_text = prompt_no_vase
	_interactable.held.connect(_on_held)
	if fill_stream != null:
		_audio.stream = fill_stream
	_audio.bus = &"Tomb"

func _process(_delta: float) -> void:
	_refresh_prompt()

func _on_held(_by: Node, dt: float) -> void:
	var vase := _get_held_vase()
	if vase == null or vase.is_filled:
		_audio.stop()
		_fill_progress = 0.0
		return
	if not _audio.playing:
		_audio.play()
	_fill_progress += dt
	if _fill_progress >= fill_duration:
		_fill_progress = 0.0
		vase.fill()
		_audio.stop()

func _refresh_prompt() -> void:
	if not is_inside_tree():
		return
	var vase := _get_held_vase()
	if vase == null:
		_interactable.prompt_text = prompt_no_vase
	elif vase.is_filled:
		_interactable.prompt_text = prompt_full
	else:
		_interactable.prompt_text = prompt_fill

func _get_held_vase() -> MercuryVase:
	if not is_inside_tree():
		return null
	var nodes := get_tree().get_nodes_in_group("mercury_vase_held")
	return nodes[0] as MercuryVase if not nodes.is_empty() else null
