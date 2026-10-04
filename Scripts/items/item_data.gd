class_name ItemData
extends Resource
## Static description of an item type. One .tres per item in res://data/items.

@export var id: StringName
@export var name_key := ""
@export var description_key := ""
@export var icon: Texture2D
## Visual used for world pickups, drops and thrown copies.
@export var world_scene: PackedScene
## Visual held in the right hand (falls back to world_scene).
@export var hand_scene: PackedScene
@export var hand_transform := Transform3D.IDENTITY
@export var max_stack := 1
## Key items (cloth, register) are carried without taking a hand slot.
@export var key_item := false
@export var droppable := true
@export var throwable := false
## How far guards hear it land (metres).
@export var throw_noise_radius := 16.0
@export var mass := 0.5
@export var pickup_sound: AudioStream
@export var impact_sounds: Array[AudioStream] = []

func display_name() -> String:
	return TranslationServer.translate(name_key)
