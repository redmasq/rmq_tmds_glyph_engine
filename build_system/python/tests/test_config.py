from __future__ import annotations

import unittest

from rmq_tmds_build.config import deep_merge


class ConfigTests(unittest.TestCase):
    def test_deep_merge_overrides_nested_values(self) -> None:
        base = {"tooling": {"official_gowin": {"root": "/opt/gowin", "ide_bin": ""}}}
        override = {"tooling": {"official_gowin": {"ide_bin": "/custom/bin"}}}
        merged = deep_merge(base, override)
        self.assertEqual(merged["tooling"]["official_gowin"]["root"], "/opt/gowin")
        self.assertEqual(merged["tooling"]["official_gowin"]["ide_bin"], "/custom/bin")


if __name__ == "__main__":
    unittest.main()
