#!/usr/bin/env bash
# Emit local OS username as JSON for the external data source.
set -euo pipefail

python3 - <<'PY'
import json
import os
import pwd

username = os.environ.get("DEVBOX_USER", "").strip()
if not username:
    username = os.environ.get("USER", "").strip()
if not username:
    username = pwd.getpwuid(os.getuid()).pw_name

print(json.dumps({"username": username}, separators=(",", ":")))
PY
