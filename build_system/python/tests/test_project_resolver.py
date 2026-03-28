from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from rmq_tmds_build.paths import REPO_ROOT
from rmq_tmds_build.project_config import save_project_config
from rmq_tmds_build.project_resolver import resolve_project_context
from rmq_tmds_build.actions import ActionError


class ProjectResolverTests(unittest.TestCase):
    def test_repo_root_defaults_tang_nano_to_tmds(self) -> None:
        context = resolve_project_context("tang-nano-20k", ".")
        self.assertEqual(context.design, "tmds")
        self.assertEqual(context.project_file, REPO_ROOT / "platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj")

    def test_blinky_path_infers_blinky_design(self) -> None:
        context = resolve_project_context("tang-nano-20k", "bringup/blinky-tang-nano-20k")
        self.assertEqual(context.design, "blinky")
        self.assertEqual(context.project_file, REPO_ROOT / "bringup/blinky-tang-nano-20k/blinky-tang-nano-20k.gprj")

    def test_puhzi_board_path_infers_tmds_without_project_file(self) -> None:
        context = resolve_project_context("puhzi-pa200-fl-kfb", "platform/artix/boards/puhzi-pa200-fl-kfb")
        self.assertEqual(context.design, "tmds")
        self.assertEqual(context.project_file, REPO_ROOT / "platform/artix/boards/puhzi-pa200-fl-kfb/top.v")

    def test_gowin_context_rejects_non_gprj_project_override(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "top.v").write_text("module top; endmodule\n", encoding="utf-8")
            save_project_config(root, {"project_file": "top.v", "preferred_toolchain": "gowin"})
            with self.assertRaises(ActionError):
                resolve_project_context("tang-nano-20k", str(root))


if __name__ == "__main__":
    unittest.main()
