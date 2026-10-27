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
