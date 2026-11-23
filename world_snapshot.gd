extends RefCounted
## Protocol 41 replacement frame. The unreliable RPC has one byte-array argument.
## The 1,200-byte application budget leaves 192 bytes below Godot's 1,392-byte
## ENet MTU warning threshold for RPC framing and transport headroom.
const Encounter = preload("res://encounter_config.gd")
const Network = preload("res://network_settings.gd")
const Appearance = preload("res://character_appearance.gd")
const APPEARANCE_BITS := [2, 2, 2, 2, 2, 1, 7, 7, 7, 7, 7, 7, 7, 1, 1, 1, 1]
const SCHEMA := 1
const HEADER := 52
const CAMPAIGN_WORDS := Encounter.BOSS_PHASE + 1
const PLAYER_BYTES := 137
const SCOUT_BYTES := 21
const PAYLOAD_BUDGET := 1200
const MAX_FRAME := HEADER + CAMPAIGN_WORDS * 4 + Network.MAX_PLAYERS * PLAYER_BYTES + Encounter.MAX_SCOUTS * SCOUT_BYTES
const CLIPS := ["", "Attack_bell", "Attack_blade", "Attack_bow", "Attack_censer", "Attack_crossbow",
	"Attack_fan", "Attack_hammer", "Attack_knives", "Attack_orb", "Attack_ring", "Attack_scythe",
	"Attack_spear", "Attack_staff", "Attack_wand", "Attack_whip",
	"Attack_bell_line", "Attack_bell_sweep", "Attack_blade_line", "Attack_censer_line", "Attack_censer_sweep",
	"Attack_hammer_line", "Attack_knives_line", "Attack_scythe_line", "Attack_spear_sweep", "Attack_whip_sweep", "Attack_maul_overhead", "Attack_maul_sweep", "Attack_wand_forward", "Attack_wand_sweep", "Attack_focus_push", "Attack_focus_gather",
	"Attack_bow_upright", "Attack_bow_canted", "Attack_crossbow_raised", "Attack_crossbow_low", "Attack_ring_sidearm", "Attack_ring_rising", "Attack_knives_right", "Attack_knives_left",
	"Attack_rootblade_forehand", "Attack_rootblade_backhand", "Attack_staff_forward", "Attack_staff_side",
	"Attack_whip_forehand", "Attack_whip_backhand"]
const DELIVERIES := ["sweep", "line", "projectile", "radial", "sector"]


static func encode(sequence: int, people: Dictionary, campaign: PackedInt32Array, scouts: PackedFloat32Array,
		enemy: Vector3, hp: int, max_hp: int, drop: Vector3, depth: int, flags: int) -> PackedByteArray:
	@warning_ignore("integer_division")
	var count := scouts.size() / Encounter.PACK_STRIDE
	if people.is_empty() or people.size() > Network.MAX_PLAYERS or campaign.size() != CAMPAIGN_WORDS \
			or count > Encounter.MAX_SCOUTS or scouts.size() % Encounter.PACK_STRIDE != 0:
		return PackedByteArray()
	var bytes := PackedByteArray()
	bytes.resize(HEADER + CAMPAIGN_WORDS * 4 + people.size() * PLAYER_BYTES + count * SCOUT_BYTES)
	bytes.encode_u64(0, sequence)
	_encode_vector(bytes, 8, enemy)
	_encode_vector(bytes, 20, drop)
	bytes.encode_s32(32, hp)
	bytes.encode_s32(36, max_hp)
	bytes.encode_s32(40, depth)
	bytes[48] = flags
	bytes[49] = people.size()
	bytes[50] = count
	bytes[51] = SCHEMA
	var offset := HEADER
	for word in campaign:
		bytes.encode_s32(offset, word)
		offset += 4
	for id in people:
		_encode_player(bytes, offset, int(id), people[id])
		offset += PLAYER_BYTES
	for i in count:
		var scout := i * Encounter.PACK_STRIDE
		for axis in 3:
			bytes.encode_float(offset + axis * 4, scouts[scout + axis])
		bytes.encode_float(offset + 12, scouts[scout + 6])
		bytes.encode_float(offset + 16, scouts[scout + 7])
		bytes[offset + 20] = int(scouts[scout + 3]) | (int(scouts[scout + 4]) << 1) | (int(scouts[scout + 5]) << 3)
		offset += SCOUT_BYTES
	return bytes


