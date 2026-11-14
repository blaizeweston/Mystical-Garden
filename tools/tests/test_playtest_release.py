import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import playtest_release as release


class PlaytestReleaseTests(unittest.TestCase):
    def test_version_is_canonical_and_path_safe(self):
        self.assertEqual(release.version_name("0.1.0"), "0.1.0-playtest.1")
        self.assertEqual(release.version_name("0.1.0-playtest.2"), "0.1.0-playtest.2")
        for version in ("../0.1.0", "01.0.0", "0.1.0-playtest.0", "0.1.0\n", "0.1.0+local"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.version_name(version)

    @patch.object(release, "git")
    def test_refuses_dirty_and_hidden_index_entries(self, git):
        git.return_value = b" M project.godot\0"
        with self.assertRaisesRegex(ValueError, "clean checkout"):
            release.source_revision()
        git.side_effect = [b"", b"h project.godot\0"]
        with self.assertRaisesRegex(ValueError, "Git index"):
            release.source_revision()

    def test_config_is_opt_in_and_explicit_paths_win(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            args = SimpleNamespace(config=None, workspace=None, stage=None, evidence=None, archive=None, engine=None)
            with (patch.object(release, "REPO", root / "Mystical Garden"),
                  patch.object(release, "archive_path", side_effect=lambda value: Path(value or release.DEFAULT_ARCHIVE)),
                  patch.object(release.Path, "home", return_value=root / "user"),
                  patch.dict(os.environ, APPDATA=str(root / "app"), LOCALAPPDATA=str(root / "local"))):
                defaults = release.output_options(args)
                self.assertFalse(defaults.configured)
                self.assertEqual(defaults.archive, release.DEFAULT_ARCHIVE)
                args.config = root / "workspace.json"
                args.config.write_text(json.dumps({"ArchiveRoot": str(root / "Releases"), "Engine": "recorded"}))
                args.engine = "explicit"
                result = release.output_options(args)
                self.assertTrue(result.configured)
                self.assertEqual(result.engine, "explicit")
                self.assertEqual(result.archive, root / "Releases")
                self.assertEqual(result.workspace, root / "w")
                self.assertFalse(result.workspace.exists())
                args.stage = result.workspace / "nested"
                with self.assertRaisesRegex(ValueError, "distinct"):
                    release.output_options(args)
                self.assertFalse(args.stage.exists())
                args.stage = None
                args.config.write_text('{"Typo":"value"}')
                with self.assertRaisesRegex(ValueError, "configuration keys"):
                    release.output_options(args)

    def test_path_preflight_creates_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            candidate = root / ("a" * 100)
            with self.assertRaisesRegex(ValueError, "shorter"):
                release.desktop_parent((candidate,), "0.1.0-playtest.3")
            with self.assertRaisesRegex(ValueError, "ordinary absolute"):
                release.output_path(root / "a" / ".." / "b")
            self.assertFalse(candidate.exists())

    def test_owned_profile_cleans_success_and_retains_failure(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            records = []
            def record(path, state):
                records.append((state, path.exists()))
            with release.owned_profile(root, record) as success:
                (success / "marker").write_text("success")
            self.assertFalse(success.exists())
            self.assertEqual(records, [("planned", False), ("allocated", True), ("removed", False)])
            with self.assertRaisesRegex(ValueError, "injected"):
                with release.owned_profile(root) as failed:
                    (failed / "marker").write_text("failure")
                    raise ValueError("injected")
            self.assertEqual((failed / "marker").read_text(), "failure")

    def test_owned_tree_can_remove_readonly_git_pack(self):
        with tempfile.TemporaryDirectory() as folder:
            parent = Path(folder)
            project = parent / "attempt"
            pack = project / "p/.git/objects/pack/sample.idx"
            pack.parent.mkdir(parents=True)
            pack.write_bytes(b"sample")
            pack.chmod(0o444)
            with self.assertRaisesRegex(ValueError, "ownership"):
                release.remove_owned_tree(project, parent / "other")
            self.assertEqual(pack.read_bytes(), b"sample")
            release.remove_owned_tree(project, parent)
            self.assertFalse(project.exists())

    def test_payload_manifest_and_archive_checksums(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            exe = root / release.GAME
            exe.write_bytes(b"executable")
            (root / release.evidence.LOCK_LIBRARY).write_bytes(b"native")
            descriptor = root / release.LOCK_DESCRIPTOR
            descriptor.parent.mkdir(parents=True)
            descriptor.write_text("[configuration]\n")
            (root / "tools").mkdir()
            (root / "tools/README_PLAYTEST.txt").write_text("@VERSION@ @ROOT@")
            (root / "evidence").mkdir()
            build = {"playtest_version": "0.1.0-playtest.1", "git_commit": "1" * 40, "built_utc": "2026-01-01T00:00:00Z",
                     "godot_version": "4.7.2", "protocol": 40, "input_manifest_sha256": "0" * 64,
                     "save_root": "Mystical Garden Playtest 0.1.0-playtest.1"}
            release.bundle(root, exe, root, build, {"source_run_id": "s", "package_run_id": "p"}, {})
            manifest = json.loads((root / "manifest.json").read_text())
            self.assertEqual(manifest["exe_sha256"], release.sha(exe))
            self.assertEqual(len(manifest["files"]), 5)
            self.assertIsNone(manifest["git_tag"])
            self.assertIn(release.sha(next(root.glob("*.zip"))), (root / "SHA256SUMS.txt").read_text())

    def test_historical_release_resolution_and_duplicate_refusal(self):
        version = "0.1.0-playtest.1"
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            preferred = root / "Releases"
            history = root / "Original"
            (history / version).mkdir(parents=True)
            identity = {"git_commit": "a" * 40, "zip_sha256": "b" * 64,
                        "manifest_sha256": "c" * 64, "already_approved": False}
            with (patch.object(release, "git", return_value=b""),
                  patch.object(release, "archive_path", side_effect=Path),
                  patch.object(release, "inspect_release", side_effect=lambda v, p: {**identity, "location": str(p)})):
                self.assertEqual(release.approval_selection(version, preferred, [history])["location"],
                                 str(history / version))
                with self.assertRaisesRegex(ValueError, "already exists"):
                    release.refuse_duplicate(version, preferred, [history])
                (preferred / version).mkdir(parents=True)
                selection = release.approval_selection(version, preferred, [preferred, history])
                self.assertEqual(selection["location"], str(preferred / version))
                self.assertEqual(selection["identical_copies"], [str(history / version)])
                with patch.object(release, "inspect_release", side_effect=[
                        identity, {**identity, "zip_sha256": "d" * 64}]):
                    with self.assertRaisesRegex(ValueError, "Conflicting copies"):
                        release.approval_selection(version, preferred, [history])
                self.assertEqual(release.approval_selection(version, history, [])["location"],
                                 str(history / version))

    @patch.object(release, "git")
    def test_approval_rejects_changed_review_identity_before_tag(self, git):
        identity = {"zip_sha256": "a" * 64, "manifest_sha256": "b" * 64}
        with (patch.object(release, "archive_path", side_effect=Path),
              patch.object(release, "inspect_release", return_value=identity)):
            with self.assertRaisesRegex(ValueError, "changed after review"):
                release.approve("0.1.0", ".", "c" * 64, identity["manifest_sha256"])
        git.assert_not_called()


if __name__ == "__main__":
    unittest.main()
