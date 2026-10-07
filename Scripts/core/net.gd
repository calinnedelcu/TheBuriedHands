extends Node
## Online co-op for two: whoever hosts plays the master craftsman, whoever
## joins plays his apprentice.
##
## The host runs the world: the story (quest, dialogue, flags, checkpoints),
## the guards and the traps, and its word is final. Each player runs their
## own body (movement, breath, health) and tells the other where it is.
## Using something goes through the host, so two hands never take the same
## chisel: the host checks the use, then both machines run it, each with its
## own copy of the user's body, so doors swing, sounds play and inventories
## fill on both sides. Every few seconds the host also sends the whole state
## of the world, and the apprentice's machine quietly mends what drifted.
##
## Bodies: the level's "Player" is the master; in a session the level adds
## an "Apprentice" (the same player scene) where the apprentice stood.
## Single-player never touches any of this: `active` stays false.

signal status_changed(text: String)
signal partner_changed(connected: bool)
## Both machines are about to load the level (the menu gets out of the way).
signal starting

const PORT := 7735
## Bump whenever the messages below change: different versions don't mix.
const PROTOCOL := 1
const MASTER_BODY := &"Player"
const APPRENTICE_BODY := &"Apprentice"
const BODY_RATE := 20.0
const GUARD_RATE := 12.0
const WORLD_SYNC_SECONDS := 4.0
const CONNECT_TIMEOUT := 12.0
## How long the host waits for the apprentice's level before going on alone.
const LEVEL_WAIT := 60.0
## How long the partner may go without answering while a level loads. The
## frame the level enters the tree stops the game for seconds while the
## physics builds the level's colliders (up to 13 s with two games on one
## Mac), and ENet on its own drops a peer that stays silent for 5.
const LOAD_TIMEOUT := 60.0
## Once both machines have the level, ENet's own timeout comes back after
## this long (a new level's first frames can be slow too).
const LOAD_SETTLE := 10.0
## Methods the host may run on a player's own machine (see `to_owner`).
const OWNER_CALLS := [&"look_at_point", &"add_shake", &"hurt", &"kill", &"walk_to", &"stop_walking",
	&"force_stand", &"lock_controls", &"unlock_controls", &"reset_fov", &"push", &"notice"]

enum Phase { OFF, HOSTING, JOINING, LOBBY, PLAYING }

## In a session: hosting, or joined.
var active := false
var is_host := false
## True while the apprentice's machine runs what the host sent: story calls
## (quest, flags, dialogue) are let through then, and only then.
var applying := false
## True while both machines run the same use, each with its own copy of the
## user: what happens to the user's body is then the business of the user's
## own machine, so the host passes nothing on.
var replaying := false
var partner_id := 0
var phase := Phase.OFF

var _peer: ENetMultiplayerPeer
var _address := ""
var _connect_timer := 0.0
var _body_timer := 0.0
var _guard_timer := 0.0
var _world_timer := 0.0
var _partner_level_ready := false
var _start_state: Dictionary = {}
var _have_start_state := false
## Counts level loads, so a settle that comes too late leaves the next alone.
var _load_serial := 0
var _muted := false
var _mismatch: Dictionary = {}
var _notice_layer: CanvasLayer
var _notice: Label
var _notice_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_add_ping_action()
	_build_notice()

# --- Session ----------------------------------------------------------------------

## Opens the game for an apprentice to join. Returns false if the port is taken.
func host() -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, 1)
	if err != OK:
		_peer = null
		status_changed.emit(tr("COOP_HOST_FAILED") % PORT)
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	phase = Phase.HOSTING
	status_changed.emit(tr("COOP_WAITING") % [", ".join(local_addresses()), PORT])
	return true

func join(address: String) -> bool:
	leave()
	_address = address.strip_edges()
	if _address == "":
		_address = "127.0.0.1"
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(_address, PORT)
	if err != OK:
		_peer = null
		status_changed.emit(tr("COOP_JOIN_FAILED") % _address)
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	phase = Phase.JOINING
	_connect_timer = CONNECT_TIMEOUT
	status_changed.emit(tr("COOP_CONNECTING") % _address)
	return true

## Closes the session (the partner hears about it from ENet).
func leave() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	applying = false
	replaying = false
	partner_id = 0
	phase = Phase.OFF
	_partner_level_ready = false
	_have_start_state = false
	_mismatch.clear()

