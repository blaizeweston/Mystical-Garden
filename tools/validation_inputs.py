"""Inputs that can change an observed source or packaged fixture result.

The broad infrastructure hash still guards mid-run stability. It is deliberately
not a cross-run cache key: registry neighbours and self-tests do not execute a
fixture. Format 2 starts a new evidence epoch; old keys are never relabelled.
"""
import ast
import hashlib
from pathlib import Path

KEY_SCHEMA = 2


def digest(data):
    return hashlib.sha256(data).hexdigest()


def python_contract(path, methods=None):
    tree = ast.parse(Path(path).read_text(encoding="utf-8-sig"))
    if methods is not None:
        tree = ast.Module(body=[node for node in ast.walk(tree)
                               if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                               and node.name in methods], type_ignores=[])
    return digest(ast.dump(tree, include_attributes=False).encode())


def source_harness(project, workflow_file, executor_file):
    tools = Path(project) / "tools"
    here = Path(__file__).parent
    def implementation(name, fallback):
        path = tools / name
        return path if path.is_file() else Path(fallback)

    workflow = implementation("test_workflow.py", workflow_file)
    executor = implementation("validation_execution.py", executor_file)
    registry = implementation("validation_registry.py", here / "validation_registry.py")
    inputs = implementation("validation_inputs.py", Path(__file__))
    execution_methods = {"execute", "environment", "source", "evidence_hashes",
                         "intact_evidence", "valid", "engine_signature", "read_json", "write_json"}
    shared = {
        "runner:tools/test_workflow.py::execution": python_contract(workflow, execution_methods),
        "runner:tools/validation_execution.py": python_contract(executor),
        "runner:tools/validation_registry.py": python_contract(registry),
        "runner:tools/validation_inputs.py": python_contract(inputs),
    }
    # New local Python helpers fail conservatively into the shared contract.
    # Only the explicitly package-only preparation module is excluded.
    pending = [workflow, executor, registry, inputs]
    seen = set(pending)
    while pending:
        path = pending.pop()
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8-sig"))):
            if isinstance(node, ast.ImportFrom) and node.level:
                raise ValueError("Relative validator imports need an explicit input boundary: " + str(path))
            names = [alias.name for alias in node.names] if isinstance(node, ast.Import) else [node.module] if isinstance(node, ast.ImportFrom) and node.module else []
            for name in names:
                if name == "packaged_fixture_support":
                    continue
                relative = Path(*name.split(".")).with_suffix(".py")
                helper = tools / relative
                if not helper.is_file():
                    helper = path.parent / relative
                if helper.is_file() and helper not in seen:
                    seen.add(helper);pending.append(helper)
                    shared["runner:tools/" + relative.as_posix()] = python_contract(helper)
    # This external launcher runs only the supplied network smoke. A helper
    # imported by another fixture is also covered by normal resource traversal.
    smoke = {"runner:" + path.relative_to(project).as_posix(): digest(path.read_bytes())
             for path in sorted((Path(project) / "test").glob("*"))
             if path.is_file() and path.suffix in {".gd", ".tscn", ".ps1"}}
    return {"shared": shared, "smoke": smoke}


def package_harness(project):
    tools = Path(project) / "tools"
    names = ("release_latest.ps1", "playtest_release.py", "build_playtest.ps1",
             "validation_python.ps1", "packaged_fixture_support.py")
    return {"package:tools/" + name: digest((tools / name).read_bytes())
            if (tools / name).is_file() else "missing" for name in names}
