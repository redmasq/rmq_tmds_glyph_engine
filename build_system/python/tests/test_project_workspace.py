from __future__ import annotations

import unittest

from rmq_tmds_build.paths import REPO_ROOT
from rmq_tmds_build.project_workspace import resolve_workspace


class ProjectWorkspaceTests(unittest.TestCase):
    def test_repo_root_does_not_expand_nested_bringup_contexts(self) -> None:
        workspace = resolve_workspace(REPO_ROOT)
        contexts = {(context.board, context.design, context.base_path) for context in workspace.contexts}
        self.assertIn(("tang-nano-20k", "tmds", REPO_ROOT), contexts)
        self.assertIn(("tang-primer-20k", "tmds", REPO_ROOT), contexts)
        self.assertIn(("puhzi-pa200-fl-kfb", "tmds", REPO_ROOT), contexts)
        self.assertNotIn(("tang-nano-20k", "blinky", REPO_ROOT / "bringup" / "blinky-tang-nano-20k"), contexts)


if __name__ == "__main__":
    unittest.main()
