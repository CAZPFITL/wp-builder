#!/usr/bin/env sh
set -eu

docker compose exec -T wordpress wp --allow-root my-wp-tables-migrate --force=true
docker compose exec -T wordpress sh -lc "cd wp-content/themes/${ACTIVE_THEME:-travel-concierge-me-theme} && composer dump-autoload -o"

echo "Ready"