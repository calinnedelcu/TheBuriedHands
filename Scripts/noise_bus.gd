extends Node

signal noise_emitted(position: Vector3, loudness: float, source: Node)

func emit_noise(position: Vector3, loudness: float, source: Node = null) -> void:
	noise_emitted.emit(position, loudness, source)
