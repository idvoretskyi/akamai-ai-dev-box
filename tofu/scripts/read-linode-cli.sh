#!/usr/bin/env bash
# Read region/type/image from local linode-cli config and emit JSON.
# Missing file or profile keys -> empty JSON object.

set -euo pipefail

python3 - <<'PY'
import configparser
import json
import os
from pathlib import Path


def resolve_path() -> Path:
    override = os.environ.get("LINODE_CLI_CONFIG", "").strip()
    if override:
        return Path(override).expanduser()

    legacy = Path.home() / ".linode-cli"
    if legacy.is_file():
        return legacy

    xdg_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    return xdg_home / "linode-cli"


cfg_path = resolve_path()
if not cfg_path.is_file():
    print("{}")
    raise SystemExit(0)

parser = configparser.ConfigParser()
try:
    parser.read(cfg_path)
except (configparser.Error, OSError):
    print("{}")
    raise SystemExit(0)

selected_user = parser.get("DEFAULT", "default-user", fallback="").strip()
if not selected_user:
    print("{}")
    raise SystemExit(0)

if selected_user != "DEFAULT" and not parser.has_section(selected_user):
    print("{}")
    raise SystemExit(0)

result = {}
for key in ("region", "type", "image"):
    value = parser.get(selected_user, key, fallback="").strip()
    if value:
        result[key] = value

print(json.dumps(result, separators=(",", ":")))
PY
