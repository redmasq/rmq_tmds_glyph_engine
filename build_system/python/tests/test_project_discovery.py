from __future__ import annotations

import unittest

from rmq_tmds_build.paths import REPO_ROOT
from rmq_tmds_build.project_discovery import discover_project_roots


class ProjectDiscoveryTests(unittest.TestCase):
    def test_repo_discovery_finds_known_roots(self) -> None:
        roots = {item.root for item in discover_project_roots(REPO_ROOT)}
        self.assertIn(REPO_ROOT / "bringup" / "blinky-tang-nano-20k", roots)
        self.assertIn(REPO_ROOT / "platform" / "gowin" / "boards" / "tang-primer-20k", roots)
        self.assertIn(REPO_ROOT / "platform" / "artix" / "boards" / "puhzi-pa200-fl-kfb", roots)


if __name__ == "__main__":
    unittest.main()
