from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from rmq_tmds_build.project_config import load_project_config, save_project_config


class ProjectConfigTests(unittest.TestCase):
    def test_save_and_load_project_config(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            payload = {"project_file": "foo.gprj", "preferred_backend": "gowin"}
            save_project_config(root, payload)
            loaded = load_project_config(root)
            self.assertEqual(loaded["project_file"], "foo.gprj")
            self.assertEqual(loaded["preferred_toolchain"], "gowin")
            self.assertEqual(loaded["toolchains"]["gowin"]["base_path"], "")


if __name__ == "__main__":
    unittest.main()