## The host starts the descent: both machines begin a new game.
func begin() -> void:
	if not is_host or partner_id == 0:
		return
	_begin.rpc_id(partner_id)
	_start_game()

func has_partner() -> bool:
	return active and partner_id != 0

## True on the apprentice's machine in a session.
func is_client() -> bool:
	return active and not is_host

## Whether story state (quest, flags, dialogue, checkpoints) may change on
## this machine: always alone, on the host, and on the apprentice's machine
## only while it applies what the host sent.
func story_allowed() -> bool:
	return not active or is_host or applying

## Whether the host should tell the apprentice's machine about a change.
func should_send() -> bool:
	return active and is_host and partner_id != 0 and not _muted and phase == Phase.PLAYING

func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) in range(16, 32)) or a.begins_with("100."):
			out.append(a)
	if out.is_empty():
		out.append("127.0.0.1")
	return out

# --- Bodies -------------------------------------------------------------------------

func local_body_name() -> StringName:
	return APPRENTICE_BODY if is_client() else MASTER_BODY

func is_local_body(body: Node) -> bool:
	return not active or body.name == local_body_name()

func body(body_name: StringName) -> Player:
	if Game.level == null:
		return null
	return Game.level.get_node_or_null(NodePath(String(body_name))) as Player

func local_body() -> Player:
	return body(local_body_name())

## The other player's body, or null alone.
func partner_body() -> Player:
	if not active:
		return null
	return body(MASTER_BODY if is_client() else APPRENTICE_BODY)

## Every player body in the level: one alone, two in a session.
func players() -> Array[Player]:
	var out: Array[Player] = []
	for n in get_tree().get_nodes_in_group(&"players"):
		if n is Player and n.is_inside_tree():
			out.append(n as Player)
	return out

## Called by Level._ready: in a session the apprentice takes the place of the
## apprentice who stood at his bench (who is otherwise a character), and the
## co-op director joins the level.
func setup_level(level: Node) -> void:
	if not active:
		return
	var npc := level.get_node_or_null("Rooms/01_TerracottaWorkshop/Apprentice") as Node3D
	var at := Transform3D(Basis(), Vector3.ZERO)
	var master := level.get_node_or_null(NodePath(String(MASTER_BODY))) as Node3D
	if npc != null:
		at = npc.global_transform
		npc.get_parent().remove_child(npc)
		npc.queue_free()
	elif master != null:
		at = master.global_transform.translated_local(Vector3(1.5, 0, 0))
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var apprentice := scene.instantiate() as Player
	apprentice.name = APPRENTICE_BODY
	level.add_child(apprentice)
	# The bench figure's model faces its +x; the player looks down -z.
	apprentice.global_position = at.origin
	apprentice.rotation.y = at.basis.get_euler().y - PI * 0.5
	var director := CoopDirector.new()
	director.name = "CoopDirector"
	level.add_child(director)

# --- Level start --------------------------------------------------------------------

## Game.register_level waits on this in a session: the host for the
## apprentice to have the level loaded, the apprentice for the world as the
## host has it (applied before returning).
func prepare_level() -> void:
	if not active:
		return
	phase = Phase.PLAYING
	if is_host:
		var waited := 0.0
		if partner_id != 0 and not _partner_level_ready:
			show_notice(tr("COOP_WAIT_PARTNER"), 60.0)
		while active and partner_id != 0 and not _partner_level_ready and waited < LEVEL_WAIT:
			await get_tree().process_frame
			waited += get_process_delta_time()
		hide_notice()
		# The host's own start (snapshot, first step) is sent whole afterwards.
		_muted = true
	else:
		_have_start_state = false
		_level_loaded.rpc_id(1)
		while active and not _have_start_state:
			await get_tree().process_frame
		if active:
			applying = true
			Game.apply_partner_state(_start_state)
			applying = false
			_loaded()

## The host has set up its world: the apprentice gets all of it at once.
func level_started() -> void:
	if not is_host:
		return
	_muted = false
	_partner_level_ready = false
	if partner_id != 0:
		_start_world.rpc_id(partner_id, Game.partner_state())
		_loaded()

## The host reloads the level after a death: the apprentice follows.
func reload_together() -> void:
	if is_host and partner_id != 0:
		_loading()
		_reload.rpc_id(partner_id)

