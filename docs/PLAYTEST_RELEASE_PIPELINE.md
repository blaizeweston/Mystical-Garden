# Windows playtest releases

## Build from a checkpoint

Keep `main` as the stable integration branch. Commit development checkpoints on a feature branch and build from a clean checkout. Merge into `main` only after a separate integration decision. The builder works on a detached copy of the exact commit so ignored editor caches, local assets and credentials never become build inputs.

```powershell
.\tools\build_playtest.ps1 -Version 0.1.0
.\tools\build_playtest.ps1 -Version 0.1.0-playtest.2 -ArchiveRoot 'C:\Playtests\MysticalGarden'
```

The short version in the first command expands to `0.1.0-playtest.1`. Use PowerShell 7, Python 3.11 or newer, Git, and the official Windows x64 Godot 4.7.2 editor and release templates. Set `-Engine` when the editor is installed away from the usual project parent. The builder uses the existing Connected source validation, VerifyOnly export, and package evidence verifier. It then launches the actual retail EXE in disposable profiles to verify the title, build label, backend and save isolation.

The default archive is `%USERPROFILE%\Documents\MG-Playtests`. Use `-ArchiveRoot` to choose a shorter local directory if needed. The builder's temporary Git tree and multiplayer fixtures inherit this path, and both Windows and the native save layer impose path limits. A failed build stays under `.staging`; the final version folder appears only after validation, retail probes and ZIP rehashing pass. A prior completed version or local tag blocks reuse of its name.

```text
MG-Playtests/
  .staging/<attempt>/                  # Failed or incomplete builds and their logs
  .cache/validation/                  # Hash-checked reusable fixture evidence
  0.1.0-playtest.1/
    Mystical-Garden-0.1.0-playtest.1-win64.zip
    SHA256SUMS.txt
    manifest.json
    game/
      Mystical Garden.exe             # Embedded PCK
      b0_native_lock.dll
      BUILD_INFO.txt
      README_PLAYTEST.txt
      manifest.json
      licenses/persistence_lock.gdextension
      licenses/ART_CREDITS.md
    evidence/                         # Tested inputs, run IDs and local build logs
```

The package manifest records every payload member except itself. `SHA256SUMS.txt` records the ZIP and manifest hashes separately. Only share the ZIP and its checksum. The local evidence folder contains disposable path and validation context that testers do not need. The DLL and embedded extension descriptor come from the verified export. The text descriptor in `licenses` is a reference copy.

The **Build Playtest** and **Approve Playtest** Windows shortcuts load the local
`Tools/workspace.json` beside the project. Build uses its workspace, export stage,
evidence and release directories. Enter an archive override at the prompt when
needed. From the project directory, the same launcher can preview without writing:

~~~powershell
.\tools\playtest\launch_playtest.ps1 -Mode Build -Version 0.1.0-playtest.5 -PlanOnly
.\tools\playtest\launch_playtest.ps1 -Mode Approve -Version 0.1.0-playtest.2 -PlanOnly
~~~

The launcher also accepts an explicit `-Config` or `-ArchiveRoot`. Use
`-LegacyDefaults` to skip the workspace config. The direct build and approval
scripts keep their no-config defaults and also accept explicit overrides.

The shortcut checks the local release archive and known historical roots for
duplicate versions. Approval preview verifies the ZIP and shows the exact archive,
commit and hashes. Identical copies prefer the configured archive. Conflicting
copies require an explicit archive. The approval prompt applies only to the
previewed identity, and the preview creates no tag or approval record.

## Approve and tag

After visually checking the Windows title, displayed version, character and Garden creation, and separate-PC co-op with the exact ZIP, explicitly approve that archive from the project checkout:

```powershell
.\tools\playtest\approve_playtest.ps1 -Version 0.1.0
```

Pass the same `-ArchiveRoot` if the archive is elsewhere. This checks the ZIP and manifest hashes, validates every member, creates the annotated local tag for the archived commit, and writes `approval.json` beside the ZIP. The original manifest has `git_tag: null` because it predates approval. The tag and approval record preserve the ZIP hash without changing the ZIP. A build does not tag, merge, push, or install anything.

For a historical inspection, open its archived manifest and validation summary. For a reproducibility build, use a detached checkout of the recorded commit and a disposable archive. The build embeds its UTC creation time, so a new build does not reproduce the original ZIP bytes. Keep the original ZIP for rollback. If the original version already has a local approval tag, use a disposable clone containing the commit and without that tag. The builder still refuses duplicate versions within the selected archive.

## Save boundary and rollback

A retail playtest uses `%APPDATA%\Mystical Garden Playtest <full-version>`. This is a sibling of `Mystical Garden Prototype`. The default project and installed game retain the prototype setting. All playtest `user://` paths, including the roster, Developer/Preview paths, archives, recovery artifacts, settings, diagnostics and native sentinel, resolve against the version-specific root. Development-only controls are hidden. Native authorization remains active on the existing legacy-contained route.

A matching version and commit can reopen its own save set. A different playtest version starts fresh. The early root check rejects nonstandard or redirected AppData, reparse points, case-sensitive directories, hard-linked files, missing or incompatible native backend, and a missing or mismatched identity on populated storage. This is designed for default local Windows AppData on fixed NTFS. Arbitrary live filesystem tampering, interrupted identity-file creation and relocated user profiles are outside supported operation. If the game refuses the root, keep the files and restore a matching backup through ordinary Windows file management after the game is closed.

The supported rollback is to extract the old ZIP separately and leave its original versioned save directory in place. Never copy forward saves into an older directory. Automatic migration and cross-version save compatibility require a separate implementation and acceptance. The playtest builder neither changes the multiplayer protocol nor enables guarded production persistence.

The retail configuration disables project-setting overrides only for the stock release template. Editor-driven fixtures still launch through the established verifier with isolated disposable AppData. Retail verification launches the executable itself and checks that an adjacent override and an external script do not change that behavior. [Godot user directory resolution](https://github.com/godotengine/godot/blob/ed1daf0bf/core/os/os.cpp#L318) · [Godot project overrides](https://github.com/godotengine/godot/blob/ed1daf0bf/core/config/project_settings.cpp#L689)
