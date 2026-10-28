# P3 - WordPress / tienda online (furniturehouseX)

Scripts, configuraciones exportadas y documentación de la parte web del reto.

> Sin contraseñas ni claves: usa ficheros `*.example` con los valores vacíos.

## Cómo está montada

| Elemento | Valor |
|---|---|
| Dominio | `furniturehousex.com` |
| Servidor | Ubuntu Server (VM de VirtualBox, red interna `192.168.12.0/24`) |
| Web | Apache + PHP + MySQL/MariaDB |
| Carpeta de la web | `/var/www/furniturehousex.com` |
| Base de datos | `wordpress` |
| CMS | WordPress con WooCommerce |
| Tema | Tema por defecto de WordPress (Twenty Twenty-*) |
| Plugins | WooCommerce, Akismet |

El diseño de la tienda (páginas, productos, cabecera, mini carrito...) está
hecho desde el editor de WordPress, así que se guarda en la base de datos y
no en ficheros. Por eso en este repo no hay tema ni plugins propios.

## Qué NO se sube (ver `.gitignore`)

- Núcleo de WordPress (`wp-admin/`, `wp-includes/`, `*.php` de la raíz).
- `wp-content/uploads/`, caché y copias.
- `wp-config.php` (lleva la contraseña de la base de datos).
- Volcados de la base de datos (`*.sql`), porque pueden llevar datos de clientes.

## Ficheros de esta carpeta

- `install-wordpress.sh`: instala Apache, PHP, MariaDB y WordPress en un Ubuntu limpio.
- `wp-config.php.example`: plantilla de configuración con los valores vacíos.

## Instalación rápida

```bash
sudo DB_PASS='poner-una-contraseña' bash install-wordpress.sh
```

Después abrir `http://furniturehousex.com`, terminar el asistente de WordPress
e instalar WooCommerce desde *Plugins > Añadir nuevo*.

## Copia de seguridad de la base de datos (solo en local, nunca en Git)

```bash
sudo mysqldump --result-file=furniturehousex.sql wordpress
```
