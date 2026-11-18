"""Reads ai/schema.json and the mob contract. Python never hardcodes an observation offset."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = PROJECT_ROOT / "ai" / "schema.json"
CONTRACT_PATH = PROJECT_ROOT / "mob_sim" / "mob_contract.json"
HEAD_NAMES = ("behaviour", "enemy_target", "ally_target", "manoeuvre", "message_a", "message_b")


@dataclass
class Block:
    name: str
    encoder: str
    repeat: int
    offset: int
    stride: int = 0
    fields: dict[str, tuple[int, int]] = field(default_factory=dict)

    @property
    def size(self) -> int:
        return self.repeat * self.stride


class MobSchema:
    def __init__(self, schema_path: Path = SCHEMA_PATH, contract_path: Path = CONTRACT_PATH) -> None:
        schema_bytes = schema_path.read_bytes()
        contract_bytes = contract_path.read_bytes()
        self.hash_hex = hashlib.sha256(schema_bytes + contract_bytes).hexdigest()
        data = json.loads(schema_bytes)
        contract = json.loads(contract_bytes)
        self.version = int(data["version"])
        self.clip = float(data["clip"])
        self.network = {key: int(value) for key, value in data["network"].items()}
        self.blocks, self.observation_size = self._compile(data["observation"])
        self.global_blocks, self.global_size = self._compile(data["global_state"])
        slots = contract["slots"]
        self.head_sizes = {
            "behaviour": len(contract["behaviours"]),
            "enemy_target": int(slots["players"]) + 1,
            "ally_target": int(slots["allies"]) + 2,
            "manoeuvre": len(contract["manoeuvres"]),
            "message_a": int(slots["message_symbols"]),
            "message_b": int(slots["message_symbols"]),
        }
        self.logit_count = sum(self.head_sizes.values())

    @staticmethod
    def _compile(entries: list[dict]) -> tuple[list[Block], int]:
        blocks: list[Block] = []
        cursor = 0
        for entry in entries:
            block = Block(entry["name"], entry.get("encoder", ""), int(entry.get("repeat", 1)), cursor)
            for item in entry["fields"]:
                size = int(item.get("size", 1))
                block.fields[item["name"]] = (block.stride, size)
                block.stride += size
            cursor += block.size
            blocks.append(block)
        return blocks, cursor

    def encoder_blocks(self, encoder: str) -> list[Block]:
        return [block for block in self.blocks if block.encoder == encoder]

    def encoder_size(self, encoder: str) -> int:
        return sum(block.size for block in self.encoder_blocks(encoder))

    def layout_rows(self) -> list[list]:
        """Stable text form of the layout, compared against the Godot parser."""
        rows: list[list] = []
        for prefix, blocks in (("", self.blocks), ("global.", self.global_blocks)):
            for block in blocks:
                for index in range(block.repeat):
                    for name, (offset, size) in block.fields.items():
                        rows.append([f"{prefix}{block.name}[{index}].{name}", block.offset + index * block.stride + offset, size])
        return rows
