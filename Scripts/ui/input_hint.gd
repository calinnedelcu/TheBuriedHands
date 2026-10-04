class_name InputHint
extends RefCounted
## Replaces {action_name} placeholders in translated text with the key
## currently bound to that action, e.g. "{interact} folosește" -> "E folosește".

static func format(text: String) -> String:
	if not "{" in text:
		return text
	var out := text
	var regex := RegEx.create_from_string("\\{([a-z_0-9]+)\\}")
	for m in regex.search_all(text):
		var action := StringName(m.get_string(1))
		if InputMap.has_action(action):
			out = out.replace(m.get_string(0), "[%s]" % Settings.binding_label(action))
	return out
