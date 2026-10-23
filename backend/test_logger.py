"""
backend/test_logger.py - Unit tests for daily logger CLI backend
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta
from pathlib import Path

# Add backend directory to sys.path to import directly
sys.path.insert(0, str(Path(__file__).parent.resolve()))
import logger


class TestDailyLogger(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.log_file = Path(self.test_dir) / "test_daily_logs.txt"

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_logical_date_calculation(self):
        # 02:00 AM on 2026-10-24 -> attributed to 2026-10-23
        dt_2am = datetime(2026, 10, 24, 2, 0, 0)
        self.assertEqual(logger.get_logical_date(dt_2am), "2026-10-23")

        # 04:59 AM on 2026-10-24 -> attributed to 2026-10-23
        dt_early = datetime(2026, 10, 24, 4, 59, 0)
        self.assertEqual(logger.get_logical_date(dt_early), "2026-10-23")

        # 05:00 AM on 2026-10-24 -> attributed to 2026-10-24
        dt_morning = datetime(2026, 10, 24, 5, 0, 0)
        self.assertEqual(logger.get_logical_date(dt_morning), "2026-10-24")

        # 14:00 PM on 2026-10-24 -> attributed to 2026-10-24
        dt_afternoon = datetime(2026, 10, 24, 14, 0, 0)
        self.assertEqual(logger.get_logical_date(dt_afternoon), "2026-10-24")

    def test_file_creation_and_append(self):
        self.assertFalse(self.log_file.exists())

        # Log an entry
        cmd = [
            sys.executable,
            str(Path(__file__).parent / "logger.py"),
            "--file",
            str(self.log_file),
            "log",
            "--text",
            "First log entry",
            "--date",
            "2026-10-23",
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)

        self.assertTrue(self.log_file.exists())
        lines = self.log_file.read_text(encoding="utf-8").strip().splitlines()
        self.assertEqual(len(lines), 1)

        data = json.loads(lines[0])
        self.assertEqual(data["entry"], "First log entry")
        self.assertEqual(data["date"], "2026-10-23")
        self.assertIn("id", data)
        self.assertIn("timestamp", data)

        # Append second entry
        cmd2 = [
            sys.executable,
            str(Path(__file__).parent / "logger.py"),
            "--file",
            str(self.log_file),
            "log",
            "--text",
            "Second log entry",
            "--date",
            "2026-10-24",
        ]
        res2 = subprocess.run(cmd2, capture_output=True, text=True)
        self.assertEqual(res2.returncode, 0)

        lines2 = self.log_file.read_text(encoding="utf-8").strip().splitlines()
        self.assertEqual(len(lines2), 2)
        data2 = json.loads(lines2[1])
        self.assertEqual(data2["entry"], "Second log entry")
        self.assertEqual(data2["date"], "2026-10-24")

    def test_has_logged_command(self):
        # Empty file has not logged
        cmd_check = [
            sys.executable,
            str(Path(__file__).parent / "logger.py"),
            "--file",
            str(self.log_file),
            "has-logged",
            "--date",
            "2026-10-23",
        ]
        res = subprocess.run(cmd_check, capture_output=True, text=True)
        self.assertEqual(res.returncode, 1)
        data = json.loads(res.stdout)
        self.assertFalse(data["has_logged"])

        # Add entry for that date
        cmd_add = [
            sys.executable,
            str(Path(__file__).parent / "logger.py"),
            "--file",
            str(self.log_file),
            "log",
            "--text",
            "Did some coding",
            "--date",
            "2026-10-23",
        ]
        subprocess.run(cmd_add, check=True)

        # Now check again
        res_after = subprocess.run(cmd_check, capture_output=True, text=True)
        self.assertEqual(res_after.returncode, 0)
        data_after = json.loads(res_after.stdout)
        self.assertTrue(data_after["has_logged"])
        self.assertEqual(data_after["count"], 1)

    def test_list_command(self):
        # Add 3 entries
        for i in range(1, 4):
            cmd = [
                sys.executable,
                str(Path(__file__).parent / "logger.py"),
                "--file",
                str(self.log_file),
                "log",
                "--text",
                f"Entry {i}",
                "--date",
                f"2026-10-2{i}",
            ]
            subprocess.run(cmd, check=True)

        cmd_list = [
            sys.executable,
            str(Path(__file__).parent / "logger.py"),
            "--file",
            str(self.log_file),
            "list",
            "--limit",
            "2",
            "--reverse",
        ]
        res = subprocess.run(cmd_list, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        self.assertEqual(len(data["entries"]), 2)
        self.assertEqual(data["entries"][0]["entry"], "Entry 3")
        self.assertEqual(data["entries"][1]["entry"], "Entry 2")


if __name__ == "__main__":
    unittest.main()
