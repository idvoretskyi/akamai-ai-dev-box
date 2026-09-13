#!/usr/bin/env bash
# Emit a LINODE_TOKEN value from local linode-cli configuration.
# Usage:
#   LINODE_TOKEN="$(scripts/linode-token-from-cli.sh)"; export LINODE_TOKEN
#   LINODE_TOKEN="$(scripts/linode-token-from-cli.sh profile-name)"; export LINODE_TOKEN

set -euo pipefail

python3 - "$@" <<'PY'
import configparser
import os
import sys
from pathlib import Path


def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) > 2:
    fail("usage: linode-token-from-cli.sh [profile]")

profile = sys.argv[1] if len(sys.argv) == 2 else None

env_token = os.environ.get("LINODE_CLI_TOKEN", "")
if env_token:
    if profile:
        fail("LINODE_CLI_TOKEN is set; unset it before selecting a saved profile")
    print(env_token)
    raise SystemExit(0)

cfg_override = os.environ.get("LINODE_CLI_CONFIG", "")
if cfg_override:
    cfg_path = Path(cfg_override).expanduser()
else:
    legacy = Path.home() / ".linode-cli"
    xdg_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    cfg_path = legacy if legacy.is_file() else xdg_home / "linode-cli"

if not cfg_path.is_file():
    fail("linode-cli config not found; set LINODE_CLI_CONFIG or run linode-cli configure")

parser = configparser.ConfigParser()
try:
    parser.read(cfg_path)
except (configparser.Error, OSError):
    fail("unable to read linode-cli config")

selected = profile or parser.get("DEFAULT", "default-user", fallback="")
if not selected:
    fail("no linode-cli profile selected and DEFAULT.default-user is missing")

if selected != "DEFAULT" and not parser.has_section(selected):
    fail("selected linode-cli profile was not found")

token = parser.get(selected, "token", fallback="").strip()
if not token:
    fail("token not found for selected linode-cli profile")

print(token)
PY
