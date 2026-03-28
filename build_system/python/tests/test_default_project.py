from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from rmq_tmds_build.default_project import read_default_project, write_default_project


class DefaultProjectTests(unittest.TestCase):
    def test_write_and_read_default_project(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            base = Path(temp_dir)
            project = base / "sample.gprj"
            project.write_text("<Project/>\n", encoding="utf-8")
            marker = write_default_project(base, project)
            self.assertTrue(marker.exists())
            resolved = read_default_project(base)
            self.assertEqual(resolved, project.resolve())


if __name__ == "__main__":
    unittest.main()
