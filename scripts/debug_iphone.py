#!/usr/bin/env python3
"""Run the physical-iPhone debug profile from .vscode/launch.json."""

import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PROFILE = "AI-Fit (Dev - iPhone Físico)"

with (ROOT / ".vscode/launch.json").open() as launch_file:
    configurations = json.load(launch_file)["configurations"]

config = next((item for item in configurations if item.get("name") == PROFILE), None)
if config is None:
    raise SystemExit(f"No se encontró el perfil '{PROFILE}' en .vscode/launch.json")

command = ["flutter", "run"]
if config.get("deviceId"):
    command += ["-d", config["deviceId"]]
if config.get("flutterMode"):
    command += ["--{0}".format(config["flutterMode"])]
command += config.get("toolArgs", [])
command.append(config.get("program", "lib/main.dart"))

raise SystemExit(subprocess.run(command, cwd=ROOT).returncode)
