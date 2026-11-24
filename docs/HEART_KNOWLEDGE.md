# Heart and Knowledge progression

The host can purchase research at the Heart between expeditions. Select a technology to see its benefit, prerequisites, lifetime Knowledge threshold and purchase price. Available Knowledge equals lifetime Knowledge earned minus the amount spent. Purchasing an eligible node unlocks it immediately for the whole Garden. Flowering is free and requires an explicit selection.

Six bed unlocks take a Garden from three to nine universal planting beds. Place an unlocked bed through Build. Reaching Roots opens frontier expansion. Root Irrigation lets players fill a vessel at terrain water and improves crop growth by 20%. Symbiotic Nursery raises the growth bonus to 40%. Crop growth, watering and Patient Bud keep their own timing. The other technologies retain their station, cargo, conduit and guardian-memory benefits. The Living Archive still requires its other prerequisites and recorded guardian victories still determine its three Remembrances.

## Material contributions

The host can contribute available shared plant and monster parts at the Heart. The preview lists the selected materials and both rewards. Each unit pays the following amounts immediately. Equipped and otherwise reserved materials remain protected.

| Item rarity | Growth Energy | Knowledge |
|---|---:|---:|
| Common | 2 | 1 |
| Uncommon | 3 | 2 |
| Rare | 3 | 3 |
| Epic | 4 | 4 |
| Mythic | 4 | 5 |

Growth Energy pays for physical expansion. Earning Knowledge increases both lifetime and available Knowledge. Field Study trophy rewards, identification, altar recipes and crafting keep their separate rules.

## Existing Gardens

Paid unfinished technologies become unlocked on load. Research Infusion has been retired. Its recorded debit is returned to available Knowledge, up to five points, while preserving spending on supported technologies. Lifetime Knowledge receives no refund credit. Unfinished material batches award their outstanding Knowledge. Their Growth Energy and material deductions already took effect in the old version. The next normal save preserves the original file as a migration backup and writes the converted state.

Edit technologies in [heart_catalog.gd](../heart_catalog.gd) and contribution values in [garden_offerings.gd](../assets/terrain_m02/garden_offerings.gd). Purchase validation, persistence and focused tests are listed in [Heart research and offerings](ARCHITECTURE.md#heart-research-and-offerings-hg01).
