#!/usr/bin/env sh
set -eu

docker compose exec wordpress bash -lc "/usr/local/bin/install-required-plugins.sh"

echo "Ready"