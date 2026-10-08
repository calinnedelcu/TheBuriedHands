extends Logger
## For the dev runners: counts script errors. One ends the function it
## happens in, and a runner would go on from where that was called as if
## nothing had gone wrong. Register it with OS.add_logger().

var count := 0
var first := ""
var _lock := Mutex.new()

func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_lock.lock()
	count += 1
	if first == "":
		first = "%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line]
	_lock.unlock()
