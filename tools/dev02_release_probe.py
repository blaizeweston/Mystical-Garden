"""Exercise the real Windows release template with a disposable command-refusal fixture."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STATIC = re.compile(r'(?:preload\(\s*|extends\s+)["\']res://([^"\']+)')
DRIVER = "tests/support/dev02_release_boundary.gd"


def dependencies():
    pending = [DRIVER]
    seen = set()
    while pending:
        name = pending.pop()
        if name in seen:
            continue
        seen.add(name)
        source = ROOT / name
        if source.suffix in (".gd", ".tscn", ".tres"):
            pending.extend(STATIC.findall(source.read_text(encoding="utf-8")))
    # Some catalog constants read their JSON during script initialization.
    seen.update(p.relative_to(ROOT).as_posix() for p in (ROOT / "assets").rglob("*.json"))
    # Template binaries load imported models and textures via their resource remaps.
    imports = {ROOT / (name + ".import") for name in seen}
    for name in tuple(seen):
        if name.endswith(".glb"):
            imports.update((ROOT / name).parent.glob("*.png.import"))
            imports.update((ROOT / name).parent.glob("*.jpg.import"))
    for remap in imports:
        if remap.is_file():
            seen.add(remap.relative_to(ROOT).as_posix())
            seen.update(re.findall(r'"res://(\.godot/imported/[^"]+)"', remap.read_text(encoding="utf-8")))
    seen.add(".godot/global_script_class_cache.cfg")
    return sorted(seen)


def run(editor, template):
    base = ROOT / ".godot" / "vd"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dev02-release-", dir=base) as scratch:
        work = Path(scratch)
        project = work / "fixture"
        project.mkdir()
        env = {**os.environ, "APPDATA": scratch, "LOCALAPPDATA": scratch,
               "MYSTICAL_DEV02_PROBE_ROOT": scratch, "MYSTICAL_VALIDATION_FIXTURE": "dev02_release_boundary"}
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="DEV02 disposable probe"\nrun/main_scene="res://probe.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        (project / "probe.tscn").write_text(f'[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://{DRIVER}" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
        # The pack contains only the refusal probe and its static script dependencies.
        # Use the editor solely as a PCK writer. The release binary runs the assertion.
        packer = project / "pack.gd"
        packer.write_text(r'''extends SceneTree
func _initialize():
    var p := PCKPacker.new()
    var args := OS.get_cmdline_user_args()
    var error := p.pck_start(args[0])
    if error != OK:
        printerr(error_string(error))
        quit(1)
        return
    for name in FileAccess.get_file_as_string(args[1]).split("\n", false):
        var path := "res://" + name.strip_edges()
        var source := path if name.strip_edges() in ["project.godot", "probe.tscn"] else args[2].path_join(name.strip_edges())
        error = p.add_file(path, source)
        if error != OK:
            printerr(path, " ", error_string(error))
            quit(1)
            return
    quit(p.flush())
''')
        manifest = work / "files.txt"
        manifest.write_text("\n".join(dependencies()+["project.godot","probe.tscn"]))
        subprocess.run([editor, "--headless", "--path", str(project), "--script", "pack.gd", "--", (work/"probe.pck").as_posix(), manifest.as_posix(), ROOT.as_posix()], env=env, check=True, timeout=60)
        executable = work / "probe.exe"
        shutil.copyfile(template, executable)
        proc = subprocess.run([executable, "--headless", "--quit-after", "120", "--log-file", str(work/"run.log")], cwd=work, env=env, capture_output=True, timeout=90)
        log = (work/"run.log").read_text(encoding="utf-8", errors="replace") if (work/"run.log").exists() else ""
        if proc.returncode or not (work/"passed.txt").is_file() or "ERROR:" in log:
            raise RuntimeError(log[-6000:] or proc.stderr.decode(errors="replace"))
        print("PASS: Windows release template rejected developer entry, resources, stock and research.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("editor", type=Path)
    parser.add_argument("release_template", type=Path)
    args = parser.parse_args()
    run(args.editor.resolve(), args.release_template.resolve())
