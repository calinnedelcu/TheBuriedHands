extends CanvasLayer

@export var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _reason: Label = $Root/Panel/VBox/ReasonLabel
@onready var _retry: Button = $Root/Panel/VBox/RetryButton
@onready var _menu: Button = $Root/Panel/VBox/MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_retry.pressed.connect(_on_retry)
	_menu.pressed.connect(_on_menu)
	if has_node("/root/GameEvents"):
		get_node("/root/GameEvents").player_failed.connect(_on_failed)

func _on_failed(reason: String) -> void:
	_reason.text = reason
	_root.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