func _start_game() -> void:
	phase = Phase.PLAYING
	_partner_level_ready = false
	_have_start_state = false
	_loading()
	starting.emit()
	Game.new_game()

## A level is about to load on both machines: each may stop answering for as
## long as its loading takes (see LOAD_TIMEOUT), so the partner gets that
## long before ENet calls them gone.
func _loading() -> void:
	_load_serial += 1
	_set_partner_timeout(LOAD_TIMEOUT, LOAD_TIMEOUT)

## Both machines have the level: ENet's own timeout (5 s at the least, 30 s
## at the most) once it has run for a while.
func _loaded() -> void:
	var serial := _load_serial
	await get_tree().create_timer(LOAD_SETTLE, true, false, true).timeout
	if serial == _load_serial:
		_set_partner_timeout(5.0, 30.0)

func _set_partner_timeout(least: float, most: float) -> void:
	if _peer == null or partner_id == 0:
		return
	var partner := _peer.get_peer(partner_id)
	if partner != null:
		partner.set_timeout(32, int(least * 1000.0), int(most * 1000.0))

## Co-op: some objectives read differently for the apprentice ("Talk to your
## master" for "Talk to your apprentice"): a key with "_APP" added, if any.
func objective_for(text_key: String) -> String:
	if not is_client() or text_key == "":
		return text_key
	var alt := text_key + "_APP"
	return alt if tr(alt) != alt else text_key

# --- Story replication (host -> apprentice) -------------------------------------------

func send_quest(index: int) -> void:
	if should_send():
		_quest.rpc_id(partner_id, index)

func send_flag(flag: StringName, value: Variant) -> void:
	if should_send():
		_flag.rpc_id(partner_id, flag, value)

func send_chapter(number: int) -> void:
	if should_send():
		_chapter.rpc_id(partner_id, number)

func send_sealing(stage: int) -> void:
	if should_send():
		_sealing.rpc_id(partner_id, stage)

func send_fail(reason_key: String) -> void:
	if should_send():
		_fail.rpc_id(partner_id, reason_key)

## Dialogue as it plays on the host: the apprentice's subtitles keep its pace.
func send_dialogue(kind: StringName, data: Array = []) -> void:
	if should_send():
		_dialogue.rpc_id(partner_id, kind, data)

## Runs `method` (a `net_*` method) on `node` on the apprentice's machine:
## the host-run traps and sequences show their moves there this way.
func mirror(node: Node, method: StringName, args: Array = []) -> void:
	if should_send() and Game.level != null and Game.level.is_ancestor_of(node):
		_mirror.rpc_id(partner_id, Game.level.get_path_to(node), method, args)

## Runs `method` on `player`'s own machine (the host's story turning the
## apprentice's head, a guard's blow landing on him).
func to_owner(player: Player, method: StringName, args: Array = []) -> void:
	if active and is_host and partner_id != 0 and not replaying and player != null and not player.is_local:
		_owner_call.rpc_id(partner_id, player.name, method, args)

# --- Uses -----------------------------------------------------------------------------

## Uses `usable` (`mode`: &"use", &"tap" or &"hold" for a finished hold) for
## `user`. In a session this goes through the host, and both machines run it.
func use(usable: Usable, user: Node, mode: StringName) -> void:
	if not has_partner() or Game.level == null or not Game.level.is_ancestor_of(usable):
		_run_use(usable, user, mode)
		return
	var path := Game.level.get_path_to(usable)
	if is_host:
		_do_use.rpc_id(partner_id, path, user.name, mode)
		_run_use(usable, user, mode)
	else:
		_request_use.rpc_id(1, path, mode)

func _run_use(usable: Usable, user: Node, mode: StringName) -> void:
	replaying = active
	match mode:
		&"tap":
			usable.tap(user)
		&"hold":
			usable.complete_hold(user)
		_:
			usable.use(user)
	replaying = false

## Something the player did with their own inventory (select, drop, throw,
## the lamp): the other machine does it to its copy of them.
func inventory_action(player: Player, action: StringName, args: Array = []) -> void:
	if has_partner() and player.is_local:
		_inventory_action.rpc_id(partner_id, player.name, action, args)

## The whole inventory, after it changed (fixes whatever drifted).
func send_inventory(player: Player) -> void:
	if has_partner() and player.is_local and phase == Phase.PLAYING:
		_inventory_state.rpc_id(partner_id, player.name, player.inventory.persist_save())

