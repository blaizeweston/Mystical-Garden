extends RefCounted
# Independent tuning knobs; changing checkpoint spacing never changes biome length.
const UPGRADE_INTERVAL:=3
const EXTRACTION_INTERVAL:=6
const CHECKPOINT_INTERVAL:=UPGRADE_INTERVAL # Compatibility name for upgrade checkpoints.
const BIOME_LENGTH:=6
const GRAFT_INTERVAL:=8
const SOLO_SCOUT_LIMIT:=12
const MAX_SCOUTS:=20
const PACK_STRIDE:=8
const CAMPAIGN_HEADER:=19
const LANDING_X:=CAMPAIGN_HEADER+MAX_SCOUTS
const LANDING_Z:=LANDING_X+1
const ATTACK_MODE:=LANDING_X+2

const BOSS_KIND:=ATTACK_MODE+1
const BOSS_PHASE:=BOSS_KIND+1
