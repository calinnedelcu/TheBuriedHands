class_name Story
extends RefCounted
## Shared "something happened" hook used by pickups, triggers and stations:
## set a flag, play a line or sequence, and move the main quest along.

static func fire(completes_step: StringName = &"", dialogue: StringName = &"", flag: StringName = &"") -> void:
	if flag != &"":
		Game.set_flag(flag)
	if dialogue != &"":
		Dialogue.play(dialogue)
	if completes_step != &"":
		Quest.complete(completes_step)