## A sound the apprentice made (footsteps, a landing): the host's guards hear it.
func forward_noise(position: Vector3, radius: float) -> void:
	if is_client() and partner_id != 0:
		_noise.rpc_id(1, position, radius)

## A player went down (co-op): with nobody left standing, the run is over.
func player_downed(player: Player) -> void:
	if not is_host:
		return
	for other in players():
		if not other.downed:
			return
	Game.fail(player.down_reason())

func report_death(reason_key: String) -> void:
	if is_client() and partner_id != 0:
		_died.rpc_id(1, reason_key)

func request_skip_line() -> void:
	if is_client() and partner_id != 0:
		_skip_line.rpc_id(1)

## Points something out to the partner: a mark where the player looks.
func ping(position: Vector3, on_guard: Node) -> void:
	var path := NodePath()
	if on_guard != null and Game.level != null and Game.level.is_ancestor_of(on_guard):
		path = Game.level.get_path_to(on_guard)
	_show_ping(position, path, local_body_name())
	if has_partner():
		_ping.rpc_id(partner_id, position, path, local_body_name())

# --- Ticks ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if phase == Phase.JOINING:
		_connect_timer -= delta
		if _connect_timer <= 0.0:
			var where := _address
			leave()
			status_changed.emit(tr("COOP_JOIN_FAILED") % where)
		return
	if phase != Phase.PLAYING or partner_id == 0 or Game.level == null:
		return
	_body_timer -= delta
	if _body_timer <= 0.0:
		_body_timer = 1.0 / BODY_RATE
		var me := local_body()
		if me != null and me.is_node_ready():
			_body_state.rpc_id(partner_id, me.name, me.net_state())
	if not is_host or _muted:
		return
	_guard_timer -= delta
	if _guard_timer <= 0.0:
		_guard_timer = 1.0 / GUARD_RATE
		_send_guards()
	_world_timer -= delta
	if _world_timer <= 0.0:
		_world_timer = WORLD_SYNC_SECONDS
		_send_world()

func _send_guards() -> void:
	var data := []
	for g in Stealth.guards():
		if is_instance_valid(g) and g is Guard and Game.level.is_ancestor_of(g):
			data.append([Game.level.get_path_to(g), (g as Guard).net_state()])
	if not data.is_empty():
		_guards.rpc_id(partner_id, data)

## Persistent world nodes that both machines run the same way (not bodies,
## not inventories, not the guards the host sends anyway).
func _world_nodes() -> Dictionary:
	var out := {}
	for n in get_tree().get_nodes_in_group(&"persistent"):
		if n is Player or n is Inventory or n is Guard or n is Npc or not n.has_method(&"persist_save"):
			continue
		if not Game.level.is_ancestor_of(n):
			continue
		out[str(Game.level.get_path_to(n))] = n.call(&"persist_save")
	return out

func _send_world() -> void:
	_world.rpc_id(partner_id, Quest.index(), Game.sealing_stage, Game.encoded_flags(), _world_nodes())

# --- Messages: session ------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	# The host waits for the newcomer's hello before calling them a partner.
	if partner_id != 0 and id != partner_id:
		_peer.disconnect_peer(id)

func _on_peer_disconnected(id: int) -> void:
	if not is_host or id != partner_id:
		return
	partner_id = 0
	partner_changed.emit(false)
	if phase == Phase.PLAYING:
		_end_in_game("COOP_PARTNER_LEFT")
	else:
		phase = Phase.HOSTING
		status_changed.emit(tr("COOP_WAITING") % [", ".join(local_addresses()), PORT])

func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL)

func _on_connection_failed() -> void:
	var where := _address
	leave()
	status_changed.emit(tr("COOP_JOIN_FAILED") % where)

func _on_server_disconnected() -> void:
	var was_playing := phase == Phase.PLAYING
	leave()
	partner_changed.emit(false)
	if was_playing:
		_end_in_game("COOP_LOST_HOST")
	else:
		status_changed.emit(tr("COOP_LOST_HOST"))

func _end_in_game(reason_key: String) -> void:
	# Out in the light already: the ending plays on, alone.
	if Game.is_over() and not Game.is_dead():
		leave()
		return
	leave()
	show_notice(tr(reason_key), 6.0)
	Game.return_to_menu()

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host or (partner_id != 0 and partner_id != id):
		return
	if protocol != PROTOCOL:
		_refused.rpc_id(id, "COOP_VERSION")
		get_tree().create_timer(0.5).timeout.connect(func():
			if _peer != null:
				_peer.disconnect_peer(id))
		return
	partner_id = id
	phase = Phase.LOBBY
	_welcome.rpc_id(id)
	partner_changed.emit(true)
	status_changed.emit(tr("COOP_PARTNER_IN"))

