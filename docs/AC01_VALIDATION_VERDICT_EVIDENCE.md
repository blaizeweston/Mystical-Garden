# AC-01 Validation Verdict Evidence

Validation now requires a zero process exit, a complete result tied to the run, fixture, and peer, and a stdout pass marker. Unexpected engine errors from either stream fail the result. The shared runner instruments the existing fixture’s explicit exit call in a generated copy. The connect-and-play smoke keeps its native structured peer reports. Packaged results are checked again before recording release evidence, and reuse requires intact evidence hashes.

The diagnostics fixture declares one exact, unique blocked-directory error. Its deliberate subprocess fault tests still check the captured exception and the killed child’s unclean exit. No gameplay code was changed.

## Negative Godot probes

Run ID **ac01-negative-verdict**. Each fixture used the real Godot engine and produced a misleading stdout pass marker. The test checked the exact rejection reason.

| Fixture | Child exit | Result |
|---|---:|---|
| [nonzero_exit](../.godot/validation/ac01-probes/faults-verdict/nonzero_exit/verdict.json) | 7 | Rejected for process exit 7. |
| [missing_result](../.godot/validation/ac01-probes/faults-verdict/missing_result/verdict.json) | 0 | Rejected for missing or invalid structured result. |
| [stale_result](../.godot/validation/ac01-probes/faults-verdict/stale_result/verdict.json) | 0 | Rejected for stale or mismatched run, fixture, or peer. |
| [mismatched_peer](../.godot/validation/ac01-probes/faults-verdict/mismatched_peer/verdict.json) | 0 | Rejected for stale or mismatched run, fixture, or peer. |
| [incomplete_result](../.godot/validation/ac01-probes/faults-verdict/incomplete_result/verdict.json) | 0 | Rejected for failed or incomplete completion result. |
| [unexpected_error](../.godot/validation/ac01-probes/faults-verdict/unexpected_error/verdict.json) | 0 | Rejected for unexpected engine error (1): AC-01 unexpected engine error. |

## Source verification

| Fixture | Execution ID | Result |
|---|---|---|
| [content_validation](../.godot/validation/ac01-probes/source-verdict/content_validation/verdict.json) | `5a3f2006d5934dff8680711117d832d8` | Passed. |
| [diagnostics](../.godot/validation/ac01-probes/source-verdict/diagnostics/verdict.json) | `15231fd82bfc4c38ab7566f444392a4d` | Passed. |
| [core_combat_coop](../.godot/validation/ac01-probes/source-verdict/core_combat_coop/verdict.json) | `aca84d9934964b0b8d08f2ef53a9d85e` | Passed. |
| [four_players_coop](../.godot/validation/ac01-probes/source-verdict/four_players_coop/verdict.json) | `c64c48aeb2a240609b77db3d23aa2141` | Passed. |
| [supplied_network_smoke](../.godot/validation/ac01-probes/source-verdict/supplied_network_smoke/20261112-141932-93d534ea/summary.json) | `f168176ace0e44818de510162a0add89` | Passed. Host and three guests exited zero. |
| [playable_solo](../.godot/validation/ac01-probes/source-verdict/playable_solo/verdict.json) | `d7ecd1d69c1d4ef587f9373790e6328d` | Passed. |
| [garden_growth_coop](../.godot/validation/ac01-probes/source-verdict/garden_growth_coop/verdict.json) | `a12aa690c44a43ddae474683c695f195` | Rejected. Both peers exited zero, but the guest logged three engine errors. |

## Packaged verification

Run ID **ac01-package-verdict** used the retained CB-08 staged Windows executable. Catalog preflight, package startup, diagnostics, Core Combat host/guest, the four-player fixture with its overflow probe, and connect-and-play smoke all passed. The package verifier rechecked the six fixture verdicts and 52 evidence files. [Packaged evidence](../.godot/validation/ac01-probes/package-verdict/rechecked-evidence.json)

All 43 planner self-tests passed. The log lists the individual tests, including invalidated package evidence and missing commit results. [Planner self-test log](../.godot/validation/ac01-probes/planner-selftests-verdict.log)

## Release status

The strict Garden growth run reproduced the three engine errors after the guest world detached, following a successful rejoin. Archived Garden growth and Thief Escape guest logs also fail when checked against the new verdict rules. [Archive replay](../.godot/validation/ac01-probes/archive-replay.json)

The shared verdict change invalidates the 143 prior source suite keys. These targeted verification runs did not certify a release. Full source and package revalidation and the Garden growth correction remain separate work.
