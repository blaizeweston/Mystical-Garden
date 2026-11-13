> Current expansion: 24 species, seven class levels, 12 choices per class and 104 checkpoint cards. See [current content depth](CONTENT_DEPTH_2026-11-08.md); historical counts below describe earlier milestones.

# Two active class skills

Each class has two skills from level one. **Q** and **R** cast them in the Wilds with separate cooldowns. R still starts or infuses research in the Garden. Neither skill can be cast in the Garden. Both skill slots and countdowns appear in the lower expedition HUD and are hidden in the Garden.

| Class | Q | R | Q replacement | R replacement |
|---|---|---|---|---|
| Warden | Guard | Root Quake | Living Bastion | Briar Charge |
| Weaver | Rootbind | Spore Nova | Strangling Bloom | Mycelial Snare |
| Ranger | Gale Volley | Bramble Snare | Piercing Salvo | Windstep |
| Reaper | Reaping Step | Siphon Cut | Shadow Harvest | Blood Moon |
| Oracle | Renewal | Warding Chime | Sanctuary | Judgement Bell |

## Level-up choices
Open O → Classes at the Heart.
- Level 2: augment Q or replace it.
- Level 3: augment R or replace it.
- Level 4: further specialize the equipped Q or R skill. Mastery also works on replacements.
- Level 5: improve both cooldowns or strengthen both skills.

The existing passive benefit of each class-tree choice is retained. Upgrades remain one choice per row and cost one earned class point. Existing saved choices retain their passive bonuses and now grant the corresponding skill specialization. Refunds at the Heart restore the base skills and return the class points.

Augmentation preserves a skill's identity and improves its relevant potency, range/radius or duration, plus base cooldown. Replacement changes the skill's behavior. Catalyst and class modifiers still affect both slots; replacing a skill does not discard its applicable mastery. Guard and ward skills track finite hit charges, with expired charges cleared before a fresh cast.

## Behavior and feedback
Damage, area roots, life drain, ally healing, ally wards, line attacks and safe approaches/withdrawals are implemented. Both damage and support skills use terrain line-of-sight checks. Invalid targeted casts preserve their cooldown. Movement uses the same terrain-safe stepping as dodges. Colored cast pulses and attack gestures synchronize to other players.

Both cooldowns are sent as remaining durations, avoiding reliance on matching client/server clocks. Skill choices are derived from the existing character-owned upgrade masks, so no new per-Garden skill ownership or additional save schema is needed.

## Templates
class_catalog.gd holds each class's two base skills, two replacement definitions and eight class-tree nodes. A node's skill_change describes kind (augment, replace, master, efficient, power), slot (0 = Q, 1 = R), optional amount and optional cooldown reduction. The resolver reads these fields rather than assuming a particular node index.

skill_catalog.gd resolves the effective skill and formats descriptions. Mode handlers in game.gd implement guard, bastion, ward, bind, strangle, snare, volley, reap, windstep, charge, harvest, quake, nova, bloodmoon, snare_field, judgement, salvo, siphon, heal and sanctuary. Reuse a mode with different data to add a variant; add and test a new handler before assigning a new mode. Examples: assets/data/skill_template.json and the updated class_template.json.

The original legacy single-skill class fields remain compatible; live HUD and workbench descriptions use the resolved two-slot skills.

## Verification
tests/dual_skills.gd covers all ten starting skills, all ten replacements, augments, independent cooldowns, normal R-key context, terrain cover, Catalyst effects, expired ward charges, HUD state and save round trips. tests/dual_skills_coop.gd covers portable replacement choices, both remote skill requests, relative cooldowns, enemy damage/rooting, party healing/wards and cast effects.

Build validation: dedicated skill tests, class/weapon tests, seed progression, HUD, tree interaction, health, Garden and save-slot checks passed. The full solo and host/guest campaign checks passed, as did the dedicated two-skill co-op scenario. Rendered both active skill slots, replacement names, cast effects, cooldowns and Garden hiding.

The rebuilt release pack passed a runtime check of independent Q/R casts, a replacement/augmentation build, damage/rooting, cooldown HUD, workbench and class-tree descriptions. The executable passed startup (exit 0). Mystical Garden v0.1.exe is updated. Source backups: docs/change-backups/dual-skills-20261107-192403. The prior executable is preserved in the Codex workspace work/change-preview/Mystical Garden v0.1-before-dual-skills.exe. Testing used isolated saves.
