class_name CoopCode
extends RefCounted
## The code a host gives a friend to join by: the host's address and port,
## written short enough to read out or paste in a message. Crockford's base
## 32 (no I, L, O or U, read either case; O is taken for 0, I and L for 1)
## and a check letter at the end, in groups for the eye: "4H7K-QM2X-9PZ".
## Six bytes (an IPv4 address and a port) make ten letters, and the check
## one more.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

## The code for `ip` (dotted IPv4) and `port`, or "" if it isn't an IPv4.
static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var bytes := PackedByteArray()
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		bytes.append(int(p))
	bytes.append((port >> 8) & 0xFF)
	bytes.append(port & 0xFF)
	# 48 bits, five at a time from the top: ten letters.
	var value := 0
	for b in bytes:
		value = (value << 8) | b
	var letters := ""
	for i in range(9, -1, -1):
		letters += ALPHABET[(value >> (i * 5)) & 31]
	letters += ALPHABET[_check(letters)]
	return "%s-%s-%s" % [letters.substr(0, 4), letters.substr(4, 4), letters.substr(8)]

## {"ip": String, "port": int} from a code, or {} if it isn't one (a typo
## the check letter catches, or not a code at all).
static func decode(code: String) -> Dictionary:
	var letters := normalize(code)
	if letters.length() != 11:
		return {}
	var value := 0
	for i in 10:
		var d := ALPHABET.find(letters[i])
		if d < 0:
			return {}
		value = (value << 5) | d
	if ALPHABET.find(letters[10]) != _check(letters.substr(0, 10)):
		return {}
	var port := value & 0xFFFF
	var ip := "%d.%d.%d.%d" % [(value >> 40) & 0xFF, (value >> 32) & 0xFF, (value >> 24) & 0xFF, (value >> 16) & 0xFF]
	if port == 0:
		return {}
	return {"ip": ip, "port": port}

## The letters of a code as typed or pasted: capitals, without the dashes,
## spaces and the like, the look-alike letters read as Crockford reads them.
static func normalize(code: String) -> String:
	var out := ""
	for c in code.to_upper():
		match c:
			"O":
				out += "0"
			"I", "L":
				out += "1"
			_:
				if ALPHABET.contains(c):
					out += c
	return out

## Whether `text` looks like a code rather than an address someone typed.
static func is_code(text: String) -> bool:
	return not decode(text).is_empty()

static func _check(letters: String) -> int:
	var sum := 0
	for i in letters.length():
		sum += ALPHABET.find(letters[i]) * (i + 1)
	return sum % 31

## What kind of address this is: "lan" (192.168/10/172.16-31), "vpn"
## (100.64-127, as Tailscale gives out), "loopback", "public", or "" for
## what isn't an IPv4 address at all.
static func address_kind(ip: String) -> String:
	var p := ip.split(".")
	if p.size() != 4 or not ip.is_valid_ip_address():
		return ""
	var a := int(p[0])
	var b := int(p[1])
	if a == 127:
		return "loopback"
	if a == 10 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31):
		return "lan"
	if a == 100 and b >= 64 and b <= 127:
		return "vpn"
	return "public"
