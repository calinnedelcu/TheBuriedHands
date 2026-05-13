extends Node

signal objective_changed(id: String, text: String)
signal objective_completed(id: String)

var _current_id: String = ""
var _current_text: String = ""

func set_objective(id: String, text: String) -> void:
	if _current_id == id:
		return
	_current_id = id
	_current_text = text
	objective_changed.emit(id, text)

func complete_objective(id: String) -> void:
	if id != "" and id != _current_id:
		return
	var completed_id := _current_id
	objective_completed.emit(completed_id)
	_current_id = ""
	_current_text = ""
	objective_changed.emit("", "")

func current_id() -> String:
	return _current_id

func current_text() -> String:
	return _current_text
