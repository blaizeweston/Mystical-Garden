extends RefCounted
## Collects the training brain's decisions into whole mob lives and writes them as rollout shards for the
## Python trainer (ai/training/rollouts.py reads the same format).
##
## A life is one mob from spawn to death or the end of its episode. Each decision earns the reward its mob
## collected until its next decision (or the end of the life), taken from ai/mob_rewards.gd. A life ends as
## terminal (death, a wipe, every mob dead) or truncated (time limit), which the trainer bootstraps.
##
## Shards are written atomically: to a .tmp file first, then renamed, and they end with a SHA-256 of all that
## comes before it, so a shard cut short by a power loss is detected and discarded rather than trained on.
##
## Shard layout, little-endian:
##   "MOBR", u32 format version, 64 ASCII schema hash, u32 policy version, u32 worker, u32 rows, u32 lives,
##   u32 observation size, u32 critic state size, u32 memory size, u32 mask size, u32 head count,
##   i32 life[rows], f32 obs[rows][obs], f32 global[rows][global], f32 memory[rows][memory],
##   u8 masks[rows][mask], u8 actions[rows][heads], f32 log_prob[rows], f32 reward[rows], u8 end[rows],
##   u32 stats length, UTF-8 JSON episode stats, 32-byte SHA-256 of everything before it.
## Rows of one life are contiguous and in decision order; end is 0 within a life, then 1 (terminal) or
## 2 (truncated) on its last row.

const MAGIC := "MOBR"
const FORMAT_VERSION := 1

enum End { CONTINUES = 0, TERMINAL = 1, TRUNCATED = 2 }


class Life:
	var obs := PackedFloat32Array()
	var global_state := PackedFloat32Array()
	var memory := PackedFloat32Array()
	var masks := PackedByteArray()
	var actions := PackedByteArray()
	var log_prob := PackedFloat32Array()
	var reward := PackedFloat32Array()


var obs_size := 0
var global_size := 0
var memory_size := 0
var mask_size := 0
var heads := 0
var schema_hash := ""
## Supplies each mob's reward through take(slot). Set by the episode runner.
var rewards: RefCounted
var policy_version := 0
var rows := 0
var lives := 0
## One dictionary per finished episode, written into the shard for the trainer's reports.
var episodes: Array = []

var _open := {}
var _life := PackedInt32Array()
var _obs := PackedFloat32Array()
var _global := PackedFloat32Array()
var _memory := PackedFloat32Array()
var _masks := PackedByteArray()
var _actions := PackedByteArray()
var _log_prob := PackedFloat32Array()
var _reward := PackedFloat32Array()
var _end := PackedByteArray()


func _init(schema: RefCounted) -> void:
	obs_size = schema.observation_size
	global_size = schema.global_size
	memory_size = int(schema.network.recurrent_hidden)
	mask_size = schema.contract.mask_size
	heads = schema.contract.head_sizes.size()
	schema_hash = schema.hash_hex


## Adds a decision to the slot's open life, first crediting the previous decision with the reward earned since.
func record(slot: int, obs: PackedFloat32Array, global_state: PackedFloat32Array, memory: PackedFloat32Array, masks: PackedByteArray,
		actions: PackedByteArray, log_prob: float) -> void:
	var earned: float = rewards.take(slot) if rewards != null else 0.0
	var life: Life = _open.get(slot)
	if life == null:
		life = Life.new()
		_open[slot] = life
	elif not life.reward.is_empty():
		life.reward[life.reward.size() - 1] += earned
	life.obs.append_array(obs)
	life.global_state.append_array(global_state)
	life.memory.append_array(memory)
	life.masks.append_array(masks)
	life.actions.append_array(actions)
	life.log_prob.append(log_prob)
	life.reward.append(0.0)


func has_life(slot: int) -> bool:
	return _open.has(slot)


## Ends the slot's life, crediting its last decision with what it earned since.
func close(slot: int, end: End) -> void:
	var life: Life = _open.get(slot)
	_open.erase(slot)
	var earned: float = rewards.take(slot) if rewards != null else 0.0
	if life == null or life.reward.is_empty():
		return
	life.reward[life.reward.size() - 1] += earned
	var count := life.reward.size()
	for index in count:
		_life.append(lives)
	_obs.append_array(life.obs)
	_global.append_array(life.global_state)
	_memory.append_array(life.memory)
	_masks.append_array(life.masks)
	_actions.append_array(life.actions)
	_log_prob.append_array(life.log_prob)
	_reward.append_array(life.reward)
	var ends := PackedByteArray()
	ends.resize(count)
	ends.fill(End.CONTINUES)
	ends[count - 1] = end
	_end.append_array(ends)
	rows += count
	lives += 1


func close_all(end: End) -> void:
	for slot: int in _open.keys():
		close(slot, end)


## Drops open lives without keeping them, for an episode abandoned part way.
func discard_open() -> void:
	_open.clear()


func clear() -> void:
	_open.clear()
	for table in [_life, _obs, _global, _memory, _log_prob, _reward]:
		table.clear()
	for table in [_masks, _actions, _end]:
		table.clear()
	episodes.clear()
	rows = 0
	lives = 0


func to_bytes(worker: int) -> PackedByteArray:
	var head := StreamPeerBuffer.new()
	head.big_endian = false
	head.put_data(MAGIC.to_ascii_buffer())
	head.put_u32(FORMAT_VERSION)
	head.put_data(schema_hash.to_ascii_buffer())
	for value in [policy_version, worker, rows, lives, obs_size, global_size, memory_size, mask_size, heads]:
		head.put_u32(value)
	var out := head.data_array
	out.append_array(_life.to_byte_array())
	out.append_array(_obs.to_byte_array())
	out.append_array(_global.to_byte_array())
	out.append_array(_memory.to_byte_array())
	out.append_array(_masks)
	out.append_array(_actions)
	out.append_array(_log_prob.to_byte_array())
	out.append_array(_reward.to_byte_array())
	out.append_array(_end)
	var stats := JSON.stringify(episodes).to_utf8_buffer()
	var length := StreamPeerBuffer.new()
	length.big_endian = false
	length.put_u32(stats.size())
	out.append_array(length.data_array)
	out.append_array(stats)
	out.append_array(sha256(out))
	return out


## Writes the collected lives to folder/name.shard through a temporary file and clears them. Returns OK or an error.
func write_shard(folder: String, name: String, worker: int) -> int:
	var data := to_bytes(worker)
	var temporary := folder.path_join(name + ".tmp")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(data)
	file.flush()
	var failed := file.get_error()
	file.close()
	if failed != OK:
		DirAccess.remove_absolute(temporary)
		return failed
	var status := DirAccess.rename_absolute(temporary, folder.path_join(name + ".shard"))
	if status != OK:
		DirAccess.remove_absolute(temporary)
		return status
	clear()
	return OK


static func sha256(data: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish()
