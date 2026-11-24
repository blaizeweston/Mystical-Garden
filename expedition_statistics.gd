extends RefCounted
## Host-only, in-memory observations. Rows are keyed by the character identity
## used to freeze rewards. Run IDs come from ExpeditionParticipation.
const ACTIVE := "In the Wilds"
const SETTLING := "Departure pending"
const COUNTERS := ["damage", "kills", "elites", "bosses", "taken", "healing", "prevented", "revives", "falls", "xp", "cards", "grafts"]

var _session := ""
var _run := 0
var _start_ms := 0
var _deepest := 0
var _clears := 0
var _last_clear := -1
var _party := {}
var _rows := {}
var _entries := {}
var _pending := {}
var _results := {}
var _disconnected := {}
var _confirmed_departures := {}

func bind_session(session: String) -> void:
	if _session == session: return
	_session = session
	_run = 0
	_rows.clear()
	_party.clear()
	_entries.clear()
	_pending.clear()
	_results.clear()
	_disconnected.clear()
	_confirmed_departures.clear()

func admit(run: int, identity: String, display_name: String, class_name_text: String, floor_number: int, now: int) -> void:
	if identity.is_empty() or run <= 0 or run < _run: return
	if run != _run:
		_run = run
		_start_ms = now
		_deepest = floor_number
		_clears = 0
		_last_clear = -1
		_party = {"damage":0.0,"kills":0,"elites":0,"bosses":0,"healing":0.0,"unattributed_damage":0.0,"unattributed_healing":0.0}
		_rows = {}
	if _rows.has(identity): return
	_results.erase(identity)
	_entries[identity] = run
	var row := {"name":display_name,"class_name":class_name_text,"outcome":ACTIVE,"affinity":{}}
	for metric in COUNTERS: row[metric] = 0
	_rows[identity] = row

func reached(run: int, floor_number: int) -> void:
	if run == _run: _deepest = maxi(_deepest, floor_number)

func clear_encounter(run: int, floor_number: int) -> void:
	if run != _run or _rows.is_empty() or floor_number <= _last_clear: return
	_last_clear = floor_number
	_clears += 1

func _active(run: int, identity: String) -> bool:
	return run == _run and _rows.has(identity) and _rows[identity].outcome == ACTIVE

func count(run: int, identity: String, metric: String, amount: float = 1.0) -> void:
	if amount > 0 and metric in COUNTERS and _active(run,identity):
		_rows[identity][metric] += amount

## Weights are captured by the effect resolver. Keep fractional HP internally
## so even a one-HP tick shared by four people credits all four.
func damage(run: int, amount: int, weights: Dictionary, affinity: String) -> void:
	if run != _run or _rows.is_empty() or amount <= 0: return
	_party.damage += amount
	var total := 0.0
	for weight in weights.values(): total += maxf(0.0,weight)
	if total <= 0:
		_party.unattributed_damage += amount
		return
	for identity: String in weights:
		var share := amount * float(weights[identity]) / total
		if not _active(run,identity):
			_party.unattributed_damage += share
			continue
		var row: Dictionary = _rows[identity]
		row.damage += share
		if not affinity.is_empty(): row.affinity[affinity] = float(row.affinity.get(affinity,0.0)) + share

func defeat(run: int, finisher: String, elite: bool, boss: bool) -> void:
	if run != _run or _rows.is_empty(): return
	for metric in ["kills", "elites" if elite else "", "bosses" if boss else ""]:
		if not metric.is_empty():
			_party[metric] += 1
			count(run,finisher,metric)

func heal(run: int, provider: String, amount: float) -> void:
	if run != _run or _rows.is_empty() or amount <= 0: return
	_party.healing += amount
	if _active(run,provider): count(run,provider,"healing",amount)
	else: _party.unattributed_healing += amount

func _snapshot(identity: String, now: int) -> Dictionary:
	return {"session":_session,"run":_run,"personal_index":_rows.keys().find(identity),"outcome":_rows[identity].outcome,"elapsed_ms":maxi(0,now-_start_ms),
		"floor":_deepest,"clears":_clears,"party":_party.duplicate(true),"players":_rows.values().duplicate(true)}

func finish(run: int, identity: String, outcome: String, now: int) -> void:
	if not _active(run,identity): return
	_rows[identity].outcome = outcome
	_pending[identity] = now

## Freeze when the peer leaves. A later settlement may run after another
## character has entered a different expedition.
func freeze_departure(run: int, identity: String, now: int) -> void:
	if not _active(run,identity): return
	_rows[identity].outcome = SETTLING
	_disconnected[identity] = _snapshot(identity,now)
	_disconnected[identity].players[_disconnected[identity].personal_index].outcome = "Disconnected"

func settled_disconnect(identity: String) -> void:
	if not _disconnected.has(identity): return
	var frozen: Dictionary = _disconnected[identity]
	frozen.outcome = "Disconnected"
	if frozen.run == _run and _rows.has(identity): _rows[identity].outcome = frozen.outcome
	_confirmed_departures[identity] = frozen
	_disconnected.erase(identity)

func _retain(identity: String, report: Dictionary) -> void:
	_results.erase(identity)
	_results[identity] = report
	while _results.size() > 4: _results.erase(_results.keys()[0])

## Called only after the outer transaction commits. Party members returning
## together see all of its final outcomes. An early return captures the party
## at that instant, including teammates who are still playing.
func publishable() -> Array:
	for identity: String in _confirmed_departures: _retain(identity,_confirmed_departures[identity])
	_confirmed_departures.clear()
	var ready := _pending.keys()
	for identity: String in ready: _retain(identity,_snapshot(identity,_pending[identity]))
	_pending.clear()
	return ready

## Recovery owns the verdict after an ambiguous save. Another transaction's
## later success cannot publish this transaction's tentative completion.
func hold_uncertain() -> void:
	for identity in _pending.keys() + _confirmed_departures.keys():
		if _rows.has(identity): _rows[identity].outcome = "Settlement uncertain"
	_entries.clear()
	_pending.clear()
	_confirmed_departures.clear()

func take_entries() -> Dictionary:
	var entries := _entries
	_entries = {}
	return entries

func result_for(identity: String) -> Dictionary:
	return _results.get(identity,{}).duplicate(true)

func savepoint() -> Dictionary:
	return {"session":_session,"run":_run,"start_ms":_start_ms,"deepest":_deepest,"clears":_clears,"last_clear":_last_clear,
		"party":_party.duplicate(),"rows":_rows.duplicate(true),"pending":_pending.duplicate(),"entries":_entries.duplicate(),
		"results":_results.duplicate(),"disconnected":_disconnected.duplicate(true),"confirmed":_confirmed_departures.duplicate()}

func restore_savepoint(point: Dictionary) -> void:
	_session = point.session
	_run = point.run
	_start_ms = point.start_ms
	_deepest = point.deepest
	_clears = point.clears
	_last_clear = point.last_clear
	_party = point.party
	_rows = point.rows
	_pending = point.pending
	_results = point.results
	_disconnected = point.disconnected
	_entries = point.entries
	_confirmed_departures = point.confirmed
