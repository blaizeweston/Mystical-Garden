# Peaceful Garden and mysterious Heart

The Garden now uses the natural woodland style of the Wilds with a calmer treatment:
soft green ground, gently curved mossy footpaths, fine tree foliage, ferns and small
petalled flowers. The Wilds gateway is framed by living trees. The Garden offering
altar is a stone growth cradled by roots. Existing positions and interactions remain.

Two irregular ponds have shallow jade edges, subtle moving ripples, lily pads and
scattered weathered shoreline stones. Plot soil now has fine earthy detail. Garden
lighting is softer and more neutral than the warm, harder Wilds lighting; switching
areas restores the corresponding lighting treatment.

The Heart is a smooth, asymmetrical ribbed seed-organ wrapped in folded sepals rather
than a tree or a stack of rounded blobs. Fine veins, a faint inner glow and slow,
uneven breathing suggest something living and not entirely familiar. Later knowledge
phases add folded layers and curling organs. All six growth stages, finale visibility,
Garden expansion and the existing knowledge mechanics are preserved.

Implementation: garden_visuals.gd supplies reusable paths, ground cover and the altar;
heart_visuals.gd constructs the six Heart forms; stage.gd builds the grass, ponds and
shared presentation. assets/shaders/garden_path.gdshader softens footpath edges.

Validation: rendered initial Garden, early Heart close-up and restored Heart close-up;
Garden presentation, all six Heart growth stages, research/persistence, gardening,
Garden altar, Wilds pathing and combat regression checks, plus full solo playthrough.
Only the most recent playable executable, Mystical Garden v0.2.exe, is replaced.
