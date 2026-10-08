class_name DialogueDB
extends RefCounted
## Every scripted line in the game. Entries are [speaker_id, text_key] or
## [speaker_id, text_key, extras]; the text itself lives in
## localization/strings.csv. Extras are forwarded to listeners (e.g. an NPC
## animation for that line: {"anim": &"..."}); {"only": &"solo"} or
## {"only": &"coop"} keeps a line to that kind of game, {"if": &"flag"} or
## {"unless": &"flag"} to a story that went one way or the other.

const SPEAKERS := {
	&"craftsman": "SPK_CRAFTSMAN",
	&"apprentice": "SPK_APPRENTICE",
	&"liang": "SPK_LIANG",
	&"guard_a": "SPK_GUARD_CAPTAIN",
	&"guard_b": "SPK_GUARD",
	&"guard": "SPK_GUARD",
	&"wei": "SPK_WEI",
}

const SEQUENCES := {
	# --- Act I: the workshop -------------------------------------------------
	&"intro": [
		[&"craftsman", "DLG_INTRO_1"],
		[&"craftsman", "DLG_INTRO_2"],
	],
	&"apprentice_task": [
		[&"apprentice", "DLG_APPR_1", {"anim": &"talk"}],
		[&"craftsman", "DLG_APPR_2"],
		[&"apprentice", "DLG_APPR_3", {"anim": &"point"}],
	],
	&"lamp_taken": [
		[&"craftsman", "DLG_LAMP_TAKEN"],
	],
	&"bowl_taken": [
		[&"craftsman", "DLG_BOWL_TAKEN"],
	],
	&"slip_applied": [
		[&"craftsman", "DLG_SLIP_APPLIED_1"],
		[&"craftsman", "DLG_SLIP_APPLIED_2"],
	],
	&"chisel_found": [
		[&"craftsman", "DLG_CHISEL_FOUND"],
	],
	&"statue_done": [
		[&"craftsman", "DLG_STATUE_DONE"],
	],
	&"sealing_first": [
		[&"apprentice", "DLG_SEAL1_1"],
		[&"craftsman", "DLG_SEAL1_2"],
		[&"craftsman", "DLG_SEAL1_3"],
	],
	&"guards_talk": [
		[&"guard_a", "DLG_GUARDS_1"],
		[&"guard_b", "DLG_GUARDS_2"],
		[&"guard_a", "DLG_GUARDS_3"],
		[&"guard_b", "DLG_GUARDS_4"],
		[&"guard_a", "DLG_GUARDS_5"],
		[&"guard_b", "DLG_GUARDS_6"],
	],
	&"guards_aftermath": [
		[&"craftsman", "DLG_AFTER_1"],
		[&"craftsman", "DLG_AFTER_2"],
	],
	&"apprentice_plea": [
		[&"apprentice", "DLG_PLEA_1", {"anim": &"scared"}],
	],
	&"apprentice_gave_lamp": [
		[&"apprentice", "DLG_GAVE_1", {"anim": &"scared"}],
		[&"craftsman", "DLG_GAVE_2"],
	],
	&"apprentice_kept_lamp": [
		# He bows to his master all the same.
		[&"apprentice", "DLG_KEPT_1", {"anim": &"bow"}],
	],
	# Alone: on his way out, Wei's men take the apprentice (ApprenticeTaken).
	&"taken_warning": [
		[&"craftsman", "DLG_TAKEN_1"],
	],
	&"taken_list": [
		[&"wei", "DLG_TAKEN_2"],
		[&"guard_b", "DLG_TAKEN_3"],
	],
	&"taken_plea": [
		[&"apprentice", "DLG_TAKEN_4", {"anim": &"scared"}],
		[&"wei", "DLG_TAKEN_5"],
	],
	&"taken_after": [
		[&"craftsman", "DLG_TAKEN_6"],
	],
	# Co-op: the apprentice is the second player, and he comes along.
	&"coop_together": [
		[&"apprentice", "DLG_TOGETHER_1"],
		[&"craftsman", "DLG_TOGETHER_2"],
	],
	# --- Act II: the archives and Liang ---------------------------------------
	# Out of the workshop into the great corridor and its traps; at its west
	# end, the door to the Mercury Hall, nailed shut.
	&"corridor_enter": [
		[&"craftsman", "DLG_CORRIDOR_ENTER"],
	],
	&"barred_door": [
		[&"craftsman", "DLG_BARRED_DOOR"],
	],
	# Wei at his desk at the far end of the archives, his half of the tally.
	&"wei_seen": [
		[&"craftsman", "DLG_WEI_SEEN"],
	],
	&"tally_wei_taken": [
		[&"craftsman", "DLG_TALLY_WEI_TAKEN"],
	],
	&"archives_enter": [
		[&"craftsman", "DLG_ARCHIVES_ENTER"],
	],
	&"evidence_found": [
		[&"craftsman", "DLG_EVIDENCE_1"],
		[&"craftsman", "DLG_EVIDENCE_2"],
	],
	&"liang_talk": [
		[&"liang", "DLG_LIANG_1", {"anim": &"surprised"}],
		[&"craftsman", "DLG_LIANG_2"],
		[&"liang", "DLG_LIANG_3", {"anim": &"talk"}],
		[&"craftsman", "DLG_LIANG_4"],
		[&"liang", "DLG_LIANG_5", {"anim": &"talk"}],
		[&"liang", "DLG_LIANG_6", {"anim": &"talk"}],
		[&"liang", "DLG_LIANG_7", {"anim": &"talk"}],
		[&"craftsman", "DLG_LIANG_8"],
		[&"liang", "DLG_LIANG_9", {"anim": &"frustrated"}],
		# The tunnel to the mechanism came down with the gate: the way on is
		# the workers' shaft, through the army pits.
		[&"liang", "DLG_LIANG_10", {"anim": &"talk"}],
		[&"liang", "DLG_LIANG_ROUTE", {"anim": &"talk"}],
		# The stairs come up through the inner wall, whose gate wants a whole
		# tiger tally: Wei's half (taken already, or on his desk) and the
		# commander of the pits' half.
		[&"liang", "DLG_LIANG_TALLY_1", {"anim": &"talk"}],
		[&"craftsman", "DLG_LIANG_TALLY_HAVE_1", {"if": &"has_tally_wei"}],
		[&"liang", "DLG_LIANG_TALLY_HAVE_2", {"anim": &"talk", "if": &"has_tally_wei"}],
		[&"liang", "DLG_LIANG_TALLY_GET", {"anim": &"talk", "unless": &"has_tally_wei"}],
		[&"liang", "DLG_LIANG_11", {"anim": &"talk"}],
		# Alone, the craftsman tells what he saw (or learns) of his apprentice
		# and where Wei's men took him; together, the two of them hear of the
		# lift that needs both their weights.
		[&"craftsman", "DLG_LIANG_TAKEN_1", {"only": &"solo", "if": &"saw_apprentice_taken"}],
		[&"liang", "DLG_LIANG_TAKEN_2", {"anim": &"talk", "only": &"solo", "if": &"saw_apprentice_taken"}],
		[&"liang", "DLG_LIANG_PITS_1", {"anim": &"talk", "only": &"solo", "unless": &"saw_apprentice_taken"}],
		[&"craftsman", "DLG_LIANG_PITS_2", {"only": &"solo", "unless": &"saw_apprentice_taken"}],
		[&"liang", "DLG_LIANG_PITS_3", {"anim": &"talk", "only": &"solo"}],
		[&"liang", "DLG_LIANG_PITS_COOP", {"anim": &"talk", "only": &"coop"}],
		[&"craftsman", "DLG_LIANG_12"],
		[&"liang", "DLG_LIANG_13", {"anim": &"sit"}],
	],
	# --- Act III: under the mountain ------------------------------------------
	&"stone_broken": [
		[&"craftsman", "DLG_STONE_BROKEN"],
	],
	&"tunnels_enter": [
		[&"craftsman", "DLG_TUNNELS_ENTER"],
	],
	&"tunnel_fallen": [
		[&"craftsman", "DLG_TUNNEL_FALLEN"],
	],
	&"pits_enter": [
		[&"craftsman", "DLG_PITS_ENTER_1"],
		[&"craftsman", "DLG_PITS_ENTER_2"],
	],
	&"tally_pit_taken": [
		[&"craftsman", "DLG_TALLY_PIT_TAKEN"],
	],
	&"tally_gate_half": [
		[&"craftsman", "DLG_TALLY_GATE_HALF"],
	],
	&"tally_gate_open": [
		[&"craftsman", "DLG_TALLY_GATE_OPEN"],
	],
	&"apprentice_freed": [
		[&"apprentice", "DLG_FREED_1"],
		[&"craftsman", "DLG_FREED_2"],
	],
	# --- Act IV: mechanism chamber and the Mercury Hall -----------------------
	&"mechanism_enter": [
		[&"craftsman", "DLG_MECH_ENTER"],
	],
	&"balance_inspect": [
		[&"craftsman", "DLG_BALANCE_1"],
		[&"craftsman", "DLG_BALANCE_2"],
	],
	&"mercury_enter": [
		[&"craftsman", "DLG_MERCURY_ENTER_1"],
		[&"craftsman", "DLG_MERCURY_ENTER_2"],
	],
	&"vase_filled": [
		[&"craftsman", "DLG_VASE_FILLED"],
	],
	&"poured": [
		[&"craftsman", "DLG_POURED_1"],
		[&"craftsman", "DLG_POURED_2"],
	],
	&"sealing_second": [
		[&"craftsman", "DLG_SEAL2"],
	],
	# --- Act V: treasury and escape ------------------------------------------
	&"treasury_enter": [
		[&"craftsman", "DLG_TREASURY_1"],
		[&"craftsman", "DLG_TREASURY_2"],
	],
	&"coffin": [
		[&"craftsman", "DLG_COFFIN_1"],
		[&"craftsman", "DLG_COFFIN_2"],
	],
	&"drain_found": [
		[&"craftsman", "DLG_DRAIN_FOUND"],
	],
	&"collapse": [
		[&"craftsman", "DLG_COLLAPSE_1"],
		[&"craftsman", "DLG_COLLAPSE_2"],
	],
	&"light": [
		[&"craftsman", "DLG_LIGHT"],
	],
}

## Short reactive lines guards shout; one is picked at random per situation.
const GUARD_BARKS := {
	&"suspicious": ["BARK_SUSPICIOUS_1", "BARK_SUSPICIOUS_2", "BARK_SUSPICIOUS_3"],
	&"investigate": ["BARK_INVESTIGATE_1", "BARK_INVESTIGATE_2"],
	&"spotted": ["BARK_SPOTTED_1", "BARK_SPOTTED_2", "BARK_SPOTTED_3"],
	&"lost": ["BARK_LOST_1", "BARK_LOST_2"],
	&"calm": ["BARK_CALM_1", "BARK_CALM_2"],
	&"noise": ["BARK_NOISE_1", "BARK_NOISE_2"],
}

static func sequence(id: StringName) -> Array:
	return SEQUENCES.get(id, [])

static func speaker_name(speaker_id: StringName) -> String:
	var key: String = SPEAKERS.get(speaker_id, "")
	return TranslationServer.translate(key) if key != "" else ""

static func random_bark(kind: StringName) -> String:
	var options: Array = GUARD_BARKS.get(kind, [])
	return options.pick_random() if not options.is_empty() else ""
