# Character models and creation

The main menu offers three character slots, with expandable roster capacity. Empty slots open Create Character; occupied slots open Customize. Customization retains the character identity, combat experience, plant familiarity, learned choices and loadouts. Active profiles remain locked.

Both clothed traveller models share 25 joints and six Blender-authored clips: Idle, Walk, Run, Attack, Cast and Guard. Runtime combat retains weapon-specific upper-body offsets and contact timing. Weapons attach to the right-hand bone. Cosmetic proportions never alter collision, damage or attack reach.

Appearance retains the original five categorical entries (cloak, tunic, hair color, hairstyle, skin), followed by model (0 male, 1 female) and seven integer sliders: height, build, shoulders, face width, jaw, nose and eye size. Sliders use 0–100, neutral 50. Height is bounded to 92–108%; the other six use blend shapes. Old five-value saves receive neutral defaults. The same normalized array is saved and transmitted as compact bytes; multiplayer protocol 4 requires matching builds.

Authoritative editable source: assets/source/travellers.blend. Rebuild both GLBs with Blender in background using tools/make_travellers.py. Runtime files are assets/characters/traveller_male.glb and traveller_female.glb. rig_manifest.json documents bone and morph names. Legacy adventurer.glb and the old combat-model builder are retained for recovery; they are no longer used by playable characters and cannot overwrite the new asset paths.

These are a first rigged character pass, ready for further sculpting, clothing detail and animation refinement. Hair and clothing remain preset choices; face and body proportions use sliders. No external modeling API is required.

Checks: tests/character_rig.gd validates rig, skins, morphs, clips, attachment, bounded values, creator restoration, and editing without progression loss. tests/menu_coop.gd covers the full appearance array across a real host/guest connection. Standard release validation and packaged checks also run before replacing the highest numbered executable.

The female tunic includes smoothly blended breast volume. Every morph is built explicitly from Basis with from_mix=False; exported vertex checks require facial sliders to leave torso vertices unchanged and the nose slider to preserve width. This prevents inherited deformations from earlier shape keys.

Locomotion uses active manual AnimationPlayer playback, sampled once per frame. Gait phase advances with traveled distance, while idle breathing uses elapsed time. Joint poses blend at transitions; attack upper-body poses layer over the existing leg cycle. Root bob/tilt has been removed to keep the feet grounded. Both host and guest use the same presentation path. Public movement now carries authoritative velocity, while foot-cycle phase follows interpolated distance to avoid frozen or weak walking between network packets. tests/character_locomotion.gd compares joint poses over time and exercises stage-driven movement.
