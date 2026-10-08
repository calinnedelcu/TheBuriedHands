class_name NetLink
extends Node
## How two players find each other (Net's helper):
##  - Through the router: when hosting, ask the home router over UPnP to open
##    the game's port to this machine and say what its address on the
##    internet is (on a thread of its own: it can take seconds). The mapping
##    lasts two hours and is renewed while hosting, and given back on leaving.
##  - On the same network: the host calls out every second on a port of its
##    own ("here is a master, this is his code"); someone joining listens,
##    and the hosts he hears show up to be joined with a click, no code.
## The best address the host can be reached at goes into his code
## (CoopCode): the internet one if the router opened the way, else a VPN
## one (Tailscale's 100.x), else his address on the home network.

signal opened(code: String, reach: String)
signal hosts_changed

const BEACON_PORT := 7736
const BEACON_EVERY := 1.0
## A host not heard for this long has gone.
const HOST_TIMEOUT := 4.0
const LEASE := 7200
const RENEW_EVERY := 2700.0
const GAME := "TheBuriedHands"

## Ask the router to open the port (off for the dev runners, which must not
## touch the router of whoever runs them: they pass --upnp to try it).
var use_upnp := true
## Hosts heard on this network: {ip: {"name", "code", "port", "seen"}}.
var hosts: Dictionary = {}
## Whether the host calls out on the network: not once his apprentice is in,
## or others would see a game they can't join.
var calling := true

var _port := 0
var _protocol := 0
var _code := ""
var _beacon: PacketPeerUDP
var _beacon_timer := 0.0
var _listener: PacketPeerUDP
var _thread: Thread
var _mapped := false
var _renew_timer := 0.0
var _upnp: UPNP
## The address the router said we have on the internet, once it has.
var _external := ""
## Threads giving the router its port back, waited for once done.
var _returning: Array[Thread] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dev := false
	for a in OS.get_cmdline_user_args():
		dev = dev or a.begins_with("--runner=")
	use_upnp = not dev or "--upnp" in OS.get_cmdline_user_args()

# --- Hosting ---------------------------------------------------------------------------

## Starts hosting on `port`: the beacon at once, the router asked on the side;
## `opened` comes once the code is known (at once if the router isn't asked).
func open(port: int, protocol: int) -> void:
	close()
	_port = port
	_protocol = protocol
	_code = CoopCode.encode(_best_local(), port)
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_timer = 0.0
	calling = true
	if not use_upnp:
		_announce(_code, "local")
		return
	_thread = Thread.new()
	_thread.start(_map_port.bind(port))

## Stops hosting: the beacon goes quiet and the router gets its port back.
func close() -> void:
	if _beacon != null:
		_beacon.close()
		_beacon = null
	_code = ""
	_finish_thread()
	if _mapped and _upnp != null:
		var upnp := _upnp
		var port := _port
		# Given back on a thread of its own: the router can be slow to answer.
		var t := Thread.new()
		t.start(func() -> void: upnp.delete_port_mapping(port, "UDP"))
		_returning.append(t)
	_mapped = false
	_upnp = null

