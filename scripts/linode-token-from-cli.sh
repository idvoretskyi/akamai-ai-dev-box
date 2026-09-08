#!/usr/bin/env bash
# Emit a shell export for LINODE_TOKEN from local linode-cli configuration.
# Usage:
#   eval "$(scripts/linode-token-from-cli.sh)"
#   eval "$(scripts/linode-token-from-cli.sh profile-name)"

set -euo pipefail

python3 - "$@" <<'PY'
import configparser
import os
import shlex
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
    print(f"export LINODE_TOKEN={shlex.quote(env_token)}")
    raise SystemExit(0)

cfg_override = os.environ.get("LINODE_CLI_CONFIG", "")
if cfg_override:
    cfg_path = Path(cfg_override).expanduser()
else:
    legacy = Path.home() / ".linode-cli"
    xdg_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    cfg_path = legacy if legacy.is_file() else xdg_home / "linode-cli"

if not cfg_path.is_file():
    fail(f"linode-cli config not found at {cfg_path}")

parser = configparser.ConfigParser()
parser.read(cfg_path)

selected = profile or parser.get("DEFAULT", "default-user", fallback="")
if not selected:
    fail("no linode-cli profile selected and DEFAULT.default-user is missing")

if selected != "DEFAULT" and not parser.has_section(selected):
    fail(f"linode-cli profile '{selected}' not found in {cfg_path}")

token = parser.get(selected, "token", fallback="").strip()
if not token:
    fail(f"token not found for linode-cli profile '{selected}'")

print(f"export LINODE_TOKEN={shlex.quote(token)}")
PY
