# AC-06 Write Barrier Findings

**Status:** Implementation paused. A guard limited to `SaveBatch` and its transaction callers cannot protect the affected save set. Some slot operations mutate the Garden file directly.

## Disposable probe

Run `ac06-barrier-proof` used isolated save slots and an uncommitted journal. In both cases recovery returned error `12`, the attempted operation returned `OK`, and the journal remained byte-identical.

| Operation | Result while recovery was unresolved |
|---|---|
| `delete_world()` | Removed the existing Garden file. |
| `prepare(true)` | Copied a legacy save into the missing Garden path. |

[Probe log](C:/Users/sutte/Documents/Codex/ac06-9608be/AC06_BARRIER_PROBE.log)

## Required scope

Apply the same recovery preflight to the canonical Garden and character paths before direct imports, replacements, archives, and deletions. This includes current legacy import and Garden deletion, plus the older pair replacement and archive paths. A check on a staged `.new` file or deletion tombstone leaves the canonical save exposed. [Legacy import](../save_slots.gd#L15) · [Pair replacement](../save_slots.gd#L63) · [Save archive](../save_slots.gd#L158) · [Garden deletion](../save_slots.gd#L202)

The probe exercised disk behavior only. The commit-outcome implementation and acceptance tests remain pending. All probes used disposable files.
