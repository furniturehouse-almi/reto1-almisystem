#!/usr/bin/env bash
# Instala WordPress para furniturehousex.com en Ubuntu Server.
# Uso: sudo DB_PASS='contraseña' bash install-wordpress.sh
set -euo pipefail

DOMINIO="${DOMINIO:-furniturehousex.com}"
WEB_DIR="${WEB_DIR:-/var/www/$DOMINIO}"
DB_NAME="${DB_NAME:-wordpress}"
DB_USER="${DB_USER:-wordpress}"
DB_PASS="${DB_PASS:?Define DB_PASS con la contraseña de la base de datos}"

apt-get update
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql \
  php-curl php-gd php-intl php-mbstring php-xml php-zip curl

# Base de datos
mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` DEFAULT CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

# WordPress
mkdir -p "$WEB_DIR"
curl -fsSL https://wordpress.org/latest.tar.gz | tar -xz -C "$WEB_DIR" --strip-components=1
cp "$WEB_DIR/wp-config-sample.php" "$WEB_DIR/wp-config.php"
sed -i "s/database_name_here/$DB_NAME/; s/username_here/$DB_USER/; s/password_here/$DB_PASS/" "$WEB_DIR/wp-config.php"
chown -R www-data:www-data "$WEB_DIR"

# VirtualHost de Apache
cat > "/etc/apache2/sites-available/$DOMINIO.conf" <<CONF
<VirtualHost *:80>
    ServerName $DOMINIO
    ServerAlias www.$DOMINIO
    DocumentRoot $WEB_DIR
    <Directory $WEB_DIR>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMINIO-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMINIO-access.log combined
</VirtualHost>
CONF

a2ensite "$DOMINIO.conf"
a2enmod rewrite
systemctl reload apache2

echo "Listo: abre http://$DOMINIO para terminar la instalación de WordPress."
