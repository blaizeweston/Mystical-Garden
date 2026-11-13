# Garden care and deferred ending

Updated 9 November 2026.

- Garden care retains seed reclamation and monster research. Shared-part transfers are handled only by the inventory options; the duplicate dropdown/button and empty Tending page were removed. Their pages use explicit containers instead of depending on child indices.
- Planting beds are unlocked by selecting their nodes in Heart / Knowledge and completing research. The former one-button/keyboard/network expansion shortcut cannot start or pay for a project.
- The old Pale Root / Lantern Bud / Hollow Seedling offshoot feature and its finale are deferred. Guardian clears no longer generate choices; tending, sacrifice, growth rewards and awakening requests are inactive. The final research node and narrative/ending prompts are hidden. Normal Heart growth, memories, Garden technologies and Wilds progression remain active.
- Legacy offshoot states, bed assignments, growth counters, ending records and earned research remain serialized for compatibility. They do not reserve beds, create scenery, darken the Garden or block planting. Previously reserved beds can grow ordinary plants. Saved in-progress final research is paused; paid work is retained. Legacy final Heart growth displays the remembering phase rather than awakening.
- The 24 published Heart technology IDs remain stable; the tree currently displays 23 active nodes. Perfect Recollection remains an archival ID, not a purchasable node.
- Heart / Knowledge opens at the base after its visible layout settles, with the Heart root centered. This applies to opening from the Heart, reopening the panel and returning from another tab. Normal research refreshes preserve manual scrolling.
- Multiplayer protocol 14 prevents mismatched clients from restoring the retired controls. Authority, public Garden snapshots and guest menus use the same rules.

Legacy ending combat fixtures are archived under `docs/archives/legacy_endings`. Current `garden_cleanup` and `garden_cleanup_coop` suites cover retired-command rejection, Knowledge-only bed research, legacy save preservation, planting in formerly reserved beds, guest state, and bottom anchoring. Rendered menu checks use the actual game UI.
