FROM wordpress:latest

RUN apt-get update && apt-get install -y \
    less \
    mariadb-client \
    curl \
    unzip \
    default-mysql-client \
 && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional: allow WP-CLI as root without warnings
ENV WP_CLI_ALLOW_ROOT=1