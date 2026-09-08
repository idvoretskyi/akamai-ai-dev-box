#!/usr/bin/env bash
# Emit local OS username as JSON for the external data source.
set -euo pipefail

printf '{"username":"%s"}\n' "${USER:-$(id -un)}"
