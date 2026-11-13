# Independent character roster

The main menu now separates character and Garden selection. Three initial character slots support named travellers, starting classes, and live customization of cloak, tunic, hair color, hairstyle and skin. Class progression and familiarity stay with the selected character when opening different Gardens or joining a host.

Existing per-world characters are copied automatically without changing their permanent identities, earned progress or source files. World replacement/deletion preserves the independent roster. Character and world session locks are separate; joining claims only the character. Failed joins and disconnects return to the menu without saving over a selected local world.

The roster has a persisted capacity and a scrollable layout. Its initial three slots can expand independently of world slots through character_slots.gd.set_capacity. This does not change existing host-world seed/material ownership or add portable seed transfer.

Validation includes the new character_roster suite, updated start-menu/deletion tests, full source regression, and local host/guest menu selection. Visual checks cover the 1100×720 main menu and creator preview. Only the highest numbered EXE is updated by the release tool; earlier revisions remain preserved.
