extends Node3D

const OilReservoirScript = preload("res://Scripts/oil_reservoir.gd")
const InteractableScript = preload("res://Scripts/interactable.gd")
const StaticLampLoopAudioScript = preload("res://Scripts/static_lamp_loop_audio.gd")
const DefaultWallLampFireStream = preload("res://audio/sfx/lamp/wall_lamp_fire.mp3")

@export var light_energy: float = 4.5:
	set(v):
		light_energy = v
		_update_all_lights()
@export var light_range: float = 12.0:
	set(v):
		light_range = v
		_update_all_lights()
@export var light_color: Color = Color(1, 0.6, 0.26, 1):
	set(v):
		light_color = v
		_update_all_lights()
@export var volumetric_fog_energy: float = 1.0:
	set(v):
		volumetric_fog_energy = v
		_update_all_lights()
@export var name_filter: String = "tripo_node_e3fb4dc2"
@export_group("Oil Reservoir")
## Daca true, ataseaza un OilReservoir + Interactable la fiecare lampa.
@export var add_oil_reservoir: bool = true
@export var reservoir_oil_amount: float = 400.0
## Procent minim/maxim din `reservoir_oil_amount` cu care fiecare lampa porneste.
## 1.0 = 100%. Diferenta dintre min si max → variatie aleatoare per instanta.
@export_range(0.0, 1.0, 0.05) var reservoir_initial_oil_min_pct: float = 0.5
@export_range(0.0, 1.0, 0.05) var reservoir_initial_oil_max_pct: float = 1.0
@export var reservoir_idle_drain: float = 0.2
@export var reservoir_refill_per_second: float = 8.0
@export var reservoir_collider_extents: Vector3 = Vector3(0.35, 0.35, 0.35)
@export_group("Loop Audio")
@export var add_fire_loop_audio: bool = true
@export var fire_loop_stream: AudioStream = DefaultWallLampFireStream
@export var fire_loop_volume_db: float = -12.0
@export var fire_loop_unit_size: float = 6.0
@export var fire_loop_max_distance: float = 18.0
@export var fire_loop_max_db: float = -4.0
@export_range(0.0, 1.0, 0.05) var fire_loop_panning_strength: float = 0.65

var _scanned := false

func _ready() -> void:
	_scan_and_add_lights(self)

func _process(_delta: float) -> void:
	if _scanned:
		set_process(false)
		return
	_scanned = true
	_scan_and_add_lights(self)

func _scan_and_add_lights(node: Node) -> void:
	for child in node.get_children():
		var child_name: String = child.name.to_lower()
		var filters := name_filter.to_lower().split(",", false)
		var matches := false
		for f in filters:
			if f.strip_edges() in child_name:
				matches = true
				break
		if child is Node3D and matches and not "_col" in child_name and not "collision" in child_name:
			_add_light_to(child as Node3D)
		_scan_and_add_lights(child)

func _add_light_to(target: Node3D) -> void:
	var existing := target.get_node_or_null("AddedLight")
	if existing == null:
		var light := OmniLight3D.new()
		light.name = "AddedLight"
		light.light_color = light_color
		light.light_energy = light_energy
		light.light_volumetric_fog_energy = volumetric_fog_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.2
		light.light_size = 0.5
		light.shadow_enabled = false
		light.position = Vector3(0, 0.4, 0)
		target.add_child(light)
		if Engine.is_editor_hint():
			light.owner = target.owner
	if add_fire_loop_audio:
		_add_fire_loop_audio_to(target)
	if add_oil_reservoir:
		_add_reservoir_to(target)

func _add_fire_loop_audio_to(target: Node3D) -> void:
	if fire_loop_stream == null or target.get_node_or_null("LampFireSFX") != null:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.name = "LampFireSFX"
	audio.set_script(StaticLampLoopAudioScript)
	audio.set("light_path", NodePath("../AddedLight"))
	audio.set("active_volume_db", fire_loop_volume_db)
	audio.stream = fire_loop_stream
	audio.volume_db = fire_loop_volume_db
	audio.unit_size = fire_loop_unit_size
	audio.max_db = fire_loop_max_db
	audio.max_distance = fire_loop_max_distance
	audio.panning_strength = fire_loop_panning_strength
	audio.bus = &"SFX"
	audio.autoplay = true
	audio.position = Vector3(0, 0.4, 0)
	target.add_child(audio)
	if Engine.is_editor_hint():
		audio.owner = target.owner

func _add_reservoir_to(target: Node3D) -> void:
	if target.get_node_or_null("OilReservoir") != null:
		return
	# Construim intreg subarborele OFF-TREE, configuram exports, apoi atasam.
	# In felul asta @onready din oil_reservoir.gd va gasi copii + light path.
	var reservoir := Node3D.new()
	reservoir.name = "OilReservoir"
	reservoir.set_script(OilReservoirScript)
	reservoir.position = Vector3(0, 0.4, 0)
	var lo: float = min(reservoir_initial_oil_min_pct, reservoir_initial_oil_max_pct)
	var hi: float = max(reservoir_initial_oil_min_pct, reservoir_initial_oil_max_pct)
	var pct: float = randf_range(lo, hi) if not Engine.is_editor_hint() else hi
	reservoir.set("oil_amount", reservoir_oil_amount * pct)
	reservoir.set("oil_max", reservoir_oil_amount)
	reservoir.set("idle_drain_rate", reservoir_idle_drain)
	reservoir.set("refill_per_second", reservoir_refill_per_second)
	reservoir.set("light_path", NodePath("../AddedLight"))

	var body := StaticBody3D.new()
	body.name = "InteractBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.name = "InteractCollider"
	var box := BoxShape3D.new()
	box.size = reservoir_collider_extents * 2.0
	col.shape = box
	body.add_child(col)
	reservoir.add_child(body)

	var inter := Node.new()
	inter.name = "Interactable"
	inter.set_script(InteractableScript)
	inter.set("hold_action", true)
	inter.set("prompt_text", "Toarnă ulei în lampă")
	reservoir.add_child(inter)

	# Acum atasam reservoir-ul complet la target → _ready fires cu toate gata.
	target.add_child(reservoir)
	if Engine.is_editor_hint():
		var o := target.owner
		reservoir.owner = o
		body.owner = o
		col.owner = o
		inter.owner = o

func _update_all_lights() -> void:
	_update_lights_recursive(self)

func _update_lights_recursive(node: Node) -> void:
	for child in node.get_children():
		var existing := child.get_node_or_null("AddedLight")
		if existing is OmniLight3D:
			existing.light_color = light_color
			existing.light_energy = light_energy
			existing.light_volumetric_fog_energy = volumetric_fog_energy
			existing.omni_range = light_range
		_update_lights_recursive(child)
