extends Node3D

## Rezervor de ulei flexibil — se ataseaza langa orice nod (de obicei o lampa
## statica). Cand player-ul tine apasat E in raza ei, transfera ulei in lampa
## activa din inventar. Cand oil_amount ajunge la 0, dezactiveaza Light-ul tinta.
##
## Necesita un copil `Interactable` (cu `hold_action = true`) si un copil
## StaticBody3D + CollisionShape3D pentru raycast-ul de interactiune.

signal oil_changed(amount: float, max_amount: float)
signal depleted()

@export var oil_amount: float = 200.0
@export var oil_max: float = 200.0
## Cat de incet arde rezervorul in idle (cand nu e drenat). Valoare mica =
## rezervor static aprins luni intregi.
@export var idle_drain_rate: float = 0.025
## Cat ulei intra in lampa player-ului pe secunda cat timp tine apasat E.
@export var refill_per_second: float = 8.0
## Multiplicator pe consumul din rezervor: pour real = refill * acest factor.
## > 1.0 = se pierde (se varsa) ulei in timp ce torni. 2.0 inseamna ca rezervorul
## pierde dublu fata de cat castiga lampa player-ului.
@export var reservoir_drain_multiplier: float = 2.0
@export var prompt_text: String = "Toarnă ulei în lampă"
## Light3D pe care il stinge cand oil_amount ajunge la 0.
@export var light_path: NodePath
## Cand light-ul tinta are static_lamp_flicker.gd, ii dam un alt prompt cand player-ul are
## o lampa goala / sau nu are lampa.
@export var prompt_no_lamp: String = "Ai nevoie de o lampă"
@export var prompt_lamp_not_selected: String = "Selectează lampa cu Z"
@export var prompt_full: String = "Lampă plină"
@export var prompt_empty: String = "Rezervor gol"
@export_group("Low Oil Light")
@export var low_oil_warning_threshold_pct: float = 0.14
@export var low_oil_min_light_multiplier: float = 0.28

@onready var _light: Node = get_node_or_null(light_path)
@onready var _interactable: Interactable = get_node_or_null("Interactable")

var _initial_visible: bool = true

func _ready() -> void:
	if _light != null and _light is Light3D:
		_initial_visible = (_light as Light3D).visible
	if _interactable != null:
		_interactable.hold_action = true
		_interactable.prompt_text = prompt_text
		# Override get_prompt prin signal — pastram simplu, schimbam prompt_text live
		_interactable.held.connect(_on_held)
	_refresh_light()
	oil_changed.emit(oil_amount, oil_max)

func _process(delta: float) -> void:
	if oil_amount <= 0.0:
		_update_prompt_for_state(null, false)
		return
	oil_amount = max(0.0, oil_amount - idle_drain_rate * delta)
	oil_changed.emit(oil_amount, oil_max)
	_refresh_light()
	_refresh_prompt_for_player()
	if oil_amount <= 0.0:
		depleted.emit()

func _refresh_light() -> void:
	if _light == null or not (_light is Light3D):
		return
	var l := _light as Light3D
	l.visible = oil_amount > 0.0 and _initial_visible
	if _light.has_method("set_oil_light_strength"):
		_light.call("set_oil_light_strength", _current_oil_light_strength())

func _current_oil_light_strength() -> float:
	if oil_max <= 0.0:
		return 1.0
	var pct: float = clamp(oil_amount / oil_max, 0.0, 1.0)
	var threshold := maxf(0.001, low_oil_warning_threshold_pct)
	if pct >= threshold:
		return 1.0
	return lerp(low_oil_min_light_multiplier, 1.0, pct / threshold)

func _on_held(by: Node, dt: float) -> void:
	if oil_amount <= 0.0:
		_update_prompt_for_state(null, false)
		return
	var target: Object = _resolve_player_lamp(by)
	if target == null:
		_update_prompt_for_state(null, _player_has_lamp(by))
		return
	var current_oil: float = float(target.get("oil_level"))
	var max_oil: float = float(target.get("oil_max"))
	var space_left: float = max(0.0, max_oil - current_oil)
	if space_left <= 0.0:
		_update_prompt_for_state(target, true)
		return
	# Lampa primeste refill_per_second*dt; rezervorul pierde de `reservoir_drain_multiplier` ori mai mult.
	# Cap pe ce rezervorul mai poate suporta inainte de a ajunge la 0.
	var max_lamp_gain_from_reservoir: float = oil_amount / max(0.001, reservoir_drain_multiplier)
	var lamp_gain: float = min(refill_per_second * dt, space_left, max_lamp_gain_from_reservoir)
	if lamp_gain <= 0.0:
		return
	var reservoir_loss: float = lamp_gain * reservoir_drain_multiplier
	oil_amount = max(0.0, oil_amount - reservoir_loss)
	target.set("oil_level", current_oil + lamp_gain)
	# emit pe lampa player-ului ca sa actualizeze HUD-ul
	if target.has_signal("oil_changed"):
		target.emit_signal("oil_changed", current_oil + lamp_gain, max_oil)
	oil_changed.emit(oil_amount, oil_max)
	_refresh_light()
	_play_refill_feedback(by)
	if oil_amount <= 0.0:
		depleted.emit()

func _resolve_player_lamp(by: Node) -> Object:
	if by == null:
		return null
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			break
		n = n.get_parent()
	if n == null:
		return null
	var inv := n.get_node_or_null("Inventory")
	if inv != null and inv.has_method("active_lamp"):
		return inv.call("active_lamp")
	return null

func _player_has_lamp(by: Node) -> bool:
	if by == null:
		return false
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			break
		n = n.get_parent()
	if n == null:
		return false
	var inv := n.get_node_or_null("Inventory")
	if inv != null and inv.has_method("find_lamp"):
		return inv.call("find_lamp") != null
	return false

func _refresh_prompt_for_player() -> void:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	var target := _resolve_player_lamp(player)
	_update_prompt_for_state(target, target == null and _player_has_lamp(player))

func _play_refill_feedback(by: Node) -> void:
	if by == null:
		return
	var n: Node = by
	while n != null:
		if n.is_in_group("player"):
			break
		n = n.get_parent()
	if n != null and n.has_method("play_feedback_sfx"):
		n.call("play_feedback_sfx", "refill")

func _update_prompt_for_state(target: Object, has_unselected_lamp: bool = false) -> void:
	if _interactable == null:
		return
	if oil_amount <= 0.0:
		_interactable.prompt_text = prompt_empty
		return
	if has_unselected_lamp and target == null:
		_interactable.prompt_text = prompt_lamp_not_selected
		return
	if target == null:
		_interactable.prompt_text = prompt_no_lamp
		return
	var current_oil = target.get("oil_level")
	var max_oil = target.get("oil_max")
	if current_oil != null and max_oil != null and float(current_oil) >= float(max_oil) - 0.01:
		_interactable.prompt_text = prompt_full
	else:
		_interactable.prompt_text = prompt_text
