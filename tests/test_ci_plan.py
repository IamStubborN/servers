"""Verify that CI planning remains read-only and keeps raw output private."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SECRET = "unpublished-secret-value"
IDENTIFIER = "ocid1.private.example"


class CiPlanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        bin_dir = self.work / "bin"
        bin_dir.mkdir()
        tofu = bin_dir / "tofu"
        tofu.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$1\" >> \"$MOCK_CALLS\"\n"
            "case \"$1\" in\n"
            "  plan)\n"
            "    if [ \"$MOCK_STATUS\" != 1 ]; then\n"
            "      for arg in \"$@\"; do\n"
            "        case \"$arg\" in -out=*) printf 'mock plan' > \"${arg#-out=}\" ;; esac\n"
            "      done\n"
            "    fi\n"
            "    printf '%s\\n' \"$MOCK_SECRET $MOCK_IDENTIFIER\"\n"
            "    exit \"$MOCK_STATUS\" ;;\n"
            "  show)\n"
            "    if [ \"${MOCK_OUTPUT_ONLY:-0}\" = 1 ]; then\n"
            "      printf '{\"resource_changes\":[],\"output_changes\":{\"hidden\":{\"change\":{\"actions\":[\"update\"],\"after\":\"%s\"}}}}' \"$MOCK_SECRET\"\n"
            "      exit 0\n"
            "    fi\n"
            "    printf '{\"resource_changes\":[{\"type\":\"oci_core_instance\",\"address\":\"%s\",\"change\":{\"actions\":[\"delete\",\"create\"],\"before\":{\"password\":\"%s\"}}}]}' \"$MOCK_IDENTIFIER\" \"$MOCK_SECRET\" ;;\n"
            "  *) exit 99 ;;\n"
            "esac\n"
        )
        tofu.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update(
            PATH=f"{bin_dir}:{self.env['PATH']}",
            CI_PRIVATE_DIR=str(self.work / "private"),
            MOCK_CALLS=str(self.work / "calls"),
            MOCK_SECRET=SECRET,
            MOCK_IDENTIFIER=IDENTIFIER,
        )

    def run_plan(self, status):
        self.env["MOCK_STATUS"] = str(status)
        return subprocess.run(
            [str(ROOT / "scripts/ci_plan.sh")],
            cwd=self.work,
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )

    def assert_private_output(self, result):
        self.assertNotIn(SECRET, result.stdout + result.stderr)
        self.assertNotIn(IDENTIFIER, result.stdout + result.stderr)
        self.assertNotIn("apply", (self.work / "calls").read_text())
        self.assertEqual((self.work / "private").stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.work / "private" / "ci-plan.log").stat().st_mode & 0o777, 0o600)

    def test_no_change(self):
        result = self.run_plan(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no changes", result.stdout)
        self.assertEqual((self.work / "calls").read_text().splitlines(), ["plan"])
        self.assert_private_output(result)

    def test_change_reports_only_counts_and_returns_two(self):
        result = self.run_plan(2)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("replace oci_core_instance: 1", result.stdout)
        self.assertEqual((self.work / "calls").read_text().splitlines(), ["plan", "show"])
        self.assert_private_output(result)
        self.assertIn(SECRET, (self.work / "private" / "ci-plan.json").read_text())
        self.assertEqual((self.work / "private" / "ci-plan.json").stat().st_mode & 0o777, 0o600)

    def test_error_returns_one_without_raw_diagnostics(self):
        result = self.run_plan(1)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Plan failed", result.stderr)
        self.assertEqual((self.work / "calls").read_text().splitlines(), ["plan"])
        self.assert_private_output(result)

    def test_output_only_change_is_counted_without_output_name_or_value(self):
        self.env["MOCK_OUTPUT_ONLY"] = "1"
        result = self.run_plan(2)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("outputs changed: 1", result.stdout)
        self.assertNotIn("hidden", result.stdout)
        self.assertEqual((self.work / "calls").read_text().splitlines(), ["plan", "show"])
        self.assert_private_output(result)

    def test_repeated_runs_remove_stale_plan_and_summary(self):
        first = self.run_plan(2)
        self.assertEqual(first.returncode, 2, first.stderr)
        private = self.work / "private"
        generated = [private / name for name in ("ci.plan", "ci-plan.json", "ci-plan-summary.txt")]
        self.assertTrue(all(path.exists() for path in generated))

        unchanged = self.run_plan(0)
        self.assertEqual(unchanged.returncode, 0, unchanged.stderr)
        self.assertTrue(generated[0].exists())
        self.assertFalse(any(path.exists() for path in generated[1:]))
        self.assert_private_output(unchanged)

        changed_again = self.run_plan(2)
        self.assertEqual(changed_again.returncode, 2, changed_again.stderr)
        self.assertTrue(all(path.exists() for path in generated))

        errored = self.run_plan(1)
        self.assertEqual(errored.returncode, 1, errored.stderr)
        self.assertFalse(any(path.exists() for path in generated))
        self.assert_private_output(errored)


if __name__ == "__main__":
    unittest.main()
