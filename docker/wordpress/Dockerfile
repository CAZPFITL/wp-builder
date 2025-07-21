FROM wordpress:latest

RUN apt-get update && apt-get install -y \
    less \
    mariadb-client \
    curl \
    unzip \
 && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar \
 && mv wp-cli.phar /usr/local/bin/wp