@rpc("authority", "call_remote", "reliable")
func _welcome() -> void:
	partner_id = 1
	phase = Phase.LOBBY
	partner_changed.emit(true)
	status_changed.emit(tr("COOP_JOINED"))

@rpc("authority", "call_remote", "reliable")
func _refused(reason_key: String) -> void:
	leave()
	status_changed.emit(tr(reason_key))

@rpc("authority", "call_remote", "reliable")
func _begin() -> void:
	_start_game()

@rpc("authority", "call_remote", "reliable")
func _reload() -> void:
	phase = Phase.PLAYING
	_have_start_state = false
	_loading()
	Game.reload_with_host()

@rpc("any_peer", "call_remote", "reliable")
func _level_loaded() -> void:
	if is_host and multiplayer.get_remote_sender_id() == partner_id:
		_partner_level_ready = true

@rpc("authority", "call_remote", "reliable")
func _start_world(state: Dictionary) -> void:
	_start_state = state
	_have_start_state = true

# --- Messages: story --------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _quest(index: int) -> void:
	applying = true
	Quest.sync_index(index)
	applying = false

@rpc("authority", "call_remote", "reliable")
func _flag(flag: StringName, value: Variant) -> void:
	applying = true
	Game.set_flag(flag, value)
	applying = false

@rpc("authority", "call_remote", "reliable")
func _chapter(number: int) -> void:
	applying = true
	Game.start_chapter(number)
	applying = false

@rpc("authority", "call_remote", "reliable")
func _sealing(stage: int) -> void:
	applying = true
	Game.advance_sealing(stage)
	applying = false

@rpc("authority", "call_remote", "reliable")
func _fail(reason_key: String) -> void:
	applying = true
	Game.fail(reason_key)
	applying = false

@rpc("authority", "call_remote", "reliable")
func _dialogue(kind: StringName, data: Array) -> void:
	Dialogue.apply_remote(kind, data)

@rpc("authority", "call_remote", "reliable")
func _mirror(path: NodePath, method: StringName, args: Array) -> void:
	if Game.level == null or not String(method).begins_with("net_"):
		return
	var node := Game.level.get_node_or_null(path)
	if node != null and node.has_method(method):
		node.callv(method, args)

@rpc("authority", "call_remote", "reliable")
func _owner_call(body_name: StringName, method: StringName, args: Array) -> void:
	var p := body(body_name)
	if p != null and p.is_local and method in OWNER_CALLS:
		p.callv(method, args)

@rpc("any_peer", "call_remote", "reliable")
func _died(reason_key: String) -> void:
	if is_host and multiplayer.get_remote_sender_id() == partner_id:
		Game.fail(reason_key)

@rpc("any_peer", "call_remote", "reliable")
func _skip_line() -> void:
	if is_host and multiplayer.get_remote_sender_id() == partner_id:
		Dialogue.skip_line()

# --- Messages: uses and bodies ----------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_use(path: NodePath, mode: StringName) -> void:
	if not is_host or multiplayer.get_remote_sender_id() != partner_id or Game.level == null:
		return
	var usable := Game.level.get_node_or_null(path) as Usable
	var user := body(APPRENTICE_BODY)
	if usable == null or user == null or not usable.can_use(user):
		return
	_do_use.rpc_id(partner_id, path, user.name, mode)
	_run_use(usable, user, mode)

@rpc("authority", "call_remote", "reliable")
func _do_use(path: NodePath, user_name: StringName, mode: StringName) -> void:
	if Game.level == null:
		return
	var usable := Game.level.get_node_or_null(path) as Usable
	var user := body(user_name)
	if usable == null or user == null:
		push_warning("Net: no usable at %s for %s" % [path, user_name])
		return
	_run_use(usable, user, mode)

## Which machine owns a body: the host the master, the apprentice himself.
func _sent_by_owner(body_name: StringName) -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return (body_name == MASTER_BODY and sender == 1) or (body_name == APPRENTICE_BODY and sender == partner_id and is_host)

