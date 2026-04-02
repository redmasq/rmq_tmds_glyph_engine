from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .paths import CONFIG_PATH, CONFIG_TEMPLATE_PATH


TOOLCHAIN_STYLES = ("yosys", "gowin", "vivado")
EDITOR_KINDS = ("text", "hex")


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_config() -> dict[str, Any]:
    config = load_json(CONFIG_TEMPLATE_PATH)
    if CONFIG_PATH.exists():
        config = deep_merge(config, load_json(CONFIG_PATH))
    return normalize_config(config)


def init_user_config(force: bool = False) -> Path:
    if CONFIG_PATH.exists() and not force:
        raise FileExistsError(f"{CONFIG_PATH} already exists")
    CONFIG_PATH.write_text(CONFIG_TEMPLATE_PATH.read_text(encoding="utf-8"), encoding="utf-8")
    return CONFIG_PATH


def save_config(config: dict[str, Any]) -> Path:
    CONFIG_PATH.write_text(json.dumps(normalize_config(config), indent=2) + "\n", encoding="utf-8")
    return CONFIG_PATH


def normalize_config(config: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(config)

    if "global" not in normalized:
        tooling = normalized.get("tooling", {})
        normalized["global"] = {
            "toolchain_preferences": {
                "gowin_family": "gowin",
                "artix_family": "vivado",
            },
            "toolchains": {
                "yosys": {
                    "auto_detect": True,
                    "base_path": "",
                    "executables": {
                        "yosys": tooling.get("opensource", {}).get("yosys", "yosys"),
                        "nextpnr_gowin": tooling.get("opensource", {}).get("nextpnr_gowin", "nextpnr-gowin"),
                        "nextpnr_xilinx": tooling.get("opensource", {}).get("nextpnr_xilinx", "nextpnr-xilinx"),
                        "gowin_pack": tooling.get("opensource", {}).get("gowin_pack", "gowin_pack"),
                        "openfpgaloader": tooling.get("opensource", {}).get("openfpgaloader", "openFPGALoader"),
                        "prjxray": tooling.get("opensource", {}).get("prjxray", ""),
                        "fasm2bels": tooling.get("opensource", {}).get("fasm2bels", ""),
                    },
                },
                "gowin": {
                    "auto_detect": True,
                    "base_path": tooling.get("official_gowin", {}).get("root", ""),
                    "executables": {
                        "ide_bin": tooling.get("official_gowin", {}).get("ide_bin", ""),
                        "programmer_bin": tooling.get("official_gowin", {}).get("programmer_bin", ""),
                    },
                },
                "vivado": {
                    "auto_detect": True,
                    "base_path": tooling.get("official_vivado", {}).get("root", ""),
                    "executables": {
                        "bin": tooling.get("official_vivado", {}).get("bin", ""),
                    },
                    "device_pattern": tooling.get("official_vivado", {}).get("device_pattern", ""),
                },
            },
        }

    global_cfg = normalized.setdefault("global", {})
    global_cfg.setdefault("toolchain_preferences", {})
    editors = global_cfg.setdefault("editors", {})
    editors.setdefault("text", {"env_var": "EDITOR", "command": "", "args_template": "{file}", "launch_mode": "terminal"})
    editors.setdefault("hex", {"env_var": "HEX_EDITOR", "command": "xxd", "args_template": "{file}", "launch_mode": "terminal"})
    prefs = global_cfg["toolchain_preferences"]
    prefs.setdefault("gowin_family", "gowin")
    prefs.setdefault("artix_family", "vivado")

    toolchains = global_cfg.setdefault("toolchains", {})
    for style in TOOLCHAIN_STYLES:
        toolchains.setdefault(style, {})
        toolchains[style].setdefault("auto_detect", True)
        toolchains[style].setdefault("base_path", "")
        toolchains[style].setdefault("executables", {})

    toolchains["yosys"]["executables"].setdefault("yosys", "yosys")
    toolchains["yosys"]["executables"].setdefault("nextpnr_gowin", "nextpnr-gowin")
    toolchains["yosys"]["executables"].setdefault("nextpnr_xilinx", "nextpnr-xilinx")
    toolchains["yosys"]["executables"].setdefault("gowin_pack", "gowin_pack")
    toolchains["yosys"]["executables"].setdefault("openfpgaloader", "openFPGALoader")
    toolchains["yosys"]["executables"].setdefault("prjxray", "")
    toolchains["yosys"]["executables"].setdefault("fasm2bels", "")
    toolchains["gowin"]["executables"].setdefault("ide_bin", "")
    toolchains["gowin"]["executables"].setdefault("programmer_bin", "")
    toolchains["vivado"]["executables"].setdefault("bin", "")
    toolchains["vivado"].setdefault("device_pattern", "")

    return normalized


def toolchain_config(config: dict[str, Any], style: str) -> dict[str, Any]:
    return normalize_config(config)["global"]["toolchains"][style]


def editor_config(config: dict[str, Any], kind: str) -> dict[str, Any]:
    return normalize_config(config)["global"]["editors"][kind]
