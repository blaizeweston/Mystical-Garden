extends Node
# Runs before SceneMultiplayer exposes peers or accepts any scene RPCs.
const Contract=preload("res://network_contract.gd")
const Settings=preload("res://network_settings.gd")
const Experiment=preload("res://assets/terrain_m02/experimental/experiment_mode.gd")
const UPDATE_MESSAGE="Multiplayer compatibility check failed. Both players must use the same updated game build."
var signature: String
var failure_reason: String=""

func _ready() -> void:
 signature=Contract.signature(get_parent().get_script().get_script_method_list())
 # The host publishes the party roster. Engine peer-to-peer roster relays
 # can target a transport already disconnected during a simultaneous leave.
 if Experiment.active(get_parent()): multiplayer.server_relay=false
 multiplayer.auth_callback=receive_compatibility
 multiplayer.auth_timeout=Settings.REGISTER_TIMEOUT_MS/1000.0
 multiplayer.peer_authenticating.connect(begin_check)
 multiplayer.peer_authentication_failed.connect(check_failed)

func begin_check(id: int) -> void:
 if get_parent().network_session.role()=="Connecting":
  get_parent().network_session.compatibility_started()
 preload("res://diagnostic_journal.gd").event("network","compatibility_started",{"actor":id,"protocol":Settings.PROTOCOL,"signature":signature})
 failure_reason=""
 var payload: Dictionary={"game":"mystical-garden","protocol":Settings.PROTOCOL,"contract":signature,"terrain":preload("res://battlefield.gd").SIGNATURE,"garden":preload("res://garden_return_catalog.gd").signature,"cultivation":preload("res://cultivation_growth.gd").signature}
 payload.hp_per_point=get_parent().Life.Preview.scale()
 payload.experimental_terrain=Experiment.network_identity(get_parent())
 var ruleset := preload("res://combat_ruleset.gd").network_identity(get_parent())
 if not ruleset.is_empty(): payload.combat_ruleset = ruleset
 multiplayer.send_auth(id,JSON.stringify(payload).to_utf8_buffer())

func receive_compatibility(id: int,data: PackedByteArray) -> void:
 var payload=JSON.parse_string(data.get_string_from_utf8()) if data.size()<=1024 else null
 if signature.is_empty() or not payload is Dictionary or payload.get("game")!="mystical-garden" or payload.get("protocol")!=Settings.PROTOCOL or payload.get("contract")!=signature or payload.get("terrain","")!=preload("res://battlefield.gd").SIGNATURE or payload.get("garden","")!=preload("res://garden_return_catalog.gd").signature or payload.get("cultivation","")!=preload("res://cultivation_growth.gd").signature:
  preload("res://diagnostic_journal.gd").event("network","compatibility_rejected",{"actor":id},"warning")
  failure_reason=UPDATE_MESSAGE
  multiplayer.disconnect_peer(id)
  return
 var combat_mode = preload("res://combat_ruleset.gd")
 if payload.get("combat_ruleset", "") != combat_mode.network_identity(get_parent()):
  preload("res://diagnostic_journal.gd").event("network","compatibility_rejected",{"actor":id,"reason":"combat_ruleset"},"warning")
  failure_reason = combat_mode.MISMATCH
  if not multiplayer.is_server(): finish_failed_check.call_deferred(get_parent().network_session.session_identity())
  return
 if payload.get("experimental_terrain","")!=Experiment.network_identity(get_parent()):
  failure_reason="Everyone must use the same experimental terrain build."
  if not multiplayer.is_server(): finish_failed_check.call_deferred(get_parent().network_session.session_identity())
  return
 if int(payload.get("hp_per_point",0))!=get_parent().Life.Preview.scale():
  preload("res://diagnostic_journal.gd").event("network","compatibility_rejected",{"actor":id,"reason":"health_scale"},"warning")
  # Keep the peer unauthenticated while it reads our handshake and shows the reason.
  if not multiplayer.is_server():
   failure_reason="Everyone must use the same current combat build and health scale."
   finish_failed_check.call_deferred(get_parent().network_session.session_identity())
  return
 preload("res://diagnostic_journal.gd").event("network","compatibility_accepted",{"actor":id})
 multiplayer.complete_auth(id)

func check_failed(id: int) -> void:
 var game:=get_parent()
 if game.network_session.role()!="Connecting" or id!=1: return
 if failure_reason.is_empty(): failure_reason=UPDATE_MESSAGE
 finish_failed_check.call_deferred(get_parent().network_session.session_identity())

func finish_failed_check(attempt: String) -> void:
 var game:=get_parent()
 # A queued failure belongs to the connection that scheduled it.
 if game.network_session.session_identity()!=attempt: return
 if game.network_session.role()=="Connecting": game.connection_rejected(failure_reason)

func _exit_tree() -> void:
 if multiplayer.auth_callback==receive_compatibility: multiplayer.auth_callback=Callable()
