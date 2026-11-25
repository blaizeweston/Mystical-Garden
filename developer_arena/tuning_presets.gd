extends "res://developer_arena/named_files.gd"
const Tune = preload("res://developer_arena/tuning.gd")
const VERSION := 1
func _prefix() -> String: return "preset-"

func _dir() -> String:
	if not is_instance_valid(world) or not "developer_tuning" in world or world.developer_tuning == null: return ""
	return world.developer_tuning.directory(world)

func fingerprint(id: String) -> String:
	var row: Dictionary = Tune.PROPERTIES[id]
	var path := "res://" + str(row.source)
	# In marked debug templates source text may be stripped. Identify that narrower evidence explicitly.
	if FileAccess.file_exists(path):
		var hash := FileAccess.get_sha256(path)
		if not hash.is_empty():
			if Tune.Contacts.DEFAULTS.has(id):
				var shader_path := "res://assets/shaders/contact_fragments.gdshader"
				if FileAccess.file_exists(shader_path): hash = (hash+FileAccess.get_sha256(shader_path)).sha256_text()
			if id == Tune.SUN:
				var climate := "res://assets/terrain_m02/wilds_biome.gd"
				if FileAccess.file_exists(climate): hash = (hash+FileAccess.get_sha256(climate)).sha256_text()
			return "sha256:" + hash
	return "runtime:" + (str(row.symbol)+"|"+str(world.developer_tuning.baseline(id))).sha256_text()

func snapshot(name: String) -> Dictionary:
	if _dir().is_empty(): return {}
	var entries := []
	var tune = world.developer_tuning
	for id in Tune.PROPERTIES:
		var value: float = tune.requested(id)
		var original: float = tune.baseline(id)
		if is_equal_approx(value,original): continue
		var row: Dictionary = Tune.PROPERTIES[id]
		entries.append({"id":id,"type":row.type,"unit":row.unit,"original":original,"modified":value,
			"source":str(row.source)+"#"+str(row.symbol),"fingerprint":fingerprint(id)})
	return {"format":VERSION,"name":name,"commit":git_commit(),"properties":entries}

func save_new(name: String) -> String:
	var folder := _dir()
	if folder.is_empty(): return "Developer session required."
	return _new_file(folder,snapshot(name))

func compare(record: Dictionary) -> Dictionary:
	var result := {"invalid":[],"conflicts":[],"compatible":[],"values":{}}
	if _dir().is_empty() or record.get("format")!=VERSION or not record.get("properties") is Array or not record.get("commit") is String or not record.get("name") is String:
		result.invalid.append("Incompatible preset format.")
		return result
	var seen := {}
	for entry in record.properties:
		if not entry is Dictionary or not entry.get("id") is String:
			result.invalid.append("Invalid property record.")
			continue
		var id: String = entry.id
		if not Tune.PROPERTIES.has(id):
			result.invalid.append("Unsupported property: "+id)
			continue
		var row: Dictionary = Tune.PROPERTIES[id]
		if seen.has(id) or entry.get("type")!=row.type or entry.get("unit")!=row.unit or not entry.get("fingerprint") is String or str(entry.fingerprint).is_empty() or entry.get("source")!=str(row.source)+"#"+str(row.symbol):
			result.invalid.append(id+" — incompatible or duplicate definition.")
			continue
		seen[id]=true
		if not Tune.valid(id,entry.get("modified")) or not (entry.get("original") is float or entry.get("original") is int) or not is_finite(entry.original):
			result.invalid.append(id+" — invalid experimental or original value.")
			continue
		result.values[id]=entry.modified
		var current: float=world.developer_tuning.baseline(id)
		if not is_equal_approx(current,entry.original):
			result.conflicts.append("%s — baseline changed from %s to %s %s."%[id,entry.original,current,row.unit])
		elif fingerprint(id)!=entry.fingerprint: result.conflicts.append(id+" — source fingerprint changed.")
		else: result.compatible.append(id)
	return result

func load_named(name: String, confirmation := "") -> String:
	var record := read(name)
	var report := compare(record)
	if not report.invalid.is_empty(): return "\n".join(report.invalid)
	if (not confirmation.is_empty() or not report.conflicts.is_empty()) and confirmation != review_token(record,report):
		return "Review and confirm changed baselines first."
	return "" if world.developer_tuning.replace(world,report.values) else "Developer session required."

func review_token(record: Dictionary, report: Dictionary) -> String:
	var sources := {}
	for id in report.values:
		sources[id]=[world.developer_tuning.baseline(id),fingerprint(id)]
	return JSON.stringify([record,sources]).sha256_text()

func export_review(name: String = "") -> String:
	var folder := _dir()
	if folder.is_empty(): return "Developer session required."
	var record := snapshot("Current changes") if name.is_empty() else read(name)
	if record.is_empty(): return "Preset unavailable."
	var report := compare(record)
	var proposal := {"preset":record.get("name",""),"format":VERSION,"origin_commit":record.get("commit",""),"review_commit":git_commit(),
		"invalid":report.invalid,"conflicts":report.conflicts,"differences":[]}
	var lines := PackedStringArray(["# Mystical Garden tuning proposal","","Preset: "+str(proposal.preset),"","Origin commit: "+str(proposal.origin_commit),"Review commit: "+str(proposal.review_commit),""])
	var entries: Variant=record.get("properties",[])
	for entry in entries if entries is Array else []:
		if not entry is Dictionary or not report.values.has(entry.get("id","")) or not Tune.valid(entry.id,entry.get("modified")) or not entry.has_all(["original","source","fingerprint","unit"]): continue
		var current: float=world.developer_tuning.baseline(entry.id)
		if is_equal_approx(current,entry.modified): continue
		var diff: Dictionary=entry.duplicate()
		diff.current_baseline=current
		diff.current_fingerprint=fingerprint(entry.id)
		proposal.differences.append(diff)
		lines.append("- %s: %s → %s %s (original %s). Source: %s."%[entry.id,current,entry.modified,entry.unit,entry.original,entry.source])
	lines.append("")
	for issue in report.invalid+report.conflicts: lines.append("- "+str(issue))
	var location:=folder.path_join("exports").path_join("review-"+Crypto.new().generate_random_bytes(8).hex_encode())
	if DirAccess.make_dir_recursive_absolute(location)!=OK or _write(location.path_join("changes.json"),JSON.stringify(proposal,"  "))!=OK or _write(location.path_join("changes.md"),"\n".join(lines)+"\n")!=OK: return "Could not write the complete export."
	return ProjectSettings.globalize_path(location)
