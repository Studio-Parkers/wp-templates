FROM php:8.1-apache as development
WORKDIR /var/www/html

# Install required packages
RUN apt-get update && apt-get install -y git zip && docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Enable the rewite module for htaccesss
RUN a2enmod rewrite

# Install composer and its packages
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ADD auth.json composer.json ./
RUN composer install

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp

# Create apache config
RUN echo "<VirtualHost *:80>\n\tServerAdmin webmaster@localhost\n\tDocumentRoot /var/www/html/web\n\tDirectoryIndex index.php index.html index.htm\n\n\tErrorLog ${APACHE_LOG_DIR}/error.log\n\tCustomLog ${APACHE_LOG_DIR}/access.log combined\n\n\t<Directory /var/www/html/web>\n\t\tOptions -Indexes\n\t\t<IfModule mod_rewrite.c>\n\t\t\tRewriteEngine On\n\t\t\tRewriteBase /\n\t\t\tRewriteRule ^index.php$ - [L]\n\t\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\t\tRewriteCond %{REQUEST_FILENAME} !-d\n\t\t\tRewriteRule . /index.php [L]\n\t\t</IfModule>\n\t</Directory>\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

ADD web/app /var/www/html/web/app

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_RUN_DIR /var/lib/apache/runtime
ENV APACHE_PID_FILE /var/run/apache2.pid

RUN mkdir -p ${APACHE_RUN_DIR} && mkdir -p ${APACHE_LOG_DIR} && cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/conf.d/php.ini

CMD ["apache2", "-D", "FOREGROUND"]

FROM development as production

ADD config /var/www/html/config
ADD web/app /var/www/html/web/app
ADD web/index.php /var/www/html/web/index.php
ADD web/wp-config.php /var/www/html/web/wp-config.php
ADD auth.json /var/www/html/auth.json
ADD phpcs.xml /var/www/html/phpcs.xml
ADD wp-cli.yml /var/www/html/wp-cli.yml

# Uncomment the following lines if the project uses node
# # Install Node
# ARG NODE_VERSION
# ENV NODE_VERSION=$NODE_VERSION
# RUN apt install -y curl
# RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
# ENV NVM_DIR=/root/.nvm
# RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
# RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
# RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
# ENV PATH="/root/.nvm/versions/node/v${NODE_VERSION}/bin/:${PATH}"

# RUN npm install --global yarn && yarn install && yarn build