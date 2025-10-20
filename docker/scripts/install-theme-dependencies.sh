#!/bin/bash

# Script to install Composer dependencies in the active theme

set -e

# Verify that ACTIVE_THEME is defined
if [ -z "$ACTIVE_THEME" ]; then
    echo "Error: ACTIVE_THEME is not defined"
    exit 1
fi

THEME_DIR="/var/www/html/wp-content/themes/$ACTIVE_THEME"

echo "🎨 Setting up active theme: $ACTIVE_THEME"
echo "📁 Theme directory: $THEME_DIR"

# Verify that the theme directory exists
if [ ! -d "$THEME_DIR" ]; then
    echo "❌ Error: Theme directory does not exist: $THEME_DIR"
    exit 1
fi

# Verify that composer.json exists
if [ ! -f "$THEME_DIR/composer.json" ]; then
    echo "⚠️  Warning: composer.json not found in $THEME_DIR"
    echo "   Skipping PHP dependencies installation"
    exit 0
fi

echo "📦 Installing Composer dependencies..."
cd "$THEME_DIR"

# Install Composer dependencies
composer install --no-dev --optimize-autoloader

echo "✅ Composer dependencies installed successfully in $THEME_DIR/vendor"

# Show summary
if [ -d "$THEME_DIR/vendor" ]; then
    echo "📂 Dependencies installed:"
    ls -la "$THEME_DIR/vendor" 2>/dev/null || echo "   (vendor directory created)"
fi