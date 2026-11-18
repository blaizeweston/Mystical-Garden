"""Readable coverage declarations and separately retained source-matching snapshots."""
from copy import deepcopy
import json
from pathlib import Path


def read_object(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as error:
        raise ValueError(f"Cannot read validation declaration {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"Validation declaration must be an object: {path}")
    return value


def load_map(project):
    tools = Path(project) / "tools"
    declarations = read_object(tools / "test_map.json")
    name = declarations.get("matching_data")
    if name is None:  # Small self-test maps can declare their matches inline.
        return declarations
    if not isinstance(name, str):
        raise ValueError("Matching-data path must be a string")
    relative = Path(name)
    path = (tools / relative).resolve()
    if relative.is_absolute() or ".." in relative.parts or not path.is_relative_to(tools.resolve()):
        raise ValueError("Matching data must stay inside tools: " + str(name))
    snapshots = read_object(path)
    if snapshots.get("schema") != 1 or set(snapshots) != {"schema", "game_regions", "file_regions"}:
        raise ValueError("Unsupported matching-data schema")
    result = deepcopy(declarations)
    for section in ("game_regions", "file_regions"):
        owners = result.get(section, {})
        matches = snapshots.get(section, {})
        if set(owners) != set(matches):
            raise ValueError("Matching-data ownership differs: " + section)
        for container, specification in owners.items():
            rules = specification if section == "game_regions" else specification["regions"]
            captured = matches[container]
            if set(rules) != set(captured):
                raise ValueError("Missing/orphan matching region: " + container)
            for region, rule in rules.items():
                pair = captured[region]
                if (set(pair) != {"match", "baseline"} or not pair["match"]
                        or not all(isinstance(value, str) for value in pair.values())
                        or "match" in rule or "baseline" in rule):
                    raise ValueError("Invalid/duplicated matching snapshot: " + container + "::" + region)
                rule.update(pair)
    return result


def fixture_profile(project, name, declarations=None):
    """Resolve only this fixture's explicit environment; never infer it from its name."""
    if declarations is None:
        path = Path(project) / "tools/test_map.json"
        declarations = read_object(path) if path.is_file() else {}
    suite = declarations.get("suites", {}).get(name, {})
    profile_name = suite.get("profile", "standard")
    profiles = declarations.get("profiles", {"standard": {}})
    if not isinstance(profile_name, str) or not isinstance(profiles, dict) or profile_name not in profiles:
        raise ValueError("Unknown fixture profile: " + str(profile_name))
    profile = profiles[profile_name]
    if not isinstance(profile, dict) or set(profile) - {"isolated_terrain", "arguments"}:
        raise ValueError("Unsupported fixture profile fields: " + str(profile_name))
    terrain = profile.get("isolated_terrain", False)
    arguments = profile.get("arguments", [])
    allowed = {"--experimental-terrain", "--combat-affinities"}
    if (not isinstance(terrain, bool) or not isinstance(arguments, list)
            or any(not isinstance(argument, str) or argument not in allowed for argument in arguments)
            or len(set(arguments)) != len(arguments)
            or ("--experimental-terrain" in arguments) != terrain):
        raise ValueError("Invalid isolated fixture profile: " + str(profile_name))
    return {"isolated_terrain": terrain, "arguments": list(arguments)}
