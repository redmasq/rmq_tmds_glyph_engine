from __future__ import annotations

import os
import shutil
from dataclasses import dataclass


PACKAGE_HINTS = {
    "apt-get": {
        "yosys": "sudo apt-get install yosys",
        "nextpnr-gowin": "sudo apt-get install nextpnr-gowin",
        "nextpnr-xilinx": "not currently known via apt metadata on this machine",
        "gowin_pack": "sudo apt-get install python3-apycula",
        "openFPGALoader": "sudo apt-get install openfpgaloader",
        "prjxray": "check upstream packaging or build from source",
        "vivado": "install AMD Vivado separately",
        "gowin": "install Gowin IDE separately"
    },
    "pacman": {
        "yosys": "sudo pacman -S yosys",
        "nextpnr-gowin": "check AUR or local packaging",
        "nextpnr-xilinx": "check AUR or local packaging",
        "gowin_pack": "check distribution or AUR packaging for apycula",
        "openFPGALoader": "sudo pacman -S openFPGALoader",
        "prjxray": "check AUR or build from source",
        "vivado": "install AMD Vivado separately",
        "gowin": "install Gowin IDE separately"
    },
    "brew": {
        "yosys": "brew install yosys",
        "nextpnr-gowin": "check Homebrew packaging or build from source",
        "nextpnr-xilinx": "check Homebrew packaging or build from source",
        "gowin_pack": "check Homebrew packaging or install apycula separately",
        "openFPGALoader": "brew install openfpgaloader",
        "prjxray": "build from source",
        "vivado": "install AMD Vivado separately",
        "gowin": "install Gowin IDE separately"
    },
    "dnf": {},
    "yum": {},
    "winget": {
        "vivado": "winget search amd vivado",
        "gowin": "install Gowin IDE separately"
    },
    "choco": {
        "vivado": "check Chocolatey or install AMD Vivado separately",
        "gowin": "install Gowin IDE separately"
    }
}


@dataclass(frozen=True)
class ToolCheck:
    key: str
    command: str
    available: bool
    resolved_path: str | None


def resolve_command(command: str) -> str | None:
    if not command:
        return None
    if os.path.sep in command and os.path.exists(command):
        return command
    return shutil.which(command)


def check_tool(key: str, command: str) -> ToolCheck:
    resolved = resolve_command(command)
    return ToolCheck(key=key, command=command, available=resolved is not None, resolved_path=resolved)


def install_hints(tool_key: str, package_managers: list[str]) -> list[str]:
    hints = []
    for manager in package_managers:
        suggestion = PACKAGE_HINTS.get(manager, {}).get(tool_key)
        if suggestion:
            hints.append(f"{manager}: {suggestion}")
    return hints
