from pathlib import Path
import sys,json
import bpy
project=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(project/"tools"))
from enemy_model_template import build,bake_export
catalog=json.loads((project/"assets/enemies/catalog.json").read_text(encoding="utf-8-sig"))
if len(catalog)>65536 or len({entry["id"] for entry in catalog})!=len(catalog):
    raise ValueError("Use unique enemy IDs; extend the runtime codec before exceeding 65536 kinds.")
source=project/"assets/source/enemies"
source.mkdir(parents=True,exist_ok=True)
requested=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
for entry in catalog:
    if requested and entry["id"] not in requested:continue
    if entry.get("boss"):
        from boss_model_template import build as build_boss
        root=build_boss(entry)
    else:root=build(entry)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source/f'{entry["id"]}.blend'))
    bake_export(root,project/f'assets/enemies/{entry["id"]}.glb')
    print("BUILT",entry["id"])
