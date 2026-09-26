ARG PHP_VERSION=8.5
FROM php:${PHP_VERSION}-cli-alpine

RUN apk add --no-cache bash git unzip
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Composer picks the newest tool versions that run on this image's PHP.
# Majors are pinned so a rebuild can't suddenly fail every project; bump them on purpose.
ENV COMPOSER_HOME=/opt/tools COMPOSER_ALLOW_SUPERUSER=1 PATH=/opt/tools/vendor/bin:$PATH
RUN composer global config --no-plugins allow-plugins.dealerdirect/phpcodesniffer-composer-installer true \
 && composer global require --no-interaction --no-progress \
      "phpstan/phpstan:^2" \
      "squizlabs/php_codesniffer:^3.13 || ^4" \
      "phpmd/phpmd:^2" \
      "php-parallel-lint/php-parallel-lint:^1" \
      "staabm/annotate-pull-request-from-checkstyle:^1" \
      "micheh/phpcs-gitlab:^2" \
      dealerdirect/phpcodesniffer-composer-installer \
      "phpcompatibility/php-compatibility:^9.3 || ^10.0@alpha" \
 && composer clear-cache

COPY config /opt/pure/config
COPY bin/pure /usr/local/bin/pure

WORKDIR /app
CMD ["pure"]
