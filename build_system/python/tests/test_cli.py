from __future__ import annotations

import unittest

from rmq_tmds_build.cli import parse_overrides


class CliTests(unittest.TestCase):
    def test_parse_overrides_normalizes_keys(self) -> None:
        overrides = parse_overrides(["video_mode=720p", "RUN_PROCESS=pnr"])
        self.assertEqual(overrides["VIDEO_MODE"], "720p")
        self.assertEqual(overrides["RUN_PROCESS"], "pnr")

    def test_parse_overrides_rejects_non_assignment(self) -> None:
        with self.assertRaises(Exception):
            parse_overrides(["VIDEO_MODE"])


if __name__ == "__main__":
    unittest.main()