static func for_viewer(shared: PackedByteArray, carried: int, dropped: bool, pouch: bool) -> PackedByteArray:
	var bytes := shared.duplicate()
	bytes.encode_s32(44, carried)
	bytes[48] = bytes[48] | (2 if dropped else 0) | (4 if pouch else 0)
	return bytes


static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER or bytes.size() > MAX_FRAME or bytes[51] != SCHEMA:
		return {}
	var sequence := bytes.decode_u64(0)
	if sequence < 0:
		return {}
	var people_count := bytes[49]
	var scout_count := bytes[50]
	if people_count < 1 or people_count > Network.MAX_PLAYERS or scout_count > Encounter.MAX_SCOUTS \
			or bytes.size() != HEADER + CAMPAIGN_WORDS * 4 + people_count * PLAYER_BYTES + scout_count * SCOUT_BYTES:
		return {}
	var offset := HEADER
	var campaign := PackedInt32Array()
	for i in CAMPAIGN_WORDS:
		campaign.append(bytes.decode_s32(offset))
		offset += 4
	var people := {}
	for i in people_count:
		var id := bytes.decode_u32(offset)
		if id == 0 or people.has(id) or bytes[offset + 105] >= CLIPS.size() or bytes[offset + 106] >= DELIVERIES.size():
			return {}
		people[id] = _decode_player(bytes, offset, campaign, bytes.decode_s32(36))
		offset += PLAYER_BYTES
	var scouts := PackedFloat32Array()
	for i in scout_count:
		var flags := bytes[offset + 20]
		scouts.append_array(PackedFloat32Array([
			bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8),
			flags & 1, (flags >> 1) & 3, (flags >> 3) & 1,
			bytes.decode_float(offset + 12), bytes.decode_float(offset + 16)]))
		offset += SCOUT_BYTES
	return {"sequence": sequence, "people": people, "campaign": campaign, "scouts": scouts,
		"enemy": _decode_vector(bytes, 8), "drop": _decode_vector(bytes, 20), "hp": bytes.decode_s32(32),
		"depth": bytes.decode_s32(40), "carried": bytes.decode_s32(44), "flags": bytes[48]}


static func _encode_player(bytes: PackedByteArray, offset: int, id: int, p: Dictionary) -> void:
	bytes.encode_u32(offset, id)
	_encode_vector(bytes, offset + 4, p.pos)
	_encode_vector(bytes, offset + 16, p.velocity)
	bytes.encode_float(offset + 28, p.motion_radius)
	bytes.encode_float(offset + 32, p.motion_scale)
	bytes.encode_u32(offset + 36, p.motion_ack.ack)
	bytes.encode_u32(offset + 40, p.motion_ack.partial_sequence)
	bytes.encode_float(offset + 44, p.motion_ack.partial)
	bytes.encode_u32(offset + 48, p.vitals_revision)
	bytes.encode_u32(offset + 52, p.damage_seq)
	bytes.encode_s32(offset + 56, p.damage_amount)
	bytes.encode_float(offset + 60, p.hp)
	bytes.encode_s32(offset + 64, p.max_hp)
	bytes.encode_s32(offset + 68, p.lost_health)
	bytes.encode_s32(offset + 72, p.wallet)
	bytes.encode_s32(offset + 76, p.get("garden_layout_revision", -2))
	bytes.encode_u16(offset + 80, p.pose)
	bytes.encode_u16(offset + 82, p.core_part)
	bytes[offset + 84] = p.party_slot
	bytes[offset + 85] = int(p.wild) | (int(p.fallen) << 1) | (int(p.skill_ready) << 2) | (int(p.skill_two_ready) << 3)
	bytes[offset + 86] = p.frame
	bytes[offset + 87] = p.weapon_kind
	bytes.encode_u64(offset + 88, _pack_appearance(p.appearance))
	var attack: Dictionary = p.attack_anim
	var cast: bool = attack.form == "cast"
	var direction: Variant = attack.direction
	bytes[offset + 96] = int(attack.active) | (int(cast) << 1) | (4 if direction is Vector3 else 0) | (8 if attack.get("aim_live", false) else 0)
	bytes.encode_float(offset + 97, p.skill_cooldowns[0])
	bytes.encode_float(offset + 101, p.skill_cooldowns[1])
	bytes[offset + 105] = maxi(0, CLIPS.find(attack.clip))
	bytes[offset + 106] = maxi(0, DELIVERIES.find(attack.get("delivery", "sweep")))
	bytes.encode_float(offset + 107, attack.phase)
	bytes.encode_u32(offset + 111, attack.combo)
	bytes.encode_u16(offset + 115, attack.duration)
	if direction is Vector3:
		_encode_vector(bytes, offset + 117, direction)
	bytes.encode_float(offset + 129, attack.get("reach", 0.0))
	bytes.encode_float(offset + 133, attack.get("span", 0.0))


