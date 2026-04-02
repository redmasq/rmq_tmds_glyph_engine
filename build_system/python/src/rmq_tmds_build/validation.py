from __future__ import annotations

import os

from .config import toolchain_config
from .targets import ProjectContext
from .tool_discovery import check_tool


def _effective_toolchain_config(config: dict, context: ProjectContext, style: str) -> dict:
    merged = {
        "base_path": toolchain_config(config, style).get("base_path", ""),
        "executables": dict(toolchain_config(config, style).get("executables", {})),
    }
    if style == "vivado":
        merged["device_pattern"] = toolchain_config(config, style).get("device_pattern", "")
    override = context.project_config.get("toolchains", {}).get(style, {})
    if override.get("base_path"):
        merged["base_path"] = override["base_path"]
    for key, value in override.get("executables", {}).items():
        if value:
            merged["executables"][key] = value
    if style == "vivado" and override.get("device_pattern"):
        merged["device_pattern"] = override["device_pattern"]
    return merged


def validate_context_toolchain(context: ProjectContext, config: dict) -> list[str]:
    backend = context.backend
    warnings: list[str] = []

    if backend == "gowin":
        cfg = _effective_toolchain_config(config, context, "gowin")
        base_path = cfg.get("base_path", "")
        if not base_path:
            warnings.append("Gowin toolchain base path is not configured.")
        if os.name == "posix" and hasattr(os, "geteuid") and os.geteuid() != 0:
            warnings.append(
                "Gowin programming may fail without device permissions on this Linux/WSL session. "
                "If cable scan or programming fails, fix USB device access/udev rules or retry with sudo."
            )
        return warnings

    if backend == "vivado":
        cfg = _effective_toolchain_config(config, context, "vivado")
        base_path = cfg.get("base_path", "")
        if not base_path:
            warnings.append("Vivado toolchain base path is not configured.")
        return warnings

    if backend == "yosys":
        cfg = _effective_toolchain_config(config, context, "yosys")
        for key, command in cfg.get("executables", {}).items():
            if key in {"prjxray", "fasm2bels"} and not command:
                continue
            result = check_tool(key, command)
            if not result.available:
                warnings.append(f"Missing open-source tool '{key}' ({command}).")
        return warnings

    warnings.append(f"Unknown backend '{backend}' for validation.")
    return warnings
