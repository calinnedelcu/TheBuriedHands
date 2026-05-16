class_name Ladder
extends Node3D

@export var player_group: String = "player"

@onready var _top_exit: Marker3D = $TopExit
@onready var _bottom_exit: Marker3D = $BottomExit
@onready var _interactable: Interactable = $InteractBody/Interactable
@onready var _entry_area: Area3D = $EntryArea

var _active_climber: CharacterBody3D = null

func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	_entry_area.body_entered.connect(_on_entry_entered)
	_entry_area.body_exited.connect(_on_entry_exited)

func _on_interacted(by: Node) -> void:
	if _active_climber != null:
		return
	var player := _resolve_player(by)
	if player == null or not player.has_method("enter_ladder"):
		return
	_active_climber = player
	player.enter_ladder(self)

func _on_entry_entered(body: Node) -> void:
	if body.is_in_group(player_group) and body.has_method("set_nearby_ladder"):
		body.set_nearby_ladder(self)

func _on_entry_exited(body: Node) -> void:
	if body.is_in_group(player_group) and body.has_method("set_nearby_ladder"):
		body.set_nearby_ladder(null)

## Apelat de player cand paraseste scara.
func notify_climber_exited() -> void:
	_active_climber = null

func get_top_exit() -> Marker3D:
	return _top_exit

func get_bottom_exit() -> Marker3D:
	return _bottom_exit

func _resolve_player(node: Node) -> CharacterBody3D:
	var n := node
	while n != null:
		if n is CharacterBody3D and n.is_in_group(player_group):
			return n as CharacterBody3D
		n = n.get_parent()
	return get_tree().get_first_node_in_group(player_group) as CharacterBody3D
