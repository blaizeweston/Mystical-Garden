> Current expansion: 24 species, seven class levels, 12 choices per class and 104 checkpoint cards. See [current content depth](CONTENT_DEPTH_2026-11-08.md); historical counts below describe earlier milestones.

# Garden sacrifice altar

Press **E** at the Garden altar to open the new drag-and-drop offering menu. The right-hand grid shows available inventory items; the left holds two offering slots and the result preview.

Choose **Seeds** or **Plant parts**. Drag one ingredient into each slot. Dragging a stack reserves **one item**, not the entire stack. Nothing is consumed until you press **Sacrifice 2 seeds** or **Sacrifice 2 plant parts**. Clear offerings to cancel, double-click an offering to remove it, drag it back to the right-hand grid, or move it to the other offering slot. Closing the menu does not consume ingredients.

Seed and plant-part offerings can draw from personal or shared Garden storage; the sources can be mixed across the two slots. Type modes, rarity filtering and sorting help find ingredients. Monster components and unidentified seeds cannot be sacrificed in these combinations. The **Identify seed** button identifies one mysterious seed from the selected storage without changing its ownership. Keyboard and controller users can focus an ingredient and use **Add selected ingredient**.

## Results and discoveries

An unknown combination shows **?** without revealing a result item. Once its result is known, the preview shows the item and rarity. Identifying the species alone leaves its recipe concealed. Living Roots draws connections for successfully tested seed recipes. Learned successful and failed altar results are saved for the host's Garden. A known result remains visible even after the last ingredients are consumed; the sacrifice button stays disabled until enough materials are available again.

The 24-species catalog supplies 16 seed recipes and all 21 two-parent material syntheses. Matching ordinary materials also retain their refinement recipes. Five historical parent pairs now yield only salvage when offered as seeds. A saved former success cannot grant its old seed or appear in the repeatable recipe picker. Existing seeds, discoveries and Knowledge are preserved. Either ingredient order works.

A material result is usable in the normal crafting system but does **not** award its seed or unlock its plant species. That separation also survives save/load and moving materials into shared storage. Discovering or identifying the seed is still necessary to cultivate that species.

Failed combinations consume the two offerings and return one deterministic salvage material plus a clue. With Seed Conservation, a failed seed offering also returns the parent whose material was not salvaged. For matching parents that means one net seed consumed. The recorded failure preview lists both outputs. Repeating the failed pair previews the salvage, rather than implying a hidden successful result. Mixed seed/material offerings, missing ingredients and attempts away from the Garden altar are rejected without consuming anything.

New seed discoveries grant their usual four Knowledge. The first successful seed recipe independently earns two Knowledge, giving six when it also discovers a species. A first successful material recipe earns four Knowledge. Repeating known recipes grants the item without repeatedly farming discovery Knowledge. Personal-only ingredients yield personal results; if either ingredient is shared, every output (including failed-offering salvage and conservation returns) goes to shared Garden storage. The mixed-source preview states this before payment.

All ingredient counts are revalidated on confirmation. If saving fails, ingredients, output, recipe records, discovery flags and Knowledge are restored.

## Extending recipes

`altar_recipes.gd` generates seed/material pairs from the seed lineage data. Append custom definitions to **assets/altar/additional_recipes.json** using the shape in **docs/altar_recipe_template.json**. Recipes refer to stable IDs from the reusable item catalog. A custom recipe must use two items of the appropriate category and produce that same category; material outputs must be higher rarity than both inputs. Duplicate unordered pairs are ignored. Generic template plant materials can participate when their categories and recipe definitions match. New cultivable seed species use the existing seed-catalog template.

`altar_service.gd` owns preview secrecy, ownership validation, consumption, salvage, discovery and rollback. `garden_altar_panel.gd` and `altar_input_slot.gd` implement the matching inventory-style interface. Legacy seed discoveries and recorded experiment attempts migrate, with a `.pre-altar-v1.bak` recovery copy before the first updated save.

## Verification

Passed: menu opening without consumption; unknown and known previews; forward/reversed recipes; higher-rarity materials; separate material/seed discovery; personal/shared accounting; partial salvage and clues; duplicate-input quantities; invalid mixed inputs; range and Wilds rejection; transactional rollback; identification; recipe persistence; legacy backup and attempt migration. A graphical test performed real mouse drags from the right-hand grid, confirmed both seed and material offerings, checked result updates and verified viewport bounds. The full solo loop and existing seed, inventory, weighted-upgrade, grafting, Heart, run-flow and save-menu checks passed.

The exported Windows build passed the focused altar checks. Both playable executables were refreshed after backing up their previous builds; v0.2 launched successfully.

