extends CanvasLayer

@export var main_menu_scene: String = "res://scenes/main_menu.tscn"

@onready var _root: Control = $Root
@onready var _resume: Button = $Root/Panel/VBox/ResumeButton
@onready var _restart: Button = $Root/Panel/VBox/RestartButton
@onready var _menu: Button = $Root/Panel/VBox/MenuButton
@onready var _quit: Button = $Root/Panel/VBox/QuitButton

var _is_paused: bool = false
var _was_mouse_captured: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_resume.pressed.connect(func(): _set_paused(false))
	_restart.pressed.connect(_on_restart)
	_menu.pressed.connect(_on_menu)
	_quit.pressed.connect(_on_quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _is_paused:
		_set_paused(false)
	else:
		_set_paused(true)
	get_viewport().set_input_as_handled()

func _set_paused(p: bool) -> void:
	_is_paused = p
	get_tree().paused = p
	_root.visible = p
	if p:
		_was_mouse_captured = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		if _was_mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
	get_tree().quit()
