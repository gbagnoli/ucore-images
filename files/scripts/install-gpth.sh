#!/usr/bin/env bash
set -euo pipefail

# Upstream currently publishes one Linux asset, built for x86_64.
if [[ $(uname -m) != x86_64 ]]; then
    echo 'Google Photos Takeout Helper requires the reviewed x86_64 Linux asset' >&2
    exit 1
fi

gpth_version=3.4.3
gpth_sha256=605d790188c6747bdaf2d10ca216dc7743a3eb4d9d2354ec4410a45478e5c735
gpth_download=$(mktemp)
trap 'rm -f "$gpth_download"' EXIT
curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/releases/download/v${gpth_version}/gpth-linux" \
    --output "$gpth_download"
printf '%s  %s\n' "$gpth_sha256" "$gpth_download" | sha256sum --check --strict
install -o root -g root -m 0755 "$gpth_download" /usr/bin/gpth
/usr/bin/gpth --help >/dev/null
