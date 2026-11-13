extends RefCounted
# A small outcome policy, not a second plant/loot catalog. Stable IDs may be extended.
const VERSION:=1
const DEFINITIONS: Array=[{
 "id":"patient_bud","name":"An unusual bud","stage":2,
 "delay_fraction":.20,"rare_bonus":.15,"rare_cap":.60,
 "description":"A tightly folded bud holds a richer vein of sap. Let it mature normally, or give it more time to develop."
},{
 "id":"deep_bud","name":"A deep-veined bud","stage":2,
 "delay_fraction":.40,"rare_bonus":.25,"rare_cap":.70,
 "description":"A slow pulse of water gathers in a deep-veined bud. Preserve it for a stronger rare-material chance at the cost of longer growth."
}]
static var signature: String=var_to_str(DEFINITIONS).sha256_text()
static func definition(id: String) -> Dictionary:
 for entry in DEFINITIONS:
  if entry.id==id:return entry
 return {}
static func errors() -> Array[String]:
 var result: Array[String]=[];var ids: Array=[]
 for entry in DEFINITIONS:
  if str(entry.get("id","")).is_empty() or ids.has(entry.id):result.append("Invalid/duplicate crop opportunity")
  ids.append(entry.id)
  if int(entry.get("stage",-1)) not in [1,2]:result.append("Care must precede maturity")
  for field in ["delay_fraction","rare_bonus","rare_cap"]:
   if not entry.has(field) or float(entry[field])<0 or float(entry[field])>1:result.append("Invalid care policy: "+field)
 return result
