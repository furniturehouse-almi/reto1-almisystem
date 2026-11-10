#!/bin/bash
# =====================================================================
#  Intranet Laravel -> base de datos del clúster SQL Server (FHSQL)
#  y red de la oficina (192.168.12.0/24).
#  Uso:  sudo bash bd-sqlsrv.sh
#  - Pide la contraseña de la BD por teclado: no se guarda en este archivo.
#  - Deja la IP fija preparada para el 2º adaptador (puente).
# =====================================================================
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta así:  sudo bash bd-sqlsrv.sh"; exit 1; }

APP=/var/www/furniturehouse
USUARIO="${SUDO_USER:-paul}"
IP_OFICINA="${IP_OFICINA:-192.168.12.40}"   # confirmar con P1 que está libre
DNS_DC=192.168.12.10
DOMINIO_AD=ad.furniturehouse2.com
IFACE_OFICINA="${IFACE_OFICINA:-enp0s8}"     # 2º adaptador de VirtualBox
export DEBIAN_FRONTEND=noninteractive
log() { echo -e "\n\033[1;32m=== $* ===\033[0m"; }
as_user() { sudo -u "$USUARIO" -H "$@"; }

# ---------------------------------------------------------------------
log "1/5 Driver ODBC 18 de Microsoft"
if ! dpkg -s msodbcsql18 >/dev/null 2>&1; then
  apt-get install -y curl gpg
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /usr/share/keyrings/microsoft-prod.gpg
  VER=$(. /etc/os-release; echo "$VERSION_ID"); COD=$(. /etc/os-release; echo "$VERSION_CODENAME")
  if ! curl -fsSL -o /dev/null "https://packages.microsoft.com/ubuntu/$VER/prod/dists/$COD/Release"; then
    echo "Microsoft no tiene repositorio para Ubuntu $VER: uso el de 24.04 (noble)"
    VER=24.04; COD=noble
  fi
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/$VER/prod $COD main" \
    > /etc/apt/sources.list.d/mssql-release.list
  apt-get update
  ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev
fi

# ---------------------------------------------------------------------
log "2/5 Extensiones PHP sqlsrv y pdo_sqlsrv"
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
apt-get install -y "php$PHPV-dev" php-pear make gcc
for ext in sqlsrv pdo_sqlsrv; do
  if ! php -m | grep -qx "$ext"; then
    pecl list | grep -q "^$ext " || printf '\n' | pecl install "$ext"
    printf '; priority=30\nextension=%s.so\n' "$ext" > "/etc/php/$PHPV/mods-available/$ext.ini"
  fi
done
phpenmod sqlsrv pdo_sqlsrv
systemctl restart "php$PHPV-fpm"
php -m | grep -E '^(sqlsrv|pdo_sqlsrv)$'

# ---------------------------------------------------------------------
log "3/5 Red de la oficina: IP fija $IP_OFICINA en $IFACE_OFICINA, DNS del dominio en DC01"
cat > /etc/netplan/60-red-oficina.yaml <<EOF
network:
  version: 2
  ethernets:
    $IFACE_OFICINA:
      dhcp4: false
      optional: true
      addresses: [$IP_OFICINA/24]
      nameservers:
        addresses: [$DNS_DC]
        search: [$DOMINIO_AD]
EOF
chmod 600 /etc/netplan/60-red-oficina.yaml
if ip link show "$IFACE_OFICINA" >/dev/null 2>&1; then netplan apply; echo "Red aplicada."
else echo "El 2º adaptador aún no existe: la IP se aplicará sola al arrancar con él."; fi

# ---------------------------------------------------------------------
log "4/5 ¿Llego al clúster?"
if ! (ip link show "$IFACE_OFICINA" >/dev/null 2>&1 && getent hosts "FHSQL.$DOMINIO_AD" >/dev/null \
      && timeout 5 bash -c "</dev/tcp/FHSQL.$DOMINIO_AD/1433" 2>/dev/null); then
  echo "Todavía no llego a FHSQL.$DOMINIO_AD:1433 (falta el adaptador puente o la red de la oficina)."
  echo "No toco el .env: la web sigue funcionando con SQLite."
  echo "Cuando la VM esté en la red, vuelve a ejecutar:  sudo bash bd-sqlsrv.sh"
  echo
  echo "IP de la oficina preparada: $IP_OFICINA  -> pásasela a P1 para el registro DNS 'laravel'."
  exit 0
fi
echo "Sí: FHSQL.$DOMINIO_AD responde en el puerto 1433."

# ---------------------------------------------------------------------
log "5/5 Laravel: conexión al clúster (.env) y migraciones"
cd "$APP"
# El certificado del clúster es interno: Laravel debe aceptarlo (cifrado activado)
sed -i "s#// 'encrypt' => env('DB_ENCRYPT', 'yes'),#'encrypt' => env('DB_ENCRYPT', 'yes'),#; s#// 'trust_server_certificate' => env('DB_TRUST_SERVER_CERTIFICATE', 'false'),#'trust_server_certificate' => env('DB_TRUST_SERVER_CERTIFICATE', 'false'),#" config/database.php

read -rsp "Contraseña del usuario SQL laravel_app (te la pasó P4; no se verá): " DBPASS; echo
[ -n "$DBPASS" ] || { echo "Contraseña vacía: cancelo."; exit 1; }

set_env() {  # set_env CLAVE VALOR
  if grep -q "^$1=" .env; then sed -i "s#^$1=.*#$1=$2#" .env
  else sed -i "s#^\# *$1=.*#$1=$2#" .env; grep -q "^$1=" .env || echo "$1=$2" >> .env; fi
}
cp .env ".env.antes-sqlsrv"
set_env DB_CONNECTION sqlsrv
set_env DB_HOST "FHSQL.$DOMINIO_AD"
set_env DB_PORT 1433
set_env DB_DATABASE LaravelApp
set_env DB_USERNAME laravel_app
set_env DB_ENCRYPT yes
set_env DB_TRUST_SERVER_CERTIFICATE true
# La contraseña entre comillas simples por si lleva caracteres especiales
grep -v '^DB_PASSWORD=' .env > .env.tmp && echo "DB_PASSWORD='$DBPASS'" >> .env.tmp && mv .env.tmp .env
unset DBPASS
chown "$USUARIO":www-data .env .env.antes-sqlsrv
chmod 640 .env .env.antes-sqlsrv
as_user php artisan config:clear >/dev/null
as_user php artisan migrate --force
as_user php artisan config:cache >/dev/null
echo
echo "Laravel conectado al clúster y tablas creadas."
echo "Vuelve a crear los usuarios de prueba si los necesitas:  sudo bash ~/demo.sh"
echo "Copia del .env anterior: $APP/.env.antes-sqlsrv (para volver a SQLite, cópiala encima del .env)."
