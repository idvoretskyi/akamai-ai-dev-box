#!/usr/bin/env bash
# Single source of truth for repository static checks. Used by CI
# (.github/workflows/validate.yml), CONTRIBUTING.md, and AGENTS.md.
#
# Static only: must not need cloud credentials, provision resources,
# download model weights, or call paid inference APIs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "+ tofu fmt -check"
tofu -chdir=tofu fmt -check -recursive -diff

echo "+ tofu init/validate (no backend)"
tofu -chdir=tofu init -backend=false -lockfile=readonly
tofu -chdir=tofu validate

echo "+ shell syntax and lint"
for f in \
  scripts/linode-token-from-cli.sh \
  scripts/smoke-test.sh \
  tofu/cloud-init/bootstrap.sh \
  tofu/scripts/read-linode-cli.sh \
  tofu/scripts/read-local-user.sh; do
  bash -n "$f"
  shellcheck "$f"
done

echo "+ render and schema checks"
python3 tests/check_config.py
