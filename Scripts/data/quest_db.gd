class_name QuestDB
extends RefCounted
## The main quest as an ordered list of steps. Gameplay nodes refer to steps by
## id ("this pickup completes `fetch_slip`"); the order and the objective text
## live only here. `checkpoint` steps save the game when they start; a
## `solo_text` replaces the objective when playing alone.

const STEPS := [
	# Act I — the workshop
	{"id": &"talk_apprentice", "text": "OBJ_TALK_APPRENTICE"},
	{"id": &"take_lamp", "text": "OBJ_TAKE_LAMP", "hint": "HINT_LAMP"},
	{"id": &"fetch_slip", "text": "OBJ_FETCH_SLIP"},
	{"id": &"place_bowl", "text": "OBJ_PLACE_BOWL"},
	{"id": &"apply_slip", "text": "OBJ_APPLY_SLIP", "hint": "HINT_HOLD"},
	{"id": &"find_chisel", "text": "OBJ_FIND_CHISEL", "hint": "HINT_CROUCH"},
	{"id": &"finish_statue", "text": "OBJ_FINISH_STATUE"},
	{"id": &"sealing", "text": "", "hint": "HINT_HIDE"},
	{"id": &"answer_apprentice", "text": "OBJ_ANSWER_APPRENTICE", "checkpoint": true},
	# Act II — the archives
	{"id": &"find_liang", "text": "OBJ_FIND_LIANG", "hint": "HINT_STEALTH", "checkpoint": true},
	{"id": &"talk_liang", "text": "OBJ_TALK_LIANG", "checkpoint": true},
	# Act III — under the mountain: the workers' shaft and the army pits
	{"id": &"reach_mechanism", "text": "OBJ_REACH_MECHANISM", "solo_text": "OBJ_REACH_MECHANISM_SOLO", "checkpoint": true},
	# Act IV — the counterweight
	{"id": &"inspect_balance", "text": "OBJ_INSPECT_BALANCE", "checkpoint": true},
	{"id": &"get_vase", "text": "OBJ_GET_VASE"},
	{"id": &"fill_vase", "text": "OBJ_FILL_VASE", "hint": "HINT_BREATH"},
	{"id": &"pour_mercury", "text": "OBJ_POUR_MERCURY", "checkpoint": true},
	# Act V — escape
	{"id": &"find_drain", "text": "OBJ_FIND_DRAIN", "checkpoint": true},
	{"id": &"crawl_out", "text": "OBJ_CRAWL_OUT", "hint": "HINT_CRAWL"},
	{"id": &"escape", "text": ""},
]

static func index_of(step_id: StringName) -> int:
	for i in STEPS.size():
		if STEPS[i]["id"] == step_id:
			return i
	return -1

static func step(index: int) -> Dictionary:
	return STEPS[index] if index >= 0 and index < STEPS.size() else {}