@rpc("any_peer", "call_remote", "reliable")
func _inventory_action(body_name: StringName, action: StringName, args: Array) -> void:
	var p := body(body_name)
	if p != null and not p.is_local and _sent_by_owner(body_name):
		p.inventory.apply_action(action, args)

@rpc("any_peer", "call_remote", "reliable")
func _inventory_state(body_name: StringName, state: Dictionary) -> void:
	var p := body(body_name)
	if p != null and not p.is_local and _sent_by_owner(body_name):
		p.inventory.persist_load(state)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _body_state(body_name: StringName, state: Array) -> void:
	var p := body(body_name)
	if p != null and not p.is_local and _sent_by_owner(body_name):
		p.net_apply(state)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _guards(data: Array) -> void:
	if Game.level == null:
		return
	for entry in data:
		var g := Game.level.get_node_or_null(entry[0]) as Guard
		if g != null:
			g.net_apply(entry[1])

@rpc("any_peer", "call_remote", "reliable")
func _noise(position: Vector3, radius: float) -> void:
	if is_host and multiplayer.get_remote_sender_id() == partner_id:
		Stealth.make_noise(position, radius, body(APPRENTICE_BODY))

@rpc("any_peer", "call_remote", "reliable")
func _ping(position: Vector3, guard_path: NodePath, from_body: StringName) -> void:
	_show_ping(position, guard_path, from_body)

func _show_ping(position: Vector3, guard_path: NodePath, from_body: StringName) -> void:
	if Game.level == null:
		return
	var on: Node3D = null
	if not guard_path.is_empty():
		on = Game.level.get_node_or_null(guard_path) as Node3D
	PingMarker.place(Game.level, position, on, from_body == local_body_name())

# --- World check (host -> apprentice) -------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _world(quest_index: int, sealing: int, flags: Dictionary, nodes: Dictionary) -> void:
	if Game.level == null or phase != Phase.PLAYING:
		return
	applying = true
	# Story state comes over reliably as it changes; this only mends what a
	# lost race left behind, and only once it has stayed wrong for a while.
	if _stays_wrong(&"quest", Quest.index() != quest_index):
		Quest.sync_index(quest_index)
	if _stays_wrong(&"sealing", Game.sealing_stage < sealing):
		Game.advance_sealing(sealing)
	for key in flags:
		var f := StringName(key)
		if _stays_wrong(StringName("flag:" + key), Game.get_flag(f, null) != flags[key]):
			Game.set_flag(f, flags[key])
	applying = false
	for path in nodes:
		var n := Game.level.get_node_or_null(NodePath(path))
		if n == null or not n.has_method(&"persist_save"):
			continue
		var wrong := not _same(n.call(&"persist_save"), nodes[path])
		if _stays_wrong(StringName(path), wrong):
			n.call(&"persist_load", nodes[path])

## True once `wrong` has held for two checks in a row (the first may just be
## a use still on its way).
func _stays_wrong(key: StringName, wrong: bool) -> bool:
	if not wrong:
		_mismatch.erase(key)
		return false
	var count := int(_mismatch.get(key, 0)) + 1
	if count >= 2:
		_mismatch.erase(key)
		return true
	_mismatch[key] = count
	return false

func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.75
	return a == b

# --- Notices ------------------------------------------------------------------------------------

## A short line at the top of the screen (the partner left, waiting...).
func show_notice(text: String, seconds := 5.0) -> void:
	_notice.text = text
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, 0.4)
	_notice_tween.tween_interval(seconds)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 1.0)

func hide_notice() -> void:
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)

func _build_notice() -> void:
	_notice_layer = CanvasLayer.new()
	_notice_layer.layer = 121
	add_child(_notice_layer)
	_notice = Label.new()
	_notice.theme = load("res://assets/ui/theme.tres")
	_notice.theme_type_variation = &"QuoteText"
	_notice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left = -520
	_notice.offset_right = 520
	_notice.offset_top = 70
	_notice.offset_bottom = 130
	_notice.modulate.a = 0.0
	_notice_layer.add_child(_notice)

## "ping" (middle mouse or V) is added here rather than in the project's
## input map, which the options menu doesn't rebind anyway.
func _add_ping_action() -> void:
	if InputMap.has_action(&"ping"):
		return
	InputMap.add_action(&"ping")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	InputMap.action_add_event(&"ping", key)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	InputMap.action_add_event(&"ping", mouse)
