extends SceneTree
const Auth = preload("res://persistence_authorization.gd")
const Plan = preload("res://persistence_recovery_plan.gd")
const Proof = preload("res://persistence_evidence.gd")
const Ops = preload("res://persistence_operations.gd")
const Batch = preload("res://save_batch.gd")
const G := "user://saves/slot_1/garden.cfg"
const C := "user://saves/characters/slot_1/character.cfg"
const P := "user://saves/characters/slot_2/character.cfg"
const PATHS := [C, G]
var failed := false

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, text: String) -> void:
 if not ok:
  failed = true
  printerr("FAIL: ", text)

func put(path: String, bytes: PackedByteArray) -> void:
 var file := FileAccess.open(path, FileAccess.WRITE)
 check(file != null, "write fixture " + path)
 if file != null:
  file.store_buffer(bytes)
  file.close()

func action(stage: Callable, _scope: RefCounted) -> Variant:
 check(stage.call(G, "new garden".to_utf8_buffer()) == OK, "stage Garden")
 check(stage.call(C, "new profile".to_utf8_buffer()) == OK, "stage profile")
 return null

func record(id: String, data: Dictionary) -> void:
 data.case = id
 data.run_id = OS.get_environment("MYSTICAL_VALIDATION_RUN")
 print("CASE ", JSON.stringify(data))

func artifacts() -> Dictionary:
 var result := {}
 for path: String in PATHS:
  for suffix: String in [""] + Plan.ARTIFACTS:
   var file := path + suffix
   result[file] = FileAccess.get_sha256(file) if FileAccess.file_exists(file) else null
 return result

