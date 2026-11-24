# Gate cadence and weapon preparation

Updated 9 November 2026.

- Upgrade cards appear after clearing gates **3, 6, 9, 12, ...**. Choose or skip before travelling onward. Existing three-card offers and the rare fourth card remain unchanged.
- Full extraction is offered only at cleared gates **6, 12, 18, ...**, beside the onward gate. Upgrade gates 3, 9 and 15 do not advertise or accept extraction. The Heart finale is excluded from both schedules.
- Upgrade and extraction intervals are independent constants in `encounter_config.gd`. Biome length remains six encounters. Returning Root deposits are available at discovered roots, including during combat. Gate clearance only affects upgrades and extraction.
- Each weapon dropdown lists only plant materials with copies available for that slot. Materials assigned to the other two slots are subtracted; the current slot retains its own assigned copy. Empty remains selectable.
- Selecting or removing a part updates the other dropdowns immediately, including for guests waiting for the host. Multiple copies allow repeated components up to the actual quantity.
- The host validates the same availability rule for menu and keyboard selections. The stash is consumed only on confirmed departure; party-wide departure cost checks remain atomic.
- Saved plans that exceed current stock are reduced to affordable selections when opening the gate workbench or switching classes there. Monster cargo options also subtract copies already in the cargo plan.
- Multiplayer protocol 13 keeps old clients with the previous gate/crafting rules from joining this build.

Regression coverage includes the actual six-gate route with its third-gate card stop, independent gate schedules through gate 36, both directions of slot reservation, duplicate stacks, host rejection of stale/forged selections, immediate guest filtering and live inventory changes. Existing solo, party readiness and four-player traversal tests use the new cadence.
