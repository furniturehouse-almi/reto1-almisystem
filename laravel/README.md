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

## Estado actual (intranet)

La aplicación está hecha y desplegada en un servidor de pruebas:

- **CRUD de muebles** (`/muebles`) con validaciones: nombre, descripción, precio (> 0), stock (≥ 0) y categoría.
- **Login con el AD** (LdapRecord 4): se entra con el `sAMAccountName` del dominio. Solo pasan los miembros de `Laravel-Admin` o `Laravel-Empleado` (`app/Ldap/Rules/SoloGruposLaravel.php`).
- **Roles** según el grupo (`app/Ldap/AttributeHandler.php` + Gate `admin`): el empleado ve el catálogo y el admin además crea, edita y borra.
- **Fuerza bruta:** máximo 5 intentos de login por minuto (`throttle:5,1`).
- **Pruebas** en `tests/Feature/AccesoTest.php`: invitado → login, empleado ve el catálogo, empleado no puede crear (403), admin sí, y precio negativo rechazado.

### Desplegar el servidor (Ubuntu Server 26.04)

```bash
sudo bash deploy/servidor.sh
```

Instala Nginx + PHP-FPM, UFW (solo 22, 80 y 443), certificado y HTTPS con redirección 80→443 y HSTS, y deja la app en `/var/www/furniturehouse` con `APP_DEBUG=false`. Al final ejecuta los tests y comprueba las redirecciones.

Mientras no esté conectado el AD, `sudo bash deploy/demo.sh` crea dos usuarios locales de prueba (admin y empleado) con contraseñas aleatorias que solo se muestran en la terminal. `sudo bash deploy/demo.sh off` los borra.

### Pendiente

- [ ] Datos reales del AD en el `.env` del servidor: cuenta de servicio de solo lectura y grupos `Laravel-Admin` / `Laravel-Empleado` (P1).
- [ ] Driver `sqlsrv` en el servidor y conexión a `FHSQL` (P4).
- [ ] La CI necesita la extensión `ldap` en `setup-php` (LdapRecord la exige para instalar dependencias).
