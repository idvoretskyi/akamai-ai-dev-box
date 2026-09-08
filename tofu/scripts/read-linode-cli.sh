#!/usr/bin/env bash
# Read region/type/image from local linode-cli config.
# Missing file or keys -> empty JSON object.

set -euo pipefail

cfg="${LINODE_CLI_CONFIG:-$HOME/.config/linode-cli}"

if [[ ! -f "$cfg" ]]; then
  echo '{}'
  exit 0
fi

awk '
  BEGIN { section = ""; user = "" }
  /^\[.*\]$/ {
    section = substr($0, 2, length($0) - 2)
    next
  }
  section == "DEFAULT" && /^[[:space:]]*default-user[[:space:]]*=/ {
    sub(/^[^=]*=[[:space:]]*/, "")
    user = $0
    next
  }
  section != "" && section == user {
    if ($0 ~ /^[[:space:]]*region[[:space:]]*=/)       { sub(/^[^=]*=[[:space:]]*/, ""); region = $0 }
    else if ($0 ~ /^[[:space:]]*type[[:space:]]*=/)    { sub(/^[^=]*=[[:space:]]*/, ""); type   = $0 }
    else if ($0 ~ /^[[:space:]]*image[[:space:]]*=/)   { sub(/^[^=]*=[[:space:]]*/, ""); image  = $0 }
  }
  END {
    printf "{"
    sep = ""
    if (region != "") { printf "%s\"region\":\"%s\"", sep, region; sep = "," }
    if (type   != "") { printf "%s\"type\":\"%s\"",   sep, type;   sep = "," }
    if (image  != "") { printf "%s\"image\":\"%s\"",  sep, image;  sep = "," }
    printf "}"
  }
' "$cfg"
