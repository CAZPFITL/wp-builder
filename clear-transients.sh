#!/bin/bash

# Script to clear WordPress transients
# Transients are cached data stored in wp_options table that can cause issues during development

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧹 Clearing WordPress transients..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if containers are running
if ! docker compose ps wordpress | grep -q "Up"; then
    echo "⚠️  WordPress container is not running. Starting containers..."
    docker compose up -d wordpress
    echo "⏳ Waiting for WordPress to be ready..."
    sleep 5
fi

# Delete all transients using WP-CLI
echo "🗑️  Deleting all transients..."
docker compose exec -T wordpress wp transient delete --all --allow-root

# Optional: Delete expired transients only (uncomment if you prefer this)
# docker compose exec -T wordpress wp transient delete --expired --allow-root

# Clear object cache if using persistent cache (Redis, Memcached)
if docker compose exec -T wordpress wp cache flush --allow-root 2>/dev/null; then
    echo "💾 Object cache flushed"
fi

# Database optimization (optional)
echo "🔧 Optimizing database tables..."
docker compose exec -T db mysql -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" \
    -e "OPTIMIZE TABLE ${PREFIX}options;" 2>/dev/null || echo "⚠️  Database optimization skipped"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Transients cleared successfully!"
echo ""
echo "📊 Current transient count:"
docker compose exec -T wordpress wp transient list --allow-root | wc -l || echo "0"

echo ""
echo "💡 Tip: Run this script whenever you experience caching issues during development"
