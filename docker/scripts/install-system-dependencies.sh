#!/bin/bash

# Script to install system dependencies and tools for WordPress development

set -e

echo "🔧 Installing system dependencies..."

# Update package lists
echo "📦 Updating package lists..."
apt-get update

# Install system packages
echo "📋 Installing required system packages..."
apt-get install -y \
    less \
    mariadb-client \
    curl \
    unzip \
    default-mysql-client \
    git

# Install WP-CLI
echo "🚀 Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Verify WP-CLI installation
if command -v wp >/dev/null 2>&1; then
    echo "✅ WP-CLI installed successfully"
    # Set WP-CLI to allow root for verification
    export WP_CLI_ALLOW_ROOT=1
    wp --version
else
    echo "❌ Error: WP-CLI installation failed"
    exit 1
fi

# Install Composer
echo "🎼 Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Verify Composer installation
if command -v composer >/dev/null 2>&1; then
    echo "✅ Composer installed successfully"
    composer --version
else
    echo "❌ Error: Composer installation failed"
    exit 1
fi

# Clean up package cache
echo "🧹 Cleaning up package cache..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "🎉 System dependencies installation completed successfully!"
echo ""
echo "📋 Installed tools:"
# Ensure WP-CLI allows root for the final summary
export WP_CLI_ALLOW_ROOT=1
echo "   - WP-CLI: $(wp --version 2>/dev/null || echo 'Not available')"
echo "   - Composer: $(composer --version 2>/dev/null | head -n1 || echo 'Not available')"
echo "   - Git: $(git --version 2>/dev/null || echo 'Not available')"
echo "   - MySQL Client: $(mysql --version 2>/dev/null || echo 'Not available')"