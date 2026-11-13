# Player interface art
The user's supplied Hearts Textures.png provides the health icon designs.
PlayerHUD.png is a visual reference for dark interiors, brown interwoven root borders and ochre highlights.
Reference copies are preserved in assets/source/ui.

Built-in image generation was used to prepare these project assets:
- assets/ui/hearts.png: transparent four-state health atlas, used via AtlasTexture regions.
- assets/ui/root_frame.png: reusable empty illustrated root frame. Nine-slice rendering preserves its corners across HUD and inventory sizes.

Final prompts
Hearts: "Extract the four heart icons from this provided image into a clean transparent game sprite sheet. Preserve the provided artwork and its four states: glossy intact red, glowing fractured red, dark cracked, depleted gray cracked. Remove ALL background completely with true transparent alpha. Four hearts equally sized and centered in FOUR equal square cells in ONE horizontal row, tightly framed with 8 percent padding, aligned centers and baseline. No text, no new elements. Wide 4:1 image. These are actual health HUD icons for a game, preserve readable silhouettes."

Root frame: "Use supplied PlayerHUD image ONLY as style inspiration for a new reusable game UI panel texture. Generate a SINGLE SQUARE nine-slice panel frame: thin interwoven brown woody root border with muted antique ochre highlights, tiny subtle moss flecks, organically uneven but overall rectangular perimeter. Deep nearly black forest brown opaque interior, calm flat empty center. Frame border restricted to outermost 8 percent of square on all four sides, corners have slightly thicker intertwined roots. Transparent OUTSIDE irregular silhouette only. No text, no symbols, no hearts, no slots, no gems, no icons, no extra panels, no background scene. Real illustrated bark detail like reference, restrained dark fantasy. This single empty frame will be stretched via nine-slice for health panel, ability slots and inventory. Keep long edges straight and quiet enough to tile/stretch; no giant branches protruding into center."

root_ui.gd draws live health, combat readiness, seed/pouch counts and expedition essence. I opens the matching inventory. Resource counts reflect existing game systems; no new mana or stamina mechanic is introduced.
