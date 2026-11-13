import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

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


if __name__ == "__main__":
    unittest.main()
