"""Extract upper-body clips from the two free Quaternius Standard GLBs.

No rebaking or root motion: keep the shared 65-joint rest rig and original keys.
Usage: python tools/build_weapon_combat_library.py UAL1_Standard.glb UAL2_Standard.glb OUTPUT.glb
"""
from pathlib import Path
import copy
import hashlib
import json
import struct
import sys

CLIPS = [
    ["Spell_Simple_Shoot"],
    ["Sword_Regular_A", "Sword_Regular_A_Rec", "Sword_Regular_B", "Sword_Regular_B_Rec",
     "TreeChopping_Loop", "OverhandThrow", "Melee_Hook", "Melee_Hook_Rec"],
]


def upper_body(name):
    return name == "Head" or name.startswith(("spine_", "neck_", "clavicle_", "upperarm_", "lowerarm_", "hand_", "thumb_", "index_", "middle_", "ring_", "pinky_"))


def load(path):
    raw = path.read_bytes()
    assert struct.unpack_from("<III", raw) == (0x46546C67, 2, len(raw))
    size, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    document = json.loads(raw[20:20 + size])
    offset = 20 + size
    count, kind = struct.unpack_from("<II", raw, offset)
    assert kind == 0x004E4942 and len(document["buffers"]) == 1
    return document, raw[offset + 8:offset + 8 + count]


def remap_references(document, mapping):
    for mesh in document.get("meshes", []):
        for primitive in mesh["primitives"]:
            if "indices" in primitive: primitive["indices"] = mapping(primitive["indices"])
            primitive["attributes"] = {k: mapping(v) for k, v in primitive["attributes"].items()}
            for target in primitive.get("targets", []):
                for key, value in target.items(): target[key] = mapping(value)
    for skin in document.get("skins", []):
        if "inverseBindMatrices" in skin: skin["inverseBindMatrices"] = mapping(skin["inverseBindMatrices"])
    for animation in document["animations"]:
        for sampler in animation["samplers"]:
            for key in ("input", "output"): sampler[key] = mapping(sampler[key])


def build(paths, output):
    sources = [load(path) for path in paths]
    document = copy.deepcopy(sources[0][0])
    target_nodes = {node["name"]: i for i, node in enumerate(document["nodes"])}
    document["animations"] = []
    binary = bytearray()
    for source_index, (source, data) in enumerate(sources):
        binary.extend(b"\0" * (-len(binary) % 4))
        binary_offset = len(binary)
        binary.extend(data)
        accessor_offset = 0 if source_index == 0 else len(document["accessors"])
        if source_index:
            view_offset = len(document["bufferViews"])
            for view in source["bufferViews"]:
                copied = copy.deepcopy(view)
                copied["byteOffset"] = copied.get("byteOffset", 0) + binary_offset
                document["bufferViews"].append(copied)
            for accessor in source["accessors"]:
                copied = copy.deepcopy(accessor)
                if "bufferView" in copied: copied["bufferView"] += view_offset
                assert "sparse" not in copied, "Unexpected sparse source accessor"
                document["accessors"].append(copied)
        available = {animation["name"]: animation for animation in source["animations"]}
        for name in CLIPS[source_index]:
            original = available[name]
            channels, samplers = [], []
            for channel in original["channels"]:
                node = source["nodes"][channel["target"]["node"]]
                if channel["target"]["path"] != "rotation" or not upper_body(node["name"]): continue
                target = document["nodes"][target_nodes[node["name"]]]
                for key, default in (("rotation", [0, 0, 0, 1]), ("translation", [0, 0, 0]), ("scale", [1, 1, 1])):
                    assert max(abs(a - b) for a, b in zip(node.get(key, default), target.get(key, default))) < 0.00001, (name, node["name"], key)
                sampler = copy.deepcopy(original["samplers"][channel["sampler"]])
                sampler["input"] += accessor_offset
                sampler["output"] += accessor_offset
                channels.append({"sampler": len(samplers), "target": {"node": target_nodes[node["name"]], "path": "rotation"}})
                samplers.append(sampler)
            assert channels, name
            document["animations"].append({"name": name.removesuffix("_Loop"), "channels": channels, "samplers": samplers})

    used = set()
    def collect(index): used.add(index); return index
    remap_references(document, collect)
    accessors = {old: new for new, old in enumerate(sorted(used))}
    document["accessors"] = [document["accessors"][old] for old in sorted(used)]
    remap_references(document, accessors.__getitem__)
    views = {accessor["bufferView"] for accessor in document["accessors"]}
    views.update(image["bufferView"] for image in document.get("images", []) if "bufferView" in image)
    view_indices = {old: new for new, old in enumerate(sorted(views))}
    compact, compact_views = bytearray(), []
    for old in sorted(views):
        view = copy.deepcopy(document["bufferViews"][old])
        start, length = view.get("byteOffset", 0), view["byteLength"]
        compact.extend(b"\0" * (-len(compact) % 4))
        view["byteOffset"] = len(compact)
        compact.extend(binary[start:start + length])
        compact_views.append(view)
    for accessor in document["accessors"]: accessor["bufferView"] = view_indices[accessor["bufferView"]]
    for image in document.get("images", []):
        if "bufferView" in image: image["bufferView"] = view_indices[image["bufferView"]]
    document["bufferViews"] = compact_views
    document["buffers"] = [{"byteLength": len(compact)}]
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    compact.extend(b"\0" * (-len(compact) % 4))
    payload = struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(compact)) + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded + struct.pack("<II", len(compact), 0x004E4942) + compact
    output.write_bytes(payload)
    metadata = {"license": "CC0-1.0", "publisher": "Quaternius", "sources": [
        {"page": "https://quaternius.itch.io/universal-animation-library" + ("-2" if i else ""), "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "clips": CLIPS[i]} for i, path in enumerate(paths)],
        "output_sha256": hashlib.sha256(payload).hexdigest(), "policy": "Original upper-body rotation keys only; no root, pelvis, lower-body, translation or scale tracks."}
    output.with_name("weapon_combat_sources.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print("Built", output.name, len(payload), "bytes;", len(document["animations"]), "upper-body clips")


if __name__ == "__main__":
    build([Path(value) for value in sys.argv[1:3]], Path(sys.argv[3]))
