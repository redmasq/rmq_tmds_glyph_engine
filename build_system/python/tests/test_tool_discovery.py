from __future__ import annotations

import unittest

from rmq_tmds_build.tool_discovery import install_hints


class ToolDiscoveryTests(unittest.TestCase):
    def test_install_hints_include_apt_entries(self) -> None:
        hints = install_hints("gowin_pack", ["apt-get"])
        self.assertTrue(any("python3-apycula" in hint for hint in hints))


if __name__ == "__main__":
    unittest.main()
