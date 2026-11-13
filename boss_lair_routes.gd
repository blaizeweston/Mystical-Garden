extends RefCounted
## Shared, seeded landmarks for the authoritative fight and the visible lair.
const ORCHARD := 20
const DROWNED := 21
const BANK_WIDTH := 1.25

static func supports(kind: int) -> bool:
 return kind==ORCHARD or kind==DROWNED

static func orchard_angle(seed_value: int) -> float:
 return posmod(seed_value,64)*TAU/1024.0

static func crossings(seed_value: int) -> Dictionary:
 var offset := (posmod(seed_value,7)-3)*.14
 var cross_shift := (posmod(seed_value/7,5)-2)*.18
 return {"banks":[offset-4.45,offset+4.45],"bars":[-3.0+cross_shift,5.0+cross_shift],"center":offset}

static func dry_lane(layout: Dictionary, at: Vector3) -> int:
 if absf(at.z)>10.0:return -1
 for side in 2:
  if absf(at.x-float(layout.banks[side]))<=BANK_WIDTH:return side
 return -1

static func dry(layout: Dictionary, at: Vector3) -> bool:
 if dry_lane(layout,at)>=0:return true
 if absf(at.x-float(layout.center))>6.5:return false
 for bar in layout.bars:
  if absf(at.z-float(bar))<=1.05:return true
 return false

static func bank(layout: Dictionary, side: int, z: float) -> Vector3:
 return Vector3(float(layout.banks[side]),0,clampf(z,-8.8,8.8))
