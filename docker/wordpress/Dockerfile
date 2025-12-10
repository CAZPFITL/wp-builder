FROM wordpress:latest

# Install system dependencies and tools
COPY docker/scripts/install-system-dependencies.sh /tmp/
RUN chmod +x /tmp/install-system-dependencies.sh && /tmp/install-system-dependencies.sh

# Optional: allow WP-CLI as root without warnings
ENV WP_CLI_ALLOW_ROOT=1

# Script to install Composer dependencies in the active theme
COPY docker/scripts/install-theme-dependencies.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/install-theme-dependencies.sh

# Script to install required plugins from the active theme JSON
COPY docker/scripts/install-required-plugins.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/install-required-plugins.sh

# Custom entrypoint to run setup tasks and then start Apache
COPY docker/scripts/wp-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wp-entrypoint.sh

# PHP upload/timeout tweaks
COPY docker/wordpress/php.ini /usr/local/etc/php/conf.d/uploads.ini

# Apache/PHP overrides for uploads/timeouts
COPY docker/wordpress/apache-uploads.conf /etc/apache2/conf-enabled/uploads.conf

ENTRYPOINT ["/usr/local/bin/wp-entrypoint.sh"]
CMD ["apache2-foreground"]
