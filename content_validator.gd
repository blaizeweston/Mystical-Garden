extends RefCounted
const Seeds=preload("res://seed_catalog.gd")
const Parts=preload("res://weapon_parts.gd")
const Classes=preload("res://class_catalog.gd")
const Enemies=preload("res://enemy_catalog.gd")
const Motion=preload("res://weapon_motion.gd")
const Cards=preload("res://affinity_card_catalog.gd")
const MODES: Array=["guard","front_guard","counter_guard","bastion","ward","bind","strangle","snare","volley","reap","windstep","charge","harvest","quake","nova","bloodmoon","snare_field","judgement","salvo","siphon","heal","sanctuary","growth","bloom_detonate","requiem"]
const Effects: Array=["reach","damage","windup_damage","cooldown","recovery","pull","knockback","stagger","heal_on_kill","skill_heal","max_health","skill_cooldown","skill_duration","dodge_cooldown","graft_chance","targets","familiarity","power","technique"]
static func effect_errors(effects: Dictionary,label: String) -> Array[String]:
 var errors: Array[String]=[]
 for key in effects:
  var base: String=str(key).trim_suffix("_step")
  if not Effects.has(base) and not preload("res://combat_traits.gd").KEYS.has(base): errors.append(label+": unsupported effect "+str(key))
  if not (effects[key] is int or effects[key] is float or effects[key] is bool): errors.append(label+": nonnumeric effect "+str(key))
 return errors
static func unique(entries: Array,label: String) -> Array[String]:
 var errors: Array[String]=[];var seen: Array=[]
 for entry in entries:
  var id:=str(entry.get("id",""))
  if id.is_empty() or seen.has(id): errors.append(label+": empty or duplicate ID "+id)
  seen.append(id)
 return errors
