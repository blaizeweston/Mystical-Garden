# Retired class affinity and future class-choice ideas

Class affinity has been removed from active gameplay and the Garden UI. Legacy profile
slots remain neutral (zero) for save compatibility. Existing XP, learned class choices,
loadouts, cultivation and monster familiarity remain intact. A stale saved selection
cannot grant either old bonus. No replacement class bonuses were added in this change.

Ideas retained for future class-tree development:

- Steady Hands: formerly +8 percentage points to grafting success, subject to the 95%
  cap. This already overlaps existing class choices: Warden's Primal Flourish grants
  +10 points and Oracle's Deepened Warding Chime grants +8 points. Prefer these
  deliberate class-tree choices over reintroducing a universal affinity toggle.
- Wilds Scholar: formerly doubled monster-species familiarity gained on cleared
  encounters. The exact monster-familiarity bonus is not currently a class-tree choice.
  Oracle's Judgement Bell has +1 cultivation familiarity, which concerns growing plants
  rather than monster encounters. A future monster-study branch could use the retired
  idea, with costs and progression balanced against grafting bonuses.

# Seed interaction update

The Garden Altar has Identify all beside Identify seed. Batch identification preserves
all seed quantities and species, records discoveries, and saves once. Save failure
restores the entire batch and its discovery rewards.

E at an empty bed opens a seed inventory grid containing only available identified
species, with their existing portraits and quantities. Select a square to inspect name,
rarity and crafting modifiers, then confirm Plant selected seed. Cancel consumes nothing.
The server checks bed proximity, stock, empty-bed state and species bounds. A stale or
replayed request cannot overwrite a planted bed or consume an unavailable seed. A save
failure returns the seed and restores the empty bed. C at an empty bed opens the same
picker rather than silently cycling the species.

Validation covers identify-all quantities and rollback, seed grid selection and explicit
confirmation, cancellation, stale requests, save rollback and retired-affinity migration.
Existing cultivation, class, Altar, Garden-service and full solo checks are also run.
Only the latest playable EXE, Mystical Garden v0.2.exe, is replaced.
