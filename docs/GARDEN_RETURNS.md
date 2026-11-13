# Garden return discoveries and responsive life

G-05 and the remainder of G-06 share one committed outcome boundary. The first authored example is **A lantern brought home**: safely bank an ordinary Lantern Moss mystery seed from the Wilds, then identify that species at the Altar. A previously known species is eligible so established Gardens can experience the new event. Old stash contents alone do not fabricate an expedition history.

The discovery grows pale root blooms at the existing old root scar. Its optional scene follows a root from the Heart to the scar. Six moths gather there; the sheltered spring gains subtle answering rings when unlocked, and the Heart's ground filaments answer slightly out of rhythm. This preserves a peaceful home and an ambiguous Heart. It does not activate the deferred ending.

## Authorities and reuse

| Boundary | Owner |
|---|---|
| Authored discovery/species/anchor/text | `garden_return_catalog.gd` |
| Run identity, member/source receipts, verified bank credit, one-time discovery | `garden_return_state.gd` |
| Existing gameplay hooks and privacy-filtered projection | `garden_return_service.gd` |
| Banking, loss and identification | Existing inventory/run/Altar services; not replaced |
| Committed event and per-viewer acknowledgement | Existing Garden growth state/service/scene queue |
| Read-only recap | `garden_story_panel.gd`, under Heart → Garden care → Garden stories |
| Root blooms/Heart filaments | `garden_return_view.gd` |
| Moths/water | Existing bounded Garden ambience and water shader |

The host creates a cryptographic run ID at actual departure, with stable character-member keys and source receipts. It does not consume gameplay RNG. The namespace is an additive Dictionary included in existing save transactions and old-save defaults. Failed saves restore loot and discovery state together. Failed return transactions also restore the mutable battlefield layout for retries. Malformed/future return schema versions are not executed or downgraded. Starting a new run closes unfinished old members as interrupted without inventing bank credit.

**Credit is intentionally world-level and species-fungible.** Successfully banking a species verifies that the host world received that find. Any player's later identification of that species may produce the authored discovery. Mystery stacks are interchangeable and transferable; this does not claim to track a particular physical seed. Importing/crafting/holding an unverified seed alone cannot establish credit. A legitimate earlier checkpoint deposit remains banked even if the rest of the expedition is abandoned.

## Banking and loss rules

| Outcome/source | Discovery credit |
|---|---|
| Extraction | Actual carried seeds and safe-pouch seeds banked by existing operations |
| Wipe/fallen extraction/disconnect | Only contents actually recovered from the safe pouch |
| Courier checkpoint deposit | That successfully banked seed; one receipt per member/checkpoint |
| Ancient mystery seed | Existing extracted/protected ancient source, actual species resolved on identification |
| Abandonment | No credit for lost carried or pouch contents; earlier banked deposits remain legitimate |
| Old save/stash | Empty new metadata; no inferred historical expedition or automatic reward |

Credit alone reveals nothing. Only successful identification records a matching authored discovery. There is **no extra item, XP, Knowledge, research advancement or enemy-adaptation RNG draw** from the discovery, scene, recap, moths or water response. The existing identification reward remains unchanged. Identifications by multiple party members still produce one discovery and one presentation event per host world.

Raw run/member/credit data stays in the host save. The guest projection carries only catalog-checked authored entries already discovered. Rejoining uses stable viewer acknowledgements; skipping for one viewer does not dismiss anyone else's scene. Late arrivals see the changed Garden and recap without playing historical awards. Optional pending scenes reuse existing preparation/travel suppression and party readiness; they introduce no ready vote.

## Bounds and presentation

- Last 32 run summaries; one active run; one credit per supported species/ancient source; stable discovery IDs.
- Existing 64-event growth queue and per-viewer seen state; recap displays the last 12 authored entries.
- One existing moth family, at most 8 per colony, currently 8 at the spring plus 6 at the return trace. Distance, Garden visibility and local ambient-motion settings still apply. Switching worlds hides stale colonies.
- Root/water updates are throttled local cosmetics with no colliders, per-frame RPCs or save writes. Scene completion grants nothing.

## Add another discovery

1. Add a stable definition referencing an existing stable species and interaction anchor. Catalog validation rejects duplicates and missing references. New placement requires the existing layout/clearance rules.
2. Reuse the bank/identify fact boundary; do not infer identity from unidentified inventory for a hint. A genuinely different trigger needs a small explicit service/policy and transaction coverage.
3. The saved discovery, queue, private projection and recap consume definitions automatically. Distinct art/ecological responses need a bounded view adapter; the first response is deliberately authored rather than a generic visual scripting framework.
4. Add tests for the trigger, source/loss rules, failed saves, duplicate party intents, old saves and guests. Extend `garden_returns` and its connected consumers in the interaction map. All co-op builds need the updated catalog fingerprint.

## Validation

`garden_returns` covers real departure/extraction/identification, failed-save rollback, abandonment, safe-pouch wipe recovery, reload, reward/RNG invariance, formation/skip/recap, late viewers, four-member deduplication, bounded summaries and future-version preservation. `garden_returns_coop` runs real host/guest admission, party banking, concurrent identification, hidden provenance, independent acknowledgement and reconnect. Existing affected banking, inventory, Altar, Garden, research, readiness and network checks supplement these. Source/package evidence is recorded in the milestone handoff after release validation. Rendered formation, inspection and story views were reviewed at 1280×720; the renderer error log is empty.

Release evidence (2026-11-10): connected `20261110-151546-c88e7f52` passed 29 selected/64 reused; package passed 20 selected/40 reused plus startup and real host/three-guest smoke. Installed v0.5.2.0 SHA256 `02c7d1898565349cb72d18cd2639869d4dbd973fe5d82a24f9d5a8a13ebd4054` matches the verified package. See `.godot/g05-connected.log`, `.godot/g05-package.log`, and the canonical milestone handoff. Only the highest EXE was replaced, with a timestamped prior-EXE backup; the protected pre-cleanup checkpoint was not accessed. G-05/G-06 are Complete; G-07 is Ready.
