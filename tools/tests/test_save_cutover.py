"""Disposable NTFS fixtures for the offline AC-06 deployment boundary."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import save_cutover as cutover


@unittest.skipUnless(os.name == "nt", "Windows fixed NTFS deployment contract")
class SaveCutoverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mg-cutover-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.backup = self.root / "frozen-backup"
        self.backup.mkdir()
        (self.backup / "saves/characters/slot_1").mkdir(parents=True)
        (self.backup / "saves/slot_1").mkdir()
        (self.backup / "saves/slot_1/garden.cfg").write_bytes(b'[world]\r\nseed=17\r\n')
        (self.backup / "saves/characters/slot_1/character.cfg").write_bytes(b'[profile]\r\nclass_xp=123.4\r\n')
        self.plan_path = self.root / "reviewed.json"
        self.destination = self.root / cutover.policy()["root_name"]

    def plan(self):
        value = cutover.inspect_backup(self.backup)
        self.plan_path.write_bytes(cutover.canonical(value))
        return cutover.sha(self.plan_path.read_bytes())

    def test_read_only_inspection_and_exact_copy(self):
        before = cutover.inventory(self.backup)
        digest = self.plan()
        self.assertEqual(cutover.inventory(self.backup), before)
        self.assertFalse(self.destination.exists())
        self.assertEqual(cutover.stage(self.plan_path, digest, self.destination)["status"], "published")
        self.assertEqual(cutover.verify(self.plan_path, digest, self.destination)["status"], "verified_initial_copy")
        self.assertEqual(cutover.inventory(self.backup), before)

    def test_repeat_cannot_reimport_over_new_progress(self):
        digest = self.plan()
        cutover.stage(self.plan_path, digest, self.destination)
        target = self.destination / "saves/characters/slot_1/character.cfg"
        target.write_bytes(b"new progress, never replaced")
        self.assertEqual(cutover.stage(self.plan_path, digest, self.destination)["status"], "already_published")
        self.assertEqual(target.read_bytes(), b"new progress, never replaced")
        with self.assertRaisesRegex(ValueError, "differs"):
            cutover.verify(self.plan_path, digest, self.destination)

    def test_interruption_resumes_from_verified_copies(self):
        digest = self.plan()
        def interrupt(phase, _path):
            if phase == "copied":
                raise InterruptedError("controlled termination")
        with self.assertRaises(InterruptedError):
            cutover.stage(self.plan_path, digest, self.destination, interrupt)
        self.assertFalse(self.destination.exists())
        self.assertTrue(self.destination.with_name(self.destination.name + cutover.STAGE_SUFFIX).exists())
        cutover.stage(self.plan_path, digest, self.destination)
        cutover.verify(self.plan_path, digest, self.destination)

    def test_real_process_termination_before_publish(self):
        digest = self.plan()
        script = ("import os,sys;sys.path.insert(0,sys.argv[1]);import save_cutover as c;"
                  "c.stage(sys.argv[2],sys.argv[3],sys.argv[4],"
                  "lambda phase,path:os._exit(73) if phase=='before_publish' else None)")
        result = subprocess.run([sys.executable, "-B", "-c", script, str(cutover.POLICY_FILE.parents[2] / "tools"),
                                 str(self.plan_path), digest, str(self.destination)], capture_output=True, timeout=30,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
        self.assertFalse(self.destination.exists())
        cutover.stage(self.plan_path, digest, self.destination)
        cutover.verify(self.plan_path, digest, self.destination)

    def test_partial_or_changed_staging_is_preserved_and_refused(self):
        digest = self.plan()
        def interrupt(phase, path):
            if phase == "copied":
                raise InterruptedError(path)
        with self.assertRaises(InterruptedError):
            cutover.stage(self.plan_path, digest, self.destination, interrupt)
        staging = self.destination.with_name(self.destination.name + cutover.STAGE_SUFFIX)
        target = next(staging.glob("saves/**/character.cfg"))
        target.write_bytes(b"incomplete")
        with self.assertRaisesRegex(ValueError, "Incomplete or changed"):
            cutover.stage(self.plan_path, digest, self.destination)
        self.assertEqual(target.read_bytes(), b"incomplete")
        self.assertFalse(self.destination.exists())

    def test_wrong_plan_hash_or_source_drift_creates_no_destination(self):
        digest = self.plan()
        with self.assertRaisesRegex(ValueError, "manifest hash"):
            cutover.stage(self.plan_path, "0" * 64, self.destination)
        (self.backup / "saves/slot_1/garden.cfg").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "no longer matches"):
            cutover.stage(self.plan_path, digest, self.destination)
        self.assertFalse(self.destination.exists())

    def test_existing_foreign_or_empty_destination_never_replaced(self):
        digest = self.plan()
        self.destination.mkdir()
        with self.assertRaises((ValueError, FileNotFoundError)):
            cutover.stage(self.plan_path, digest, self.destination)
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_wrong_root_name_or_nested_destination_refused(self):
        digest = self.plan()
        for destination in (self.root / "Mystical Garden Prototype", self.backup / self.destination.name):
            with self.subTest(destination=destination), self.assertRaises(ValueError):
                cutover.stage(self.plan_path, digest, destination)
            self.assertFalse(destination.exists())

    def test_live_roots_and_ancestors_are_not_backups(self):
        roaming = self.root / "roaming"
        live = roaming / "Mystical Garden Prototype"
        live.mkdir(parents=True)
        with patch.dict(os.environ, APPDATA=str(roaming), USERPROFILE=str(self.root / "profile")):
            for source in (live, roaming):
                with self.assertRaisesRegex(ValueError, "live save root"):
                    cutover.inspect_backup(source)

    def test_pending_recovery_leases_and_playtest_roots_refused(self):
        for name in ("garden.cfg.transaction", "garden.cfg.txn_link", "garden.cfg.txn_stage", "garden.cfg.recovery",
                     "catalog.cfg.tmp", "garden.cfg.txn_expected", "garden.cfg.txn_receipt", "garden.cfg.txn_previous",
                     "garden.cfg.txn_publish", "garden.cfg.TRANSACTION", "Session.cfg",
                     "session.cfg", "playtest.identity", "guarded-root.json", ".cutover-plan.json"):
            path = self.backup / name
            path.write_bytes(b"retained evidence")
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "evidence"):
                cutover.inspect_backup(self.backup)
            self.assertEqual(path.read_bytes(), b"retained evidence")
            path.unlink()  # Only this fixture-created file.

    def test_hard_links_and_directory_junctions_refused(self):
        leaf = self.backup / "saves/slot_1/garden.cfg"
        alias = self.backup / "alias.cfg"
        os.link(leaf, alias)
        with self.assertRaisesRegex(ValueError, "hard-linked"):
            cutover.inspect_backup(self.backup)
        alias.unlink()
        junction = self.backup / "redirected"
        made = subprocess.run(["cmd", "/c", "mklink", "/J", str(junction), str(self.root)],
                              capture_output=True, timeout=15, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        self.assertEqual(made.returncode, 0, made.stdout + made.stderr)
        try:
            with self.assertRaisesRegex(ValueError, "Redirected"):
                cutover.inspect_backup(self.backup)
        finally:
            junction.rmdir()  # Removes only the fixture junction, never its target.

    def test_mutating_backup_during_copy_cannot_publish(self):
        digest = self.plan()
        changed = False
        def mutate(phase, _path):
            nonlocal changed
            if phase == "copied" and not changed:
                changed = True
                (self.backup / "saves/slot_1/garden.cfg").write_bytes(b"source changed")
        with self.assertRaisesRegex(ValueError, "Backup changed"):
            cutover.stage(self.plan_path, digest, self.destination, mutate)
        self.assertFalse(self.destination.exists())

    def test_concurrent_migration_refused_without_destination_mutation(self):
        digest = self.plan()
        with cutover.destination_lock(self.destination):
            with self.assertRaisesRegex(ValueError, "busy"):
                cutover.stage(self.plan_path, digest, self.destination)
        self.assertFalse(self.destination.exists())

    def test_foreign_pending_plan_or_extra_file_blocks_resume(self):
        digest = self.plan()
        staging = self.destination.with_name(self.destination.name + cutover.STAGE_SUFFIX)
        staging.mkdir()
        (staging / cutover.PLAN_FILE).write_bytes(b"foreign")
        with self.assertRaisesRegex(ValueError, "different plan"):
            cutover.stage(self.plan_path, digest, self.destination)
        (staging / cutover.PLAN_FILE).write_bytes(self.plan_path.read_bytes())
        (staging / "unexpected.cfg").write_bytes(b"retain me")
        with self.assertRaisesRegex(ValueError, "Unexpected pending"):
            cutover.stage(self.plan_path, digest, self.destination)

    def test_root_identity_is_not_changed_by_formatting_or_operational_limits(self):
        expected = cutover.policy_digest()
        config = cutover.policy()
        alternative = self.root / "policy.json"
        alternative.write_text(json.dumps({**config, "max_files": config["max_files"] + 1}, separators=(",", ":")), encoding="utf-8")
        with patch.object(cutover, "POLICY_FILE", alternative):
            self.assertEqual(cutover.policy_digest(), expected)
        config["root_name"] = "Mystical Garden Guarded 2"
        alternative.write_text(json.dumps(config), encoding="utf-8")
        with patch.object(cutover, "POLICY_FILE", alternative):
            self.assertNotEqual(cutover.policy_digest(), expected)

    def test_every_runtime_recovery_suffix_is_refused(self):
        import re
        runtime = cutover.POLICY_FILE.parents[2]
        evidence = (runtime / "persistence_evidence.gd").read_text()
        planner = (runtime / "persistence_recovery_plan.gd").read_text()
        suffixes = set(re.findall(r'"(\.txn_[a-z_]+|\.transaction|\.recovery)"', evidence + planner))
        self.assertTrue(suffixes)
        self.assertTrue(suffixes.issubset(set(cutover.RECOVERY_SUFFIXES)), suffixes - set(cutover.RECOVERY_SUFFIXES))

    def test_empty_backup_and_verified_archives_are_preserved(self):
        empty = self.root / "empty-backup"
        empty.mkdir()
        self.backup = empty
        digest = self.plan()
        cutover.stage(self.plan_path, digest, self.destination)
        cutover.verify(self.plan_path, digest, self.destination)

    def test_limits_and_windows_reserved_components(self):
        for name in ("..", "x.", "x ", "CON.cfg", "COM1", "LPT\u00b2.cfg", "x:y", "x~1"):
            self.assertFalse(cutover.ordinary(name), name)
        config = cutover.policy()
        with patch.object(cutover, "policy", return_value={**config, "max_bytes": 2}):
            with self.assertRaises(ValueError):
                cutover.inspect_backup(self.backup)

    def test_cli_manifest_is_exact_and_refuses_overwrite(self):
        self.assertEqual(cutover.main(["inspect", str(self.backup), "--plan", str(self.plan_path)]), 0)
        previous = self.plan_path.read_bytes()
        self.assertEqual(cutover.main(["inspect", str(self.backup), "--plan", str(self.plan_path)]), 1)
        self.assertEqual(self.plan_path.read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()
