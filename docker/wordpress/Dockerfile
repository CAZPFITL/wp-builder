FROM wordpress:latest

# Install system dependencies and tools
COPY docker/scripts/install-system-dependencies.sh /tmp/
RUN chmod +x /tmp/install-system-dependencies.sh && /tmp/install-system-dependencies.sh

# Optional: allow WP-CLI as root without warnings
ENV WP_CLI_ALLOW_ROOT=1

# Script to install Composer dependencies in the active theme
COPY docker/scripts/install-theme-dependencies.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/install-theme-dependencies.sh