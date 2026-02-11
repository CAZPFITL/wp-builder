#!/usr/bin/env sh
set -eu

docker compose run --rm blocks npm run build && docker compose run --rm vite npm run build && upf

echo "Ready"