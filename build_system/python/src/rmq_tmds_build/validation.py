from __future__ import annotations

from .config import toolchain_config
from .targets import ProjectContext
from .tool_discovery import check_tool


def validate_context_toolchain(context: ProjectContext, config: dict) -> list[str]:
    backend = context.backend
    warnings: list[str] = []

    if backend == "gowin":
        cfg = toolchain_config(config, "gowin")
        base_path = cfg.get("base_path", "")
        if not base_path:
            warnings.append("Gowin toolchain base path is not configured.")
        return warnings

    if backend == "vivado":
        cfg = toolchain_config(config, "vivado")
        base_path = cfg.get("base_path", "")
        if not base_path:
            warnings.append("Vivado toolchain base path is not configured.")
        return warnings

    if backend == "yosys":
        cfg = toolchain_config(config, "yosys")
        for key, command in cfg.get("executables", {}).items():
            if key in {"prjxray", "fasm2bels"} and not command:
                continue
            result = check_tool(key, command)
            if not result.available:
                warnings.append(f"Missing open-source tool '{key}' ({command}).")
        return warnings

    warnings.append(f"Unknown backend '{backend}' for validation.")
    return warnings
