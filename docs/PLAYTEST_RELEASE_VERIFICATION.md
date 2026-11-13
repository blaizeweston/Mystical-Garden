# Versioned playtest pipeline verification

## Starting checkpoint

The original worktree and index were clean on `ac06/persistence`. F6 commit
`77cdd1ba737cb3e83a97a63074b81634f4900f5b` directly follows F5 commit
`ffceab1cb73507cbb8756bf3f72961a6d7ed64e8`, descended from
`8c3cc407063130e100fade6e71efac1cfb93583a`. All 1,268 paths in the F6
tested-input manifest matched committed blobs after normalizing text
line endings and comparing binary bytes exactly.

| F6 evidence | Verified result |
|---|---|
| Tested inputs | `049d8d839b3f50a85406824b3313a6e82ef0eefe1c98fdb44fa641683a48c4f8` |
| Connected `20261113-164759-1f86b269` | 168 of 168 suites, 2 executed and 166 verified reusable |
| Windows VerifyOnly `07e07e5ad9af448288e1ba3b574306ff` | 15 fresh checks, 25 process exits, 122 reused packaged suites |
| F6 Windows EXE | `aff064123b62801d09587daa6c037b9b122891635458d2f20278cb1155ba5d6e` |
| Native DLL | `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379` |

The existing `tools/validate_release.ps1`, `tools/test_workflow.py`,
`tools/validation_execution.py`, `tools/test_map.json` and
`tools/release_latest.ps1` already handled dependency selection, strict verdicts,
export, matching native libraries and package verification. The workflow adds a
detached clean-commit build, versioned Windows export settings, retail startup
probes, an immutable archive and a separate annotated-tag command. The Windows
preset still uses an embedded PCK. The packaged extension descriptor is embedded
and supplied separately for reference. No external runtime is required on the
tester PC.

## Isolated storage

The exported configuration places the root under default Windows Roaming
AppData as a physical sibling of the old prototype root. All supported
`user://` locations, including Garden, roster, Developer Garden, Preview,
catalogs, tombstones, journals, archives, migration backups and the native
sentinel, inherit this location. Before the title and diagnostics initialize,
`playtest_storage.gd::inspect` checks the physical path and exact version/commit
identity with the existing native authorization backend. `main_menu.gd::_ready`
refuses admission on failure and disables legacy import in retail. Older and
newer playtests use different directories. Reopening a save set requires the
same version and commit. There is no automatic cross-version migration.

Standalone F6 rollback probe `playtest-older-build-root-f6` ran the exact F6
EXE and DLL from a disposable profile. It exited 0 with zero engine errors,
opened its legacy root and left the newer playtest root with only its original
sentinel `garden.cfg`. The SHA-256 before and after was
`ecaa271f7d596780b4bc03e81983a0c88509da8f4da0fcdd62c653d1f454f811`.

## Refusal evidence

- `playtest-dirty-refusal` exited 1 before staging.
- `playtest-duplicate-refusal` exited 1 before staging and preserved the existing
  version directory byte-for-byte.
- The disposable stale-evidence VerifyOnly control exited 1 before export.
- `playtest-package-negative-fc7db29275e84f11ae7ba990619cc28a` passed the original
  package-startup evidence and rejected a copy with an injected unexpected engine
  error. The production verifier and original evidence were unchanged.
- Early staging attempts remained separate. A broad cache copy reproduced a
  Windows path-limit failure for disposable network diagnostics. The final
  builder seeds only paths referenced by the strict verifier's cached records.
- Initial VerifyOnly run `fc7db29275e84f11ae7ba990619cc28a` stopped with exit 1
  when `garden_returns_coop` freed the guest world while ENet was still polling.
  Godot reported the missing `MysticalGarden` node, missing cached peer node ID
  and invalid packet. No completed release directory appeared. That fixture and
  `garden_conduit_coop` now use the AC-02 ordering and wait for actual guest
  disconnect. Production networking and error checking are unchanged.
- Direct source and package controls
  `playtest-teardown-garden_returns_coop-{source,package}` and
  `playtest-teardown-garden_conduit_coop-{source,package}` each recorded both
  peers exiting 0 and zero unexpected engine errors.