## On the router's thread: find the gateway, open the port, ask the address.
func _map_port(port: int) -> Dictionary:
	var upnp := UPNP.new()
	var result := {"upnp": upnp, "mapped": false, "external": ""}
	if upnp.discover(2000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS:
		return result
	var gateway := upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		return result
	var err := upnp.add_port_mapping(port, port, "The Buried Hands", "UDP", LEASE)
	if err != UPNP.UPNP_RESULT_SUCCESS:
		# Some routers only take mappings without a lease.
		err = upnp.add_port_mapping(port, port, "The Buried Hands", "UDP", 0)
	result["mapped"] = err == UPNP.UPNP_RESULT_SUCCESS
	result["external"] = upnp.query_external_address()
	return result

func _finish_thread() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null

func _process(delta: float) -> void:
	for t in _returning.duplicate():
		if not t.is_alive():
			t.wait_to_finish()
			_returning.erase(t)
	if _thread != null and _thread.is_started() and not _thread.is_alive():
		var result: Dictionary = _thread.wait_to_finish()
		_thread = null
		if _beacon != null:
			_on_mapped(result)
	if _beacon != null:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0 and calling:
			_beacon_timer = BEACON_EVERY
			_call_out()
		if _mapped:
			_renew_timer -= delta
			if _renew_timer <= 0.0 and _thread == null:
				_renew_timer = RENEW_EVERY
				_thread = Thread.new()
				_thread.start(_map_port.bind(_port))
	if _listener != null:
		_listen()

func _on_mapped(result: Dictionary) -> void:
	_upnp = result.get("upnp")
	var external: String = result.get("external", "")
	_mapped = bool(result.get("mapped", false))
	_renew_timer = RENEW_EVERY
	# Behind a provider's own NAT (a 10.x or 100.64.x "public" address) the
	# router's opening leads nowhere: the internet can't reach us anyway.
	if _mapped and external != "" and CoopCode.address_kind(external) == "public":
		_external = external
		_code = CoopCode.encode(external, _port)
		_announce(_code, "internet")
	else:
		_announce(_code, "local")

func _announce(code: String, reach: String) -> void:
	# A VPN address (Tailscale) beats the home network's when there's no
	# way in from the internet: a friend on the same VPN gets in by it.
	if reach == "local":
		var vpn := _vpn_address()
		if vpn != "":
			code = CoopCode.encode(vpn, _port)
			reach = "vpn"
			_code = code
	opened.emit(code, reach)

## The beacon: "a master is hosting here, this is his code".
func _call_out() -> void:
	var packet := JSON.stringify({"g": GAME, "v": _protocol, "port": _port, "code": _code, "name": host_name()}).to_utf8_buffer()
	var targets := ["255.255.255.255", "127.0.0.1"]
	for ip in IP.get_local_addresses():
		if CoopCode.address_kind(ip) == "lan":
			var p := ip.split(".")
			targets.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	for t in targets:
		_beacon.set_dest_address(t, BEACON_PORT)
		_beacon.put_packet(packet)

## The name a host goes by on the network: the user's, on this machine.
static func host_name() -> String:
	for key in ["USER", "USERNAME"]:
		var v := OS.get_environment(key)
		if v != "":
			return v.capitalize()
	return "?"

# --- Joining ---------------------------------------------------------------------------

## Listens for hosts on this network (while the co-op screen is open).
func listen(on: bool) -> void:
	if on and _listener == null:
		_listener = PacketPeerUDP.new()
		if _listener.bind(BEACON_PORT) != OK:
			_listener = null
	elif not on and _listener != null:
		_listener.close()
		_listener = null
		hosts.clear()
		hosts_changed.emit()

func _listen() -> void:
	var changed := false
	var now := Time.get_ticks_msec() / 1000.0
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(data) != TYPE_DICTIONARY or data.get("g") != GAME or int(data.get("v", -1)) != _protocol_heard():
			continue
		# Our own beacon, heard back on this machine, isn't someone to join.
		if _beacon != null and String(data.get("code", "")) == _code:
			continue
		if not hosts.has(ip):
			changed = true
		hosts[ip] = {"name": String(data.get("name", "?")), "code": String(data.get("code", "")), "port": int(data.get("port", 0)), "seen": now}
	for ip in hosts.keys():
		if now - float(hosts[ip]["seen"]) > HOST_TIMEOUT:
			hosts.erase(ip)
			changed = true
	if changed:
		hosts_changed.emit()

func _protocol_heard() -> int:
	return _protocol if _protocol != 0 else Net.PROTOCOL

## The host on this network giving out `code`, if there is one: its address.
func lan_host_for(code: String) -> String:
	var letters := CoopCode.normalize(code)
	for ip in hosts:
		if CoopCode.normalize(String(hosts[ip]["code"])) == letters:
			return ip
	return ""

# --- Addresses -------------------------------------------------------------------------

## Whether `code` names this machine: its own code, copied to be sent.
func is_own_code(code: String) -> bool:
	var decoded := CoopCode.decode(code)
	if decoded.is_empty():
		return false
	var ip: String = decoded["ip"]
	return ip in IP.get_local_addresses() or ip == _external

func _best_local() -> String:
	for ip in IP.get_local_addresses():
		if CoopCode.address_kind(ip) == "lan":
			return ip
	return "127.0.0.1"

func _vpn_address() -> String:
	for ip in IP.get_local_addresses():
		if CoopCode.address_kind(ip) == "vpn":
			return ip
	return ""

func _exit_tree() -> void:
	listen(false)
	close()
	for t in _returning:
		t.wait_to_finish()
	_returning.clear()
