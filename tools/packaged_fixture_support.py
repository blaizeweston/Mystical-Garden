"""External packaged-fixture support; never copied into the retail payload."""
from pathlib import Path
import re
import shutil

LOCK_LIBRARY = "b0_native_lock.dll"
LOCK_RESOURCE = Path("assets/native/persistence_lock") / LOCK_LIBRARY


def stage_packaged_lock(project, pack, runtime):
    """Expose the exported companion at its res:// path for editor --main-pack."""
    source = project / LOCK_RESOURCE
    if not source.is_file():
        return
    companion = pack.with_name(LOCK_LIBRARY)
    if not companion.is_file() or companion.read_bytes() != source.read_bytes():
        raise ValueError(f"Missing or mismatched packaged persistence lock: {companion}")
    destination = runtime / LOCK_RESOURCE
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(companion, destination)


def stage_packaged_fixture_helpers(project, runtime, source):
    """Keep excluded test helpers beside the external driver, outside the pack."""
    project, runtime = Path(project).resolve(), Path(runtime).resolve()
    helper_root = (project / "tests").resolve()
    if not helper_root.is_relative_to(project):
        raise ValueError("Fixture helper directory escapes the source project")
    literals = re.compile(r"""\b(?:preload|load)\s*\(\s*(["'])(res://tests/[^"'\r\n]+\.gd)\1\s*\)""")
    bases = re.compile(r"""(?m)^[ \t]*extends[ \t]+(["'])(res://tests/[^"'\r\n]+\.gd)\1[ \t]*(?:#[^\r\n]*)?\r?$""")
    pending, staged = [source], set()
    while pending:
        text = pending.pop()
        # An external fixture can inherit another excluded test script, whose
        # own base and literal helpers must be staged under the same boundary.
        for match in [*literals.finditer(text), *bases.finditer(text)]:
            relative = Path(match[2].removeprefix("res://"))
            if "\\" in match[2] or ".." in relative.parts:
                raise ValueError("Unsafe fixture helper path: " + match[2])
            if relative in staged:
                continue
            helper = (project / relative).resolve(strict=True)
            destination = runtime / relative
            if (not helper.is_relative_to(helper_root) or not helper.is_file()
                    or not destination.resolve().is_relative_to(runtime)):
                raise ValueError("Fixture helper escapes its owned directories: " + match[2])
            data = helper.read_bytes()
            destination.parent.mkdir(parents=True, exist_ok=True)
            # Use the same disposable writable fixture root as the external
            # driver. A packaged res:// path is not writable by a fixture.
            destination.write_bytes(data.replace(b"res://.godot/", b"user://release-fixtures/"))
            staged.add(relative)
            pending.append(data.decode("utf-8-sig"))