- VerifyOnly `b1587c8a3ab947a995e065b6822dd2ef` completed its individual
  fixtures and four-peer smoke, then refused release because Godot rewrote the
  female traveller's generated hair texture import settings. The playtest
  export now uses Godot's single-threaded importer. It rejects engine errors
  and substantive changes to any tracked import settings, preserving line
  endings for fingerprint verification. This is confined to playtest export.
  The earlier records were only reused for matching keys and log hashes,
  and required candidate/startup/network checks ran again on the final EXE.
  [Godot import threading](https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/editor/file_system/editor_file_system.cpp#L3092)

- The parallel intermediate smoke `20261113-180109-bf9b9ce7` failed on
  missing movement and snapshots. Its isolated retry
  `20261113-180152-e76f0050` passed all four processes and the official
  package verifier. A separate environment also encoded the title separators
  in a Windows code page. Retail probes now match the ASCII version, protocol
  and route fields independently of that separator encoding.

## Exact pipeline release candidate

| Evidence | Result |
|---|---|
| Tested build revision | `c15b2591c5e623e6f176c099e0f860e543a467e0` |
| Tested-input manifest | 1,453 paths, exact committed Git tree match, SHA-256 `1e0def18cd46c1ec8d3f85bba442cea44a7c0e78fae10cc45c169a6adc36e3f2` |
| Connected source `20261113-180923-2015f4d7` | All 168 suites reverified through the planner's existing lineage. Source runner and runtime unchanged from `20261113-174304-b5cc30e1`, which executed the two corrected co-op fixtures and reused 166. All 221 source process exits were 0 |
| Python self-tests | 57 passed, including the 54 existing planner tests |
| Focused preview | 16 suites for the three runtime files, zero unmapped inputs |
| Windows VerifyOnly `dfa75cd2d7314153bfded9e225f0970b` | Passed, 15 fresh checks, 25 fresh process exits all 0, 122 hash-verified reused package suites |
| Windows x64 EXE | `3a661fecf2f5bc042e881b906cfd9c886c71bf7ec212af5f97c2f1c92536e609` |
| Native DLL | `ad827586970b7d701af85007185fa2ef31213666add81674d47c3dab96370379` |

The builder's retail acceptance exercised 11 standalone
processes. Fresh launch and matching-identity reopen displayed the exact
version. Adjacent project overrides and external script injection did not
override the playtest or run a test driver. Missing DLL and invalid DLL were
refused before the title initialized, with three expected loader errors per
probe. Redirected AppData, a junction into the prototype root, a hard-linked
settings file and a mismatched save identity were refused. The newer-version
marker remained byte-identical. The standalone probe IDs use the
`0.1.0-playtest.1-` prefix and are stored in the archive's retail record.
No unexpected engine errors were observed.

## Completed archive

The one-command acceptance build exited 0. It produced
`C:/Users/sutte/Documents/Codex/MG7/0.1.0-playtest.1`. Use the repository's
[playtest workflow](PLAYTEST_RELEASE_PIPELINE.md) for the command, archive
layout, historical rebuild and explicit approval procedure.

| Archive evidence | Value |
|---|---|
| ZIP SHA-256 | `25a76824e797bcabb826bda705ebe7ddac4ab8eb292266caa7ef194858b61e04` |
| Release manifest SHA-256 | `f236fcac684e16c7ef3168f2b1c7bafeec592ced7509641984b436ae78befd96` |
| ZIP length | 116,480,252 bytes |
| Build UTC | `2026-11-13T23:09:49.4069096Z` |
| Four-peer smoke | `20261113-181220-31be06b6`, host and three guests exited 0 |
| Packaged candidate party fixture SHA-256 | `d6628ef828d8946f3f498e1561040e9ffda415179316aeb00310044586f579bd` |
| Garden conduit fixture SHA-256 | `1f04ba96bcb8612bb6b868d46a0fd36c2e266203873a27d691e44a85f96fd3ac` |
| Garden returns fixture SHA-256 | `da3ed66e52ae529161e3832699f66f94bb1ab47b57ade2103ef2e17151b2eaf3` |

Independent ZIP inspection verified the full member set, all sizes and hashes,
and byte equality of the bundled and archived manifests. The sample excerpt
below comes from the archive.

```json
{
  "version": "0.1.0-playtest.1",
  "git_commit": "c15b2591c5e623e6f176c099e0f860e543a467e0",
  "git_tag": null,
  "godot": "4.7.2.stable.official.ed1daf0bf",
  "target": "Windows x86_64",
  "multiplayer_protocol": 40,
  "save_root": "%APPDATA%/Mystical Garden Playtest 0.1.0-playtest.1",
  "source_run_id": "20261113-180923-2015f4d7",
  "package_run_id": "dfa75cd2d7314153bfded9e225f0970b"
}
```

The source revision was fast-forwarded onto the existing local
`ac06/persistence` branch. The report is a documentation-only follow-up
to the tested implementation. `main` remains at
`020cf68f11a5e1d30fbee3b90f349b3ca3c2921c`. The approval command was
checked against a sample archive with mocked Git. No release tag or
remote was created.

## Distribution boundary

The ZIP excludes source, fixture scripts, local evidence, diagnostics, and
player data. Local archives retain the exact log indexes and their
hash-checked logs. A build interruption can leave `.cache/build.lock`
and a staging directory. If a build was interrupted, confirm the recorded PID
no longer owns a build before removing its lock. Retain the staging evidence.
The engine can create the versioned directory before game code starts.
The refusal probes checked that this does not open canonical state or
start the diagnostic journal. The path checks assume a local filesystem
without concurrent external tampering.

## Manual acceptance and approval

Inspect the title, settings and version text on a normal Windows desktop and
exercise character/Garden creation and reopening. Run separate-PC co-op from
the same ZIP. Approval for testers is a separate step. The build process leaves
the installed executable, installed DLL and live saves alone. It leaves
`PRODUCTION_CUTOVER_APPROVED` false and `VERIFIED_WRITERS` empty. Production
activation remains NO-GO.
