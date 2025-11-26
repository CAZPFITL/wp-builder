#!/usr/bin/env bash
set -euo pipefail

# Preserve original WordPress entrypoint path
ORIG_ENTRYPOINT="/usr/local/bin/docker-entrypoint.sh"

# Ensure original entrypoint exists
if [ ! -x "$ORIG_ENTRYPOINT" ]; then
  echo "Original WordPress entrypoint not found at $ORIG_ENTRYPOINT" >&2
  exit 1
fi

# Informative banner
echo "➡️  wp-entrypoint: starting pre-start tasks"

# Install required plugins (won't fail if WP not installed yet)
if command -v install-required-plugins.sh >/dev/null 2>&1; then
  echo "🔌 Checking and installing required plugins (best-effort)"
  /usr/local/bin/install-required-plugins.sh || true
fi

# Install Composer dependencies for the active theme if present
ACTIVE_THEME=${ACTIVE_THEME:-}
if [ -n "$ACTIVE_THEME" ]; then
  THEME_DIR="/var/www/html/wp-content/themes/$ACTIVE_THEME"
  if [ -f "$THEME_DIR/composer.json" ]; then
    echo "📦 Installing Composer dependencies for theme: $ACTIVE_THEME"
    (cd "$THEME_DIR" && composer install --no-dev --optimize-autoloader) || true
  else
    echo "ℹ️  No composer.json found for theme: $ACTIVE_THEME"
  fi
else
  echo "ℹ️  ACTIVE_THEME not set; skipping theme dependency installation"
fi

# Hand off to the original WordPress entrypoint with received args
echo "➡️  wp-entrypoint: handing off to WordPress entrypoint"
exec "$ORIG_ENTRYPOINT" "$@"