static func _decode_player(bytes: PackedByteArray, offset: int, campaign: PackedInt32Array, enemy_max_hp: int) -> Dictionary:
	var flags := bytes[offset + 85]
	var wild := (flags & 1) != 0
	var fallen := (flags & 2) != 0
	var attack_flags := bytes[offset + 96]
	var cast := (attack_flags & 2) != 0
	var attack := {"active": (attack_flags & 1) != 0, "form": "cast" if cast else "weapon",
		"clip": CLIPS[bytes[offset + 105]], "phase": bytes.decode_float(offset + 107),
		"combo": bytes.decode_u32(offset + 111), "duration": bytes.decode_u16(offset + 115),
		"direction": null}
	if attack_flags & 4: attack.direction = _decode_vector(bytes, offset + 117)
	if not cast:
		attack.merge({"aim_live": (attack_flags & 8) != 0, "delivery": DELIVERIES[bytes[offset + 106]],
			"reach": bytes.decode_float(offset + 129), "span": bytes.decode_float(offset + 133)})
	var player := {"pos": _decode_vector(bytes, offset + 4), "velocity": _decode_vector(bytes, offset + 16),
		"motion_radius": bytes.decode_float(offset + 28), "motion_scale": bytes.decode_float(offset + 32),
		"motion_epoch": str([campaign[0], campaign[9], campaign[8], wild, fallen]),
		"motion_ack": {"ack": bytes.decode_u32(offset + 36), "partial_sequence": bytes.decode_u32(offset + 40),
			"partial": bytes.decode_float(offset + 44)},
		"vitals_revision": bytes.decode_u32(offset + 48), "damage_seq": bytes.decode_u32(offset + 52),
		"damage_amount": bytes.decode_s32(offset + 56), "hp": bytes.decode_float(offset + 60),
		"max_hp": bytes.decode_s32(offset + 64), "lost_health": bytes.decode_s32(offset + 68),
		"wallet": bytes.decode_s32(offset + 72), "pose": bytes.decode_u16(offset + 80),
		"core_part": bytes.decode_u16(offset + 82), "party_slot": bytes[offset + 84],
		"wild": wild, "fallen": fallen, "skill_ready": (flags & 4) != 0, "skill_two_ready": (flags & 8) != 0,
		"frame": bytes[offset + 86], "weapon_kind": bytes[offset + 87],
		"appearance": _unpack_appearance(bytes.decode_u64(offset + 88)), "attack_anim": attack, "enemy_max_hp": enemy_max_hp,
		"skill_cooldowns": [bytes.decode_float(offset + 97), bytes.decode_float(offset + 101)]}
	var garden_revision := bytes.decode_s32(offset + 76)
	if garden_revision != -2:
		player.garden_layout_revision = garden_revision
	return player


static func _pack_appearance(values: PackedByteArray) -> int:
	var normalized := Appearance.normalize(values)
	var result := 0
	var shift := 0
	for i in APPEARANCE_BITS.size():
		var width: int = APPEARANCE_BITS[i]
		var value: int = normalized[i]
		result |= (value & ((1 << width) - 1)) << shift
		shift += width
	return result


static func _unpack_appearance(value: int) -> PackedByteArray:
	var result := PackedByteArray()
	var shift := 0
	for width in APPEARANCE_BITS:
		result.append((value >> shift) & ((1 << width) - 1))
		shift += width
	return result


static func _encode_vector(bytes: PackedByteArray, offset: int, value: Vector3) -> void:
	bytes.encode_float(offset, value.x)
	bytes.encode_float(offset + 4, value.y)
	bytes.encode_float(offset + 8, value.z)


static func _decode_vector(bytes: PackedByteArray, offset: int) -> Vector3:
	return Vector3(bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8))
