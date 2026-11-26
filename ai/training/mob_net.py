"""The mob policy network and its training-only critic. All sizes come from ai/schema.json."""

from __future__ import annotations

import struct
from pathlib import Path

import torch
from torch import Tensor, nn

from mob_schema import HEAD_NAMES, MobSchema

WEIGHTS_MAGIC = b"MOBW"
WEIGHTS_VERSION = 1


class MobPolicy(nn.Module):
    """Actor exported to the game. Shared encoders keep slot order, so target heads can tell slots apart."""

    def __init__(self, schema: MobSchema) -> None:
        super().__init__()
        self.schema = schema
        net = schema.network
        self.self_blocks = schema.encoder_blocks("self")
        self.enemy_block = schema.encoder_blocks("enemy")[0]
        self.ally_block = schema.encoder_blocks("ally")[0]
        self.leader_block = schema.encoder_blocks("leader")[0]
        self.self_encoder = nn.Linear(schema.encoder_size("self"), net["self_hidden"])
        self.enemy_encoder = nn.Linear(self.enemy_block.stride, net["enemy_hidden"])
        self.ally_encoder = nn.Linear(self.ally_block.stride, net["ally_hidden"])
        self.leader_encoder = nn.Linear(self.leader_block.stride, net["leader_hidden"])
        joined = (net["self_hidden"] + self.enemy_block.repeat * net["enemy_hidden"]
                  + self.ally_block.repeat * net["ally_hidden"] + net["leader_hidden"])
        self.trunk_a = nn.Linear(joined, net["trunk_hidden"])
        self.trunk_b = nn.Linear(net["trunk_hidden"], net["trunk_hidden"])
        self.recurrent = nn.GRUCell(net["trunk_hidden"], net["recurrent_hidden"])
        self.heads = nn.Linear(net["trunk_hidden"] + net["recurrent_hidden"], schema.logit_count)
        # The message logits' rows in the heads. Messages still mean nothing, and their choices made about three
        # quarters of the policy gradient's noise, so they read the shared layers without training them (forward).
        rows, cursor = [], 0
        for name in HEAD_NAMES:
            if name.startswith("message"):
                rows += range(cursor, cursor + schema.head_sizes[name])
            cursor += schema.head_sizes[name]
        self._message_rows = torch.tensor(rows, dtype=torch.long)

    def trunk_layers(self, obs: Tensor) -> tuple[Tensor, Tensor]:
        """The two trunk layers' outputs (after their ReLU) for a batch of observations."""
        relu = torch.relu
        self_input = torch.cat([obs[:, b.offset:b.offset + b.size] for b in self.self_blocks], dim=1)
        parts = [relu(self.self_encoder(self_input))]
        for index in range(self.enemy_block.repeat):
            start = self.enemy_block.offset + index * self.enemy_block.stride
            parts.append(relu(self.enemy_encoder(obs[:, start:start + self.enemy_block.stride])))
        for index in range(self.ally_block.repeat):
            start = self.ally_block.offset + index * self.ally_block.stride
            parts.append(relu(self.ally_encoder(obs[:, start:start + self.ally_block.stride])))
        leader = self.leader_block
        parts.append(relu(self.leader_encoder(obs[:, leader.offset:leader.offset + leader.stride])))
        first = relu(self.trunk_a(torch.cat(parts, dim=1)))
        return first, relu(self.trunk_b(first))

    def forward(self, obs: Tensor, hidden: Tensor) -> tuple[Tensor, Tensor]:
        """Returns logits for every head, concatenated in head order, and the next hidden state. The message logits
        have the same values the game computes, but their gradient reaches only the heads' own weights."""
        trunk = self.trunk_layers(obs)[1]
        next_hidden = self.recurrent(trunk, hidden)
        features = torch.cat([trunk, next_hidden], dim=1)
        logits = self.heads(features)
        if torch.is_grad_enabled() and self._message_rows.numel():
            rows = self._message_rows.to(features.device)
            quiet = nn.functional.linear(features.detach(), self.heads.weight[rows], self.heads.bias[rows])
            logits = logits.index_copy(1, rows, quiet)
        return logits, next_hidden

    def initial_hidden(self, count: int, device: torch.device | str = "cpu") -> Tensor:
        return torch.zeros(count, self.schema.network["recurrent_hidden"], device=device)

    def split_logits(self, logits: Tensor) -> dict[str, Tensor]:
        sizes = [self.schema.head_sizes[name] for name in HEAD_NAMES]
        return dict(zip(HEAD_NAMES, torch.split(logits, sizes, dim=1)))


class MobCritic(nn.Module):
    """Centralised value network, used only in training and never exported."""

    def __init__(self, schema: MobSchema) -> None:
        super().__init__()
        hidden = schema.network["trunk_hidden"]
        self.layers = nn.Sequential(
            nn.Linear(schema.observation_size + schema.global_size, hidden), nn.ReLU(),
            nn.Linear(hidden, hidden), nn.ReLU(),
            nn.Linear(hidden, 1),
        )

    def forward(self, obs: Tensor, global_state: Tensor) -> Tensor:
        return self.layers(torch.cat([obs, global_state], dim=1)).squeeze(1)


def export_weights(policy: MobPolicy, path: Path) -> None:
    """Writes the actor in the little-endian format read by ai/mob_policy_reference.gd."""
    state = policy.state_dict()
    with path.open("wb") as out:
        out.write(WEIGHTS_MAGIC)
        out.write(struct.pack("<I", WEIGHTS_VERSION))
        out.write(policy.schema.hash_hex.encode("ascii"))
        out.write(struct.pack("<I", len(state)))
        for name, tensor in state.items():
            encoded = name.encode("ascii")
            rows, cols = tensor.shape[0], tensor.shape[1] if tensor.dim() == 2 else 1
            out.write(struct.pack("<III", len(encoded), rows, cols))
            out.write(encoded)
            out.write(tensor.detach().cpu().float().numpy().astype("<f4").tobytes())