static func validate() -> Array[String]:
 var errors: Array[String]=[];errors.append_array(preload("res://garden_interaction_catalog.gd").errors());errors.append_array(unique(Seeds.DEFINITIONS,"seed"));errors.append_array(unique(Parts.DEFINITIONS,"part"));errors.append_array(unique(Classes.DEFINITIONS,"class"));errors.append_array(unique(Enemies.all(),"enemy"))
 errors.append_array(preload("res://plant_affinities.gd").errors())
 var pairs: Array=[]
 for i in Seeds.DEFINITIONS.size():
  var species_id: Dictionary=Seeds.DEFINITIONS[i];errors.append_array(effect_errors(species_id.effects,"seed "+str(species_id.id)))
  if not ResourceLoader.exists("res://assets/ui/seeds/"+str(species_id.id)+".png"): errors.append("Missing seed portrait "+str(species_id.id))
  if int(species_id.part)<1 or int(species_id.part)>=Parts.DEFINITIONS.size() or Parts.plant_source(int(species_id.part))!=i: errors.append("Seed/component mapping mismatch "+str(species_id.id))
  if species_id.parents.size()==2:
   var sorted: Array=species_id.parents.duplicate();sorted.sort();var signature:=str(sorted)
   if pairs.has(signature): errors.append("Ambiguous parent pair "+signature)
   pairs.append(signature)
   for parent in species_id.parents:
    if int(parent)<0 or int(parent)>=Seeds.DEFINITIONS.size(): errors.append("Missing parent "+str(species_id.id))
    elif int(Seeds.DEFINITIONS[int(parent)].tier)>=int(species_id.tier): errors.append("Invalid lineage tier "+str(species_id.id))
 for class_id in Classes.DEFINITIONS.size():
  var c: Dictionary=Classes.DEFINITIONS[class_id]
  # Historical masks remain validated as data, never as an alternate combat tree.
  var nodes: Array=Classes.all_nodes(class_id)
  var tree=Classes.connected_tree(class_id)
  if tree==null or tree.nodes.size()!=18:
   errors.append("Class requires three focuses and five connected tiers: "+str(c.id))
  else:
   errors.append_array(unique(tree.nodes,"connected node "+str(c.id)))
   for active_node: Dictionary in tree.nodes:
    for parent: String in active_node.parents:
     if tree.node(parent).is_empty(): errors.append("Missing connected parent "+parent)
  if nodes.size()>63: errors.append("Class exceeds 63 learned-node capacity "+str(c.id))
  errors.append_array(unique(c.weapons,"weapon "+str(c.id)));errors.append_array(unique(nodes,"node "+str(c.id)))
  for weapon in c.weapons:
   if not Motion.PROFILES.has(weapon.visual): errors.append("Missing weapon motion "+str(weapon.id))
   if not preload("res://core_skill_rules.gd").WEAPON_DELIVERY.has(weapon.visual): errors.append("Missing Core delivery "+str(weapon.id))
   if weapon.pattern not in ["single","line","sweep","splash","chain"]: errors.append("Unknown attack pattern "+str(weapon.id))
  for kit in ["base"]:
   if c.skills.get(kit,[]).size()!=2: errors.append("Class must have two skills: "+str(c.id))
   for skill in c.skills.get(kit,[]):
    if not MODES.has(skill.get("mode","")): errors.append("Unsupported skill mode: "+str(c.id))
  for node in nodes:
   var change: Dictionary=node.get("skill_change",{})
   if change.get("kind","") not in ["","augment","replace","master","power","efficient","modify"]: errors.append("Unsupported skill change "+str(node.id))
   if change.get("kind","")=="modify":
    if int(change.get("slot",-1)) not in [0,1] or not MODES.has(change.get("values",{}).get("mode","")): errors.append("Invalid specialized skill "+str(c.id)+":"+str(node.id))
   errors.append_array(effect_errors(node.effects,"class node "+str(node.id)))
   for parent in node.get("parents",[]):
    var found:=false
    for candidate in nodes:
     if candidate.id==parent: found=true
    if not found: errors.append("Missing class parent "+str(parent))
 for focus in Classes.Warden.FOCUSES.values():
  if not MODES.has(focus.mode):errors.append("Unsupported Warden subclass skill "+str(focus.name))
 var subclass_clips: Dictionary=preload("res://subclass_combat.gd").CLIPS
 for group in Classes.Subclasses.FOCUSES:
  for focus in group:
   if focus.shape not in ["target","ground","line","self","retreat","dash","cone"] or not subclass_clips.has(focus.visual):
    errors.append("Invalid subclass shape or animation "+str(focus.id))
   if focus.mode!="subclass" or (focus.shape=="line" and float(focus.get("width",0))<=0.0) or (focus.shape!="line" and float(focus.get("radius",0))<=0.0):
    errors.append("Invalid subclass skill "+str(focus.id))
 var published_order=JSON.parse_string(FileAccess.get_file_as_string("res://assets/content/part_order.json"))
 if not published_order is Array or published_order.size()!=Parts.DEFINITIONS.size(): errors.append("Published component order does not cover registry")
 elif published_order!=Parts.DEFINITIONS.map(func(part):return str(part.id)): errors.append("Component order changed outside append-only contract")
 # Only the current catalog executes. Historical card ranks were run-only.
 var requirement_errors := preload("res://card_eligibility.gd").catalog_errors()
 for card_id: String in requirement_errors:
  errors.append("Card requirements " + card_id + ": " + requirement_errors[card_id])
 for card_id: String in Cards.DEFINITIONS:
  var card: Dictionary=Cards.DEFINITIONS[card_id]
  for field in ["title","trigger","description","detail","parameter"]:
   if str(card.get(field,"")).is_empty(): errors.append("Card missing "+field+": "+card_id)
  if card_id.is_empty() or card.get("scope","") not in ["core","form","catalyst","class","weapon","general","affinity"]: errors.append("Invalid card identity/scope "+card_id)
  if card.get("policy","") not in ["stackable","unique"] or int(card.get("limit",0))<1: errors.append("Invalid card acquisition policy "+card_id)
  if card.get("unit","") not in ["charges","targets","hp","healing_hp","capacity_hp","regen_hp","basis_points","pressure","bark","fragments","penetrations","ms","stacks","percent","cm","unlock","milli_stacks"] or not card.get("requires") is Dictionary: errors.append("Invalid card units/requirements "+card_id)
  if card.get("policy")=="unique":
   if int(card.get("limit",0))!=1 or int(card.get("fixed",0))<=0: errors.append("Invalid Unique card contribution "+card_id)
  elif card.get("values",[]).size()!=Cards.RARITIES.size(): errors.append("Card must author one contribution per rarity "+card_id)
  var consumer: Array=card.get("consumer",[])
  if consumer.size()!=2 or not ResourceLoader.exists(str(consumer[0])):
   errors.append("Missing card consumer "+card_id)
  else:
   var script: Script=load(str(consumer[0]))
   if script==null or not script.get_script_method_list().any(func(method):return str(method.name)==str(consumer[1])): errors.append("Unknown card consumer "+card_id)
 var boss_count:=0
 for kind in Enemies.all().size():
  var entry: Dictionary=Enemies.get_kind(kind)
  if Parts.MONSTER_DEFINITIONS.size()<=kind or int(Parts.DEFINITIONS[Parts.monster_part(kind)].get("monster",-1))!=kind: errors.append("Missing trophy mapping "+str(entry.id))
  if entry.get("boss",false):
   boss_count+=1
   if entry.get("moves",[]).size()<3 or str(entry.get("lair","")).is_empty(): errors.append("Incomplete boss template "+str(entry.id))
  if entry.role not in ["swipe","volley","charge","chant","pounce","snare","stomp","artillery","brood","skirmish","shepherd","lure"]: errors.append("Unknown enemy role "+str(entry.id))
  if not ResourceLoader.exists("res://assets/enemies/"+str(entry.id)+".glb"): errors.append("Missing enemy model "+str(entry.id))
 if boss_count!=4: errors.append("Expected four expedition bosses")
 errors.append_array(preload("res://enemy_balance.gd").errors(Enemies.all()))
 var combat=preload("res://game_balance.gd").values.get("combat",{})
 for field in ["base_scouts","coop_extra_scouts","floors_per_extra_scout","leader_base_hp","floors_per_leader_hp","scout_base_hp","floors_per_scout_hp","coop_hp_multiplier","coop_hp_per_floor","coop_hp_depth_cap","aggro_radius","group_alert_radius","spawn_entry_clearance","speed_multiplier","speed_per_floor","speed_cap","minimum_windup_ms","trophy_chance","trophy_depth_step","trophy_depth_cap","trophy_guardian_bonus","trophy_adapted_bonus","trophy_cap","hit_grace_ms","kill_essence_sparks","leader_essence_sparks","essence_sparks_per_point","kill_class_xp","leader_class_xp"]:
  if not (combat.get(field) is int or combat.get(field) is float): errors.append("Missing/nonnumeric combat balance field "+field)
 for field in ["floors_per_extra_scout","floors_per_leader_hp","floors_per_scout_hp","speed_cap","leader_base_hp","scout_base_hp","essence_sparks_per_point"]:
  if float(combat.get(field,0))<=0: errors.append("Combat balance field must be positive: "+field)
 if int(combat.get("base_scouts",0))<1 or int(combat.get("base_scouts",0))>preload("res://encounter_config.gd").MAX_SCOUTS: errors.append("Combat spawn budget exceeds protocol capacity")
 if float(combat.get("trophy_chance",0))<0 or float(combat.get("trophy_cap",2))>1 or float(combat.get("trophy_cap",0))<float(combat.get("trophy_chance",1)): errors.append("Invalid trophy probability bounds")
 if float(combat.get("minimum_windup_ms",0))<300: errors.append("Enemy telegraph budget is too short")
 if Enemies.all().size()>65536: errors.append("Enemy count exceeds protocol capacity")
 return errors
