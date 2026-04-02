from __future__ import annotations

import os
import platform
import shutil
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class HostContext:
    platform_name: str
    is_windows: bool
    is_linux: bool
    is_macos: bool
    is_wsl: bool

    @property
    def mode_name(self) -> str:
      if self.is_wsl:
          return "wsl2-hybrid"
      if self.is_windows:
          return "windows-native"
      if self.is_linux:
          return "linux-native"
      if self.is_macos:
          return "macos-native"
      return self.platform_name


def detect_host() -> HostContext:
    system = platform.system().lower()
    release = platform.release().lower()
    is_windows = system == "windows"
    is_linux = system == "linux"
    is_macos = system == "darwin"
    is_wsl = is_linux and ("microsoft" in release or "wsl" in release or "WSL_INTEROP" in os.environ)
    return HostContext(system, is_windows, is_linux, is_macos, is_wsl)


def available_package_managers() -> list[str]:
    names = []
    for candidate in ("apt-get", "pacman", "brew", "dnf", "yum", "winget", "choco"):
        if shutil.which(candidate):
            names.append(candidate)
    return names


def python_version_ok(minimum_major: int, minimum_minor: int) -> bool:
    return sys.version_info >= (minimum_major, minimum_minor)
