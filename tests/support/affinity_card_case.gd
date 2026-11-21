extends RefCounted
const Build=preload("res://affinity_build.gd")
const Cards=preload("res://affinity_cards.gd")
const Catalog=preload("res://affinity_card_catalog.gd")
const Events=preload("res://combat_action_events.gd")
const Clock=preload("res://affinity_time.gd")
const Expedition=preload("res://tests/support/expedition_case.gd")
var game: Node
var serial:=0
func create(tree: SceneTree) -> void:
 game=load("res://world.tscn").instantiate();tree.root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.battlefield.configure(0,1,0)
 preload("res://tests/support/terrain_case.gd").walls(game.battlefield,[])
 for peer in [2,3,4]:game.add_player(peer)
 Expedition.set_world(game,{"run_id":41,"combat_epoch":1,"encounter_number":1})
 for player in game.players.values():
  preload("res://tests/support/session_case.gd").set_ready(game,player,true)
  Expedition.set_membership(game,player,true)
 reset()
func reset() -> void:
 game.encounter.set_hp(-1,1000000);game.encounter.clear_scouts()
 game.tactics.memory.clear();game.tactics.position=Vector3(0,0,-2);game.tactics.boss_kind=-1
 game.enemy_mutations=0;game.set_meta(Clock.CLOCK,0.0)
 if game.has_meta(&"affinity_thorn_fields"):game.remove_meta(&"affinity_thorn_fields")
 for p in game.players.values():
  p.weapon=0;p.secondary=0;p.catalyst=0;p.frame=2;p.weapon_kind=0;p.pos=Vector3.ZERO;p.facing=Vector3.FORWARD
  p.character=game.Character.blank()
  var tree=game.Classes.connected_tree(2);p.character[tree.profile_key]=tree.state(["wildstalker"])
  for key in [Cards.STATE,"thorn_card_momentum","thorn_card_streak","card_active_state","affinity_thorn_form_ready"]:p.erase(key)
func equip(peer: int, family: String, slots: Array=["core","form","catalyst"]) -> void:
 var part:=0
 for index in range(1,Build.Materials.DEFINITIONS.size()):
  if Build.Affinities.for_part(index).get("primary_affinity")==family:part=index;break
 for slot in slots:game.players[peer][{"core":"weapon","form":"secondary","catalyst":"catalyst"}[slot]]=part
func own(peer: int, ids: Array, grade:=0) -> void:
 var copies: Array[Dictionary]=[]
 for id in ids:
  serial+=1
  var d: Dictionary=Catalog.DEFINITIONS[id]
  copies.append({"id":id,"amount":d.fixed if d.policy=="unique" else d.values[grade],"rarity":"" if d.policy=="unique" else Catalog.RARITIES[grade],"floor":1,"acquisition_id":serial})
 game.players[peer][Cards.STATE]=Cards.Ledger.new(copies)
func action(peer: int, slot: String) -> RefCounted:
 var p: Dictionary=game.players[peer]
 var build: Dictionary=game.combat_build(p).affinity_build()
 var material: Dictionary=build[slot]
 return Events.begin(game,peer,slot,material,material.potency_profile.values,["core_action","weapon_contact","class_contact","class_action","actual_block"],0x7fffffffffffffff)
func scout(point: Vector3,hp:=10000) -> int:
 var source: Dictionary=game.make_scout(0,point,1);source.hp=hp
 return game.encounter.register_scout(source)
