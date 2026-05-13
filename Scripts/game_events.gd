extends Node

signal player_failed(reason: String)
signal player_succeeded(ending_id: String)

func fail(reason: String) -> void:
	player_failed.emit(reason)

func succeed(ending_id: String) -> void:
	player_succeeded.emit(ending_id)
