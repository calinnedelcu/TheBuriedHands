class_name TalkingWorker
extends Worker
## A craftsman at work (or, after the sealing, in despair) who can be talked
## to: what he says is MasonsSong's to decide (old Bai the mason, the man
## who watched Bai's son die in the corridor).

@export var talker: StringName = &"bai"

var _talk: DelegateUsable

func _ready() -> void:
	super._ready()
	var body := get_node_or_null(^"Body") as CollisionObject3D
	if body == null:
		return
	# The dead lie with their colliders off: a word with the living only.
	if dead:
		return
	_talk = DelegateUsable.new()
	_talk.name = "Talk"
	_talk.prompt_key = "PROMPT_TALK"
	_talk.delegate_path = ^"../.."
	_talk.highlight = false
	body.add_child(_talk)

func usable_prompt(_user: Node) -> String:
	return tr("PROMPT_TALK") if MasonsSong.can_talk(talker) else ""

func usable_can_use(_user: Node) -> bool:
	return MasonsSong.can_talk(talker) and not Dialogue.is_busy()

func usable_use(user: Node) -> void:
	MasonsSong.talk(talker, self, user)
