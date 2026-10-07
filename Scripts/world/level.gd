class_name Level
extends Node3D
## Root of a playable level. Registers with Game once everything is ready so
## checkpoints can be restored, and hosts the pause and death screens.

const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const DEATH_SCREEN := preload("res://scenes/ui/death_screen.tscn")

func _ready() -> void:
	add_child(PAUSE_MENU.instantiate())
	add_child(DEATH_SCREEN.instantiate())
	# Co-op: the apprentice joins the level.
	Net.setup_level(self)
	Game.register_level.call_deferred(self)

func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player
