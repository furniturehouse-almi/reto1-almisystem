# Web Laravel

| Bloque | Responsable |
|---|---|
| Aplicación (CRUD de catálogo / pedidos) | P3 |
| Login con usuarios del AD (LDAP) y roles | P2 |
| Servidor Ubuntu + Nginx + PHP-FPM, HTTPS, DNS `laravel.ad.furniturehouse2.com` | P1 |
| Base de datos en el clúster SQL Server (listener `FHSQL`) | P4 |

## Arrancar el proyecto (P3, una sola vez)
```bash
composer create-project laravel/laravel .
```
Sube el proyecto **sin** `vendor/` ni `.env` (ya están en `.gitignore`).

## Conexión a la base de datos (producción)
En el `.env` del servidor (nunca en el repo):
```
DB_CONNECTION=sqlsrv
DB_HOST=FHSQL.ad.furniturehouse2.com
DB_PORT=1433
DB_DATABASE=LaravelApp
DB_USERNAME=laravel_app
DB_PASSWORD=          # te la pasa P4 en persona
DB_TRUST_SERVER_CERTIFICATE=true
```
En desarrollo cada uno puede usar SQLite (`DB_CONNECTION=sqlite`): las migraciones valen para los dos.

> Tras un failover del clúster hay unos segundos sin servicio: la app debe reintentar la conexión.

## Estado de la base de datos (P4, 10 nov) ✅
- BD `LaravelApp` creada en el clúster y añadida a `AG_Furniture` (SYNCHRONIZED / HEALTHY en SQL1 y SQL2).
- Login SQL `laravel_app` con **el mismo SID en los dos nodos** (no se queda huérfano tras un failover); es `db_owner` solo de `LaravelApp`, así que puede lanzar `php artisan migrate`.
- Autenticación mixta activada en SQL1 y SQL2.
- Probado: `laravel_app` entra por el listener `FHSQL` (captura 28).

## Lo que necesita el servidor de P1 (Ubuntu)
```bash
# Driver ODBC de Microsoft + extensiones PHP de SQL Server
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg
curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt update && sudo ACCEPT_EULA=Y apt install -y msodbcsql18 unixodbc-dev php-dev php-pear
sudo pecl install sqlsrv pdo_sqlsrv
echo "extension=pdo_sqlsrv.so" | sudo tee /etc/php/8.3/mods-available/pdo_sqlsrv.ini
echo "extension=sqlsrv.so"     | sudo tee /etc/php/8.3/mods-available/sqlsrv.ini
sudo phpenmod sqlsrv pdo_sqlsrv && sudo systemctl restart php8.3-fpm
```
El servidor tiene que usar como DNS a DC01 (`192.168.12.10`) para resolver `FHSQL.ad.furniturehouse2.com`, y llegar al puerto 1433 de `192.168.12.34`.