func run() -> void:
 var paths := PackedStringArray(PATHS)
 check(Auth.bootstrap(PackedStringArray([G.get_base_dir(), C.get_base_dir(), P.get_base_dir()])).error == OK, "bootstrap")
 put(G, "old garden".to_utf8_buffer())
 put(C, "old profile".to_utf8_buffer())
 var before := artifacts()
 var foreign := Auth.replace_authorized(RefCounted.new(), G + Proof.SCRATCH, G + ".transaction")
 check(foreign.error == ERR_UNAUTHORIZED and artifacts() == before, "foreign context")
 var direct: Object = ClassDB.instantiate(Auth.BACKEND)
 check(direct.call("replace_authorized", ProjectSettings.globalize_path(G + Proof.SCRATCH), PackedStringArray([ProjectSettings.globalize_path(G + ".transaction")])) == 158, "native rejects unheld handle")
 direct.free()
 var held := Auth.run(PackedStringArray([G + Proof.SCRATCH]), func(token):
  return Auth.replace_authorized(token, G + Proof.SCRATCH, G + ".transaction"))
 check(held.ran and held.value.error == ERR_UNAUTHORIZED and artifacts() == before, "incomplete scope")

 var plan := Plan.discover(paths)
 var too_many := Plan.check_footprint(plan, paths, G, 10, 64 * 1024 * 1024, 1024, 1024)
 check(not too_many, "aggregate stage limit")
 var crowded := plan.duplicate(true)
 crowded.directory_counts[G.get_base_dir()] = Plan.MAX_DIRECTORY_ENTRIES - 1
 check(not Plan.check_footprint(crowded, paths, G, 10, 10, 1024, 1024), "directory footprint")
 var scope := PackedStringArray([G])
 var dirs := PackedStringArray()
 for index in range(1, 8):
  var path := "user://saves/characters/slot_%d/character.cfg" % index
  scope.append(path)
  dirs.append(path.get_base_dir())
 check(Auth.bootstrap(dirs).error == OK, "aggregate footprint bootstrap")
 var oversized_stage := PackedByteArray()
 oversized_stage.resize(Plan.MAX_RECORD_BYTES)
 var aggregate := Ops.run_batch(scope, G, func(stage, _context):
  for path in scope:
   check(stage.call(path, oversized_stage) == OK, "individually allowed stage"))
 var refused: Batch.Finalization = aggregate.value.outcome
 check(refused.outcome == Batch.Outcome.ABORTED_RESTORED and refused.phase == "transaction_footprint" and artifacts() == before, "actual aggregate rejection without mutation")
 for path in scope:
  if path not in PATHS:
   check(DirAccess.get_files_at(path.get_base_dir()).is_empty(), "extra participants stayed empty")
 record("aggregate_footprint", {"outcome": refused.outcome, "phase": refused.phase, "bytes": scope.size() * Plan.MAX_RECORD_BYTES, "before": before, "after": artifacts()})
 var original := PackedByteArray()
 original.resize(2 * 1024 * 1024)
 original.fill(255)
 put(G, original)
 var large_before := artifacts()
 var oversized := Ops.run_batch(paths, G, action)
 var large: Batch.Finalization = oversized.value.outcome
 check(large.outcome == Batch.Outcome.ABORTED_RESTORED and large.phase == "journal_size_limit" and large_before == artifacts(), "oversized journal refused before writes")
 record("footprint", {"outcome": large.outcome, "phase": large.phase, "before": large_before, "after": artifacts()})
 put(G, "old garden".to_utf8_buffer())

 var pending := Ops._run_batch(paths, G, action, false, func(phase, path):
  if phase == "cleanup" and path == G + Proof.RECEIPT:
   return ERR_CANT_CREATE
  return OK)
 var result: Batch.Finalization = pending.value.outcome
 check(result.outcome == Batch.Outcome.COMMITTED_CLEANUP_PENDING and result.verification.commit_marker_verified, "receipt cleanup preserves commit")
 var receipt_path := G + Proof.RECEIPT
 var receipt := FileAccess.get_file_as_bytes(receipt_path)
 var proof := Proof.parse(receipt, G, result.attempt_id, paths)
 check(not proof.is_empty() and Proof.paths(proof) == paths, "durable receipt")
 if proof.is_empty():
  quit(1)
  return
 check(Proof.parse(receipt, G, "11111111111111111111111111111111", paths).is_empty(), "wrong attempt")
 check(Proof.parse(receipt, G, result.attempt_id, PackedStringArray([G])).is_empty(), "wrong participant set")
 check(Proof.parse(receipt, C).is_empty(), "wrong anchor")
 check(Proof.matches(proof.participants[0], true, "new profile".to_utf8_buffer()), "expected bytes verify")
 var reverse := Plan.discover(PackedStringArray([C]))
 check(reverse.state == "pending_recovery" and reverse.participants == paths and reverse.journal_anchors == PackedStringArray([G]), "receipt reverse discovery after primary removal")
 var committed := artifacts()
 record("receipt_only", {"outcome": result.outcome, "proof": proof, "files": committed, "reason": reverse.reason})
 for wrong in ["bad profile", "short"]:
  put(C, wrong.to_utf8_buffer())
  var mismatch := Plan.discover(PackedStringArray([C]))
  check(mismatch.reason == "committed_state_mismatch", "committed byte/length mismatch")
  var blocked := artifacts()
  var retry := Ops.run_batch(paths, G, action)
  check(not retry.ran and artifacts() == blocked, "mismatch refuses write")
  record("mismatch_" + str(wrong.length()), {"reason": mismatch.reason, "files": blocked})
 put(C, "new profile".to_utf8_buffer())
 var bad := proof.duplicate(true)
 bad.participants[0].path = P
 put(receipt_path, Proof.encode(bad))
 # A caller cannot get a matching manifest for the original authorized scope.
 check(Proof.parse(FileAccess.get_file_as_bytes(receipt_path), G, result.attempt_id, paths).is_empty(), "forged participant membership refused")
 put(receipt_path, receipt)
 check(artifacts() == committed, "restore disposable probe bytes")
 var old_image := Proof.journal_image("legacy record".to_utf8_buffer(), proof.attempt)
 var changed_attempt := proof.duplicate(true)
 changed_attempt.attempt = "11111111111111111111111111111111"
 changed_attempt.uncommitted_sha256 = Proof.digest(old_image)
 check(not Proof.binds_journal(old_image, changed_attempt, false), "journal attempt binding")
 var second := "user://saves/slot_2/garden.cfg"
 var triple := PackedStringArray([C, P, second])
 check(Auth.bootstrap(PackedStringArray([second.get_base_dir()])).error == OK, "three-participant bootstrap")
 # The old receipt is disjoint from this check only after the fixture removes it.
 check(DirAccess.remove_absolute(receipt_path) == OK, "dispose test receipt")
 var multi := Ops.run_batch(triple, second, func(stage, _scope):
  for path in triple:
   check(stage.call(path, "three participants".to_utf8_buffer()) == OK, "stage participant")
  return false)
 check(multi.ran and multi.value.outcome.outcome == Batch.Outcome.COMMITTED, "no pair-only restriction")
 record("three_participants", {"paths": triple, "outcome": multi.value.outcome.outcome})
 if not failed:
  print("PASS: B2 durable evidence")
 quit(1 if failed else 0)