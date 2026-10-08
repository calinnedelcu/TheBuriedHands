class_name Readable
extends StaticBody3D
## Something with writing on it to read close up, by a flame: the lines the
## masons cut into the edge of Bai's bench, the strip of bamboo at his dead
## son's belt. What it says is MasonsSong's (`source`); without a lit lamp
## it's too dark to make out.

@export var source: StringName = &"bench"
@export var prompt_key := "PROMPT_READ"
## Searching a body for it, rather than reading what's in plain sight.
@export var search := false
@export var radius := 0.35

var _usable: DelegateUsable

func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	if get_child_count() == 0 or not (get_child(0) is CollisionShape3D):
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		cs.shape = sphere
		add_child(cs)
	_usable = DelegateUsable.new()
	_usable.name = "Usable"
	_usable.prompt_key = prompt_key
	_usable.delegate_path = ^".."
	_usable.highlight = false
	add_child(_usable)

func usable_prompt(user: Node) -> String:
	var p := user as Player
	if p == null:
		return ""
	if not p.has_lamp_lit():
		return tr("PROMPT_TOO_DARK_TO_READ")
	return tr("PROMPT_SEARCH_BODY" if search else prompt_key)

func usable_can_use(user: Node) -> bool:
	var p := user as Player
	return p != null and p.has_lamp_lit() and not Dialogue.is_busy()

func usable_show_blocked(user: Node) -> bool:
	var p := user as Player
	return p != null and not p.has_lamp_lit()

func usable_use(user: Node) -> void:
	MasonsSong.read(source, user)
