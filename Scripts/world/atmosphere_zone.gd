@tool
class_name AtmosphereZone
extends Area3D
## A region with its own air: fog colour and density, ambient light and colour
## saturation. The level's Atmosphere blends toward the zone the player stands
## in (the highest `zone_priority` wins where zones overlap).

@export var zone_priority := 0
@export var fog_color := Color(0.012, 0.014, 0.02)
@export var fog_density := 0.01
@export var volumetric_density := 0.008
@export var volumetric_albedo := Color(0.85, 0.82, 0.78)
@export var volumetric_emission := Color(0.0, 0.0, 0.0)
@export var volumetric_emission_energy := 0.0
@export var ambient_color := Color(0.035, 0.04, 0.055)
@export var ambient_energy := 1.0
@export var saturation := 0.92
@export var exposure := 1.0

@export_group("Sound")
## Music track while inside (see Music.TRACKS); empty keeps what is playing,
## &"silence" fades the music out.
@export var music: StringName = &""
## Once this Game flag is set the zone's music no longer plays.
@export var music_until_flag: StringName = &""
## Ambience bed (see Music.AMBIENCE); empty means the tomb's own.
@export var ambience: StringName = &""

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	add_to_group(&"atmosphere_zones")

func music_track() -> StringName:
	if music_until_flag != &"" and Game.get_flag(music_until_flag):
		return &"silence"
	return music

func profile() -> Dictionary:
	return {
		"fog_color": fog_color,
		"fog_density": fog_density,
		"volumetric_density": volumetric_density,
		"volumetric_albedo": volumetric_albedo,
		"volumetric_emission": volumetric_emission,
		"volumetric_emission_energy": volumetric_emission_energy,
		"ambient_color": ambient_color,
		"ambient_energy": ambient_energy,
		"saturation": saturation,
		"exposure": exposure,
	}
