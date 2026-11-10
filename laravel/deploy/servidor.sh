#!/bin/bash
# =====================================================================
#  Reto 1 - The Furniture in Your House
#  P5: Web interna con Laravel (servidor + aplicación + login con el AD)
#  Uso:  sudo bash servidor.sh
#  Se puede ejecutar varias veces: lo que ya está hecho no se repite.
# =====================================================================
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Ejecuta así:  sudo bash servidor.sh"; exit 1; }

USUARIO="${SUDO_USER:-paul}"
APP=/var/www/furniturehouse
DOMINIO=laravel.ad.furniturehouse2.com
export DEBIAN_FRONTEND=noninteractive

log() { echo -e "\n\033[1;32m=== $* ===\033[0m"; }
as_user() { sudo -u "$USUARIO" -H "$@"; }

# ---------------------------------------------------------------------
log "1/8 Instalando paquetes (Nginx, PHP, Composer...)"
apt-get update
apt-get install -y nginx php-fpm php-cli php-mbstring php-xml php-curl php-intl \
  php-zip php-ldap php-sqlite3 php-mysql unzip composer openssl ufw git python3
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# ---------------------------------------------------------------------
log "2/8 Cortafuegos: solo SSH, 80 y 443"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80,443/tcp
ufw --force enable

# ---------------------------------------------------------------------
log "3/8 Creando el proyecto Laravel en $APP"
mkdir -p "$APP"
chown "$USUARIO":www-data "$APP"
if [ ! -f "$APP/artisan" ]; then
  as_user composer create-project laravel/laravel "$APP" --no-interaction
fi
cd "$APP"

if ! grep -q ldaprecord-laravel composer.json; then
  as_user composer require directorytree/ldaprecord-laravel --no-interaction
fi
[ -f config/ldap.php ] || as_user php artisan vendor:publish --provider="LdapRecord\Laravel\LdapServiceProvider" --no-interaction
ls database/migrations/*add_ldap_columns_to_users_table.php >/dev/null 2>&1 || \
  as_user php artisan vendor:publish --provider="LdapRecord\Laravel\LdapAuthServiceProvider" --no-interaction

[ -f app/Models/Mueble.php ] || as_user php artisan make:model Mueble -mrc --requests
ls database/migrations/*_add_role_to_users_table.php >/dev/null 2>&1 || \
  as_user php artisan make:migration add_role_to_users_table --table=users
touch database/database.sqlite

mkdir -p resources/views/layouts resources/views/muebles resources/views/auth app/Ldap/Rules

# ---------------------------------------------------------------------
log "4/8 Escribiendo la aplicación (CRUD de muebles)"

cat > "$(ls database/migrations/*_create_muebles_table.php)" <<'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('muebles', function (Blueprint $table) {
            $table->id();
            $table->string('nombre');
            $table->text('descripcion')->nullable();
            $table->decimal('precio', 8, 2);
            $table->unsignedInteger('stock')->default(0);
            $table->string('categoria');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('muebles');
    }
};
EOF

cat > "$(ls database/migrations/*_add_role_to_users_table.php)" <<'EOF'
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('empleado');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('role');
        });
    }
};
EOF

cat > app/Models/Mueble.php <<'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Mueble extends Model
{
    protected $fillable = ['nombre', 'descripcion', 'precio', 'stock', 'categoria'];
}
EOF

cat > app/Http/Controllers/MuebleController.php <<'EOF'
<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreMuebleRequest;
use App\Http\Requests\UpdateMuebleRequest;
use App\Models\Mueble;

class MuebleController extends Controller
{
    public function index()
    {
        $muebles = Mueble::latest()->paginate(10);
        return view('muebles.index', compact('muebles'));
    }

    public function create()
    {
        return view('muebles.create');
    }

    public function store(StoreMuebleRequest $request)
    {
        Mueble::create($request->validated());
        return redirect()->route('muebles.index')->with('ok', 'Mueble creado.');
    }

    public function edit(Mueble $mueble)
    {
        return view('muebles.edit', compact('mueble'));
    }

    public function update(UpdateMuebleRequest $request, Mueble $mueble)
    {
        $mueble->update($request->validated());
        return redirect()->route('muebles.index')->with('ok', 'Mueble actualizado.');
    }

    public function destroy(Mueble $mueble)
    {
        $mueble->delete();
        return redirect()->route('muebles.index')->with('ok', 'Mueble eliminado.');
    }
}
EOF

for R in StoreMuebleRequest UpdateMuebleRequest; do
cat > app/Http/Requests/$R.php <<EOF
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class $R extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre'      => 'required|string|max:255',
            'descripcion' => 'nullable|string',
            'precio'      => 'required|numeric|gt:0',
            'stock'       => 'required|integer|min:0',
            'categoria'   => 'required|string|max:100',
        ];
    }
}
EOF
done

# ---------------------------------------------------------------------
log "5/8 Login con el Active Directory y roles"

python3 - <<'PY'
import re, sys
p = 'config/auth.php'
s = open(p).read()
if "'driver' => 'ldap'" in s:
    print("config/auth.php ya estaba configurado")
    sys.exit(0)
pat = r"'users'\s*=>\s*\[\s*'driver'\s*=>\s*'eloquent',\s*'model'\s*=>\s*[^\n]*\n\s*\],"
new = """'users' => [
            'driver' => 'ldap',
            'model' => LdapRecord\\Models\\ActiveDirectory\\User::class,
            'rules' => [App\\Ldap\\Rules\\SoloGruposLaravel::class],
            'scopes' => [],
            'database' => [
                'model' => App\\Models\\User::class,
                'sync_passwords' => false,
                'sync_attributes' => [App\\Ldap\\AttributeHandler::class],
            ],
        ],"""
s2, n = re.subn(pat, lambda m: new, s, count=1)
if n != 1:
    sys.exit("ERROR: no encontré el bloque 'users' en config/auth.php")
open(p, 'w').write(s2)
print("config/auth.php actualizado")
PY

cat > app/Ldap/Rules/SoloGruposLaravel.php <<'EOF'
<?php

namespace App\Ldap\Rules;

use Illuminate\Database\Eloquent\Model as Eloquent;
use LdapRecord\Laravel\Auth\Rule;
use LdapRecord\Models\Model as LdapRecord;

// Solo entran los usuarios que pertenecen a Laravel-Admin o Laravel-Empleado.
class SoloGruposLaravel implements Rule
{
    public function passes(LdapRecord $user, ?Eloquent $model = null): bool
    {
        foreach ((array) $user->getAttribute('memberof') as $dn) {
            $dn = strtolower($dn);
            if (str_starts_with($dn, 'cn=laravel-admin,') || str_starts_with($dn, 'cn=laravel-empleado,')) {
                return true;
            }
        }

        return false;
    }
}
EOF

cat > app/Ldap/AttributeHandler.php <<'EOF'
<?php

namespace App\Ldap;

use App\Models\User as EloquentUser;
use LdapRecord\Models\Model as LdapModel;

// Copia datos del AD a la base de datos local y decide el rol según el grupo.
class AttributeHandler
{
    public function handle(LdapModel $ldap, EloquentUser $database): void
    {
        $sam = $ldap->getFirstAttribute('samaccountname');

        $database->name = $ldap->getFirstAttribute('cn') ?? $sam;
        $database->email = $ldap->getFirstAttribute('mail') ?? $sam.'@ad.furniturehouse2.com';

        $esAdmin = collect((array) $ldap->getAttribute('memberof'))
            ->contains(fn ($dn) => str_starts_with(strtolower($dn), 'cn=laravel-admin,'));

        $database->role = $esAdmin ? 'admin' : 'empleado';
    }
}
EOF

cat > app/Models/User.php <<'EOF'
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use LdapRecord\Laravel\Auth\AuthenticatesWithLdap;
use LdapRecord\Laravel\Auth\LdapAuthenticatable;

class User extends Authenticatable implements LdapAuthenticatable
{
    use AuthenticatesWithLdap, HasFactory, Notifiable;

    protected $fillable = ['name', 'email', 'password', 'role'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return ['password' => 'hashed'];
    }
}
EOF

cat > app/Providers/AppServiceProvider.php <<'EOF'
<?php

namespace App\Providers;

use Illuminate\Pagination\Paginator;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void {}

    public function boot(): void
    {
        Paginator::useBootstrapFive();
        Gate::define('admin', fn ($user) => $user->role === 'admin');
    }
}
EOF

cat > app/Http/Controllers/LoginController.php <<'EOF'
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class LoginController extends Controller
{
    public function show()
    {
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        if (Auth::attempt(['samaccountname' => $data['username'], 'password' => $data['password']])) {
            $request->session()->regenerate();
            return redirect()->intended(route('muebles.index'));
        }

        return back()
            ->withErrors(['username' => 'Usuario o contraseña incorrectos, o sin permiso de acceso.'])
            ->onlyInput('username');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
EOF

cat > routes/web.php <<'EOF'
<?php

use App\Http\Controllers\LoginController;
use App\Http\Controllers\MuebleController;
use Illuminate\Support\Facades\Route;

Route::redirect('/', '/muebles');

Route::middleware('guest')->group(function () {
    Route::get('/login', [LoginController::class, 'show'])->name('login');
    Route::post('/login', [LoginController::class, 'login'])->middleware('throttle:5,1');
});

Route::middleware('auth')->group(function () {
    Route::post('/logout', [LoginController::class, 'logout'])->name('logout');

    // Empleados y admins pueden ver el catálogo
    Route::get('/muebles', [MuebleController::class, 'index'])->name('muebles.index');

    // Solo los admins pueden crear, editar y borrar
    Route::middleware('can:admin')->group(function () {
        Route::resource('muebles', MuebleController::class)->except(['index', 'show']);
    });
});
EOF

# ---------------------------------------------------------------------
log "6/8 Vistas"

cat > resources/views/layouts/app.blade.php <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>The Furniture in Your House</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<nav class="navbar navbar-dark bg-dark mb-4">
    <div class="container">
        <a class="navbar-brand" href="{{ route('muebles.index') }}">The Furniture in Your House</a>
        @auth
            <div class="d-flex align-items-center text-white">
                <span class="me-3">{{ auth()->user()->name }} ({{ auth()->user()->role }})</span>
                <form action="{{ route('logout') }}" method="POST">
                    @csrf
                    <button class="btn btn-sm btn-outline-light">Salir</button>
                </form>
            </div>
        @endauth
    </div>
</nav>
<main class="container">
    @if (session('ok'))
        <div class="alert alert-success">{{ session('ok') }}</div>
    @endif
    @yield('content')
</main>
</body>
</html>
EOF

cat > resources/views/auth/login.blade.php <<'EOF'
@extends('layouts.app')

@section('content')
<div class="row justify-content-center">
    <div class="col-md-5">
        <div class="card shadow-sm">
            <div class="card-body">
                <h1 class="h4 mb-3">Acceso a la intranet</h1>
                <p class="text-muted">Usa tu usuario y contraseña del dominio.</p>
                <form action="{{ route('login') }}" method="POST">
                    @csrf
                    <div class="mb-3">
                        <label class="form-label">Usuario</label>
                        <input type="text" name="username" class="form-control @error('username') is-invalid @enderror"
                               value="{{ old('username') }}" autofocus autocomplete="username">
                        @error('username') <div class="invalid-feedback">{{ $message }}</div> @enderror
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Contraseña</label>
                        <input type="password" name="password" class="form-control" autocomplete="current-password">
                    </div>
                    <button class="btn btn-primary w-100">Entrar</button>
                </form>
            </div>
        </div>
    </div>
</div>
@endsection
EOF

cat > resources/views/muebles/index.blade.php <<'EOF'
@extends('layouts.app')

@section('content')
<div class="d-flex justify-content-between mb-3">
    <h1 class="h3">Catálogo de muebles</h1>
    @can('admin')
        <a href="{{ route('muebles.create') }}" class="btn btn-primary">Nuevo mueble</a>
    @endcan
</div>

<table class="table table-striped bg-white">
    <thead>
        <tr><th>Nombre</th><th>Categoría</th><th>Precio</th><th>Stock</th><th></th></tr>
    </thead>
    <tbody>
    @forelse ($muebles as $m)
        <tr>
            <td>{{ $m->nombre }}</td>
            <td>{{ $m->categoria }}</td>
            <td>{{ number_format($m->precio, 2) }} €</td>
            <td>{{ $m->stock }}</td>
            <td class="text-end">
                @can('admin')
                    <a href="{{ route('muebles.edit', $m) }}" class="btn btn-sm btn-outline-secondary">Editar</a>
                    <form action="{{ route('muebles.destroy', $m) }}" method="POST" class="d-inline"
                          onsubmit="return confirm('¿Eliminar este mueble?')">
                        @csrf @method('DELETE')
                        <button class="btn btn-sm btn-outline-danger">Borrar</button>
                    </form>
                @endcan
            </td>
        </tr>
    @empty
        <tr><td colspan="5" class="text-center">No hay muebles todavía.</td></tr>
    @endforelse
    </tbody>
</table>

{{ $muebles->links() }}
@endsection
EOF

cat > resources/views/muebles/_form.blade.php <<'EOF'
@if ($errors->any())
    <div class="alert alert-danger">
        <ul class="mb-0">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div class="mb-3">
    <label class="form-label">Nombre</label>
    <input type="text" name="nombre" class="form-control" value="{{ old('nombre', $mueble->nombre ?? '') }}">
</div>
<div class="mb-3">
    <label class="form-label">Descripción</label>
    <textarea name="descripcion" class="form-control" rows="3">{{ old('descripcion', $mueble->descripcion ?? '') }}</textarea>
</div>
<div class="row">
    <div class="col-md-4 mb-3">
        <label class="form-label">Precio (€)</label>
        <input type="number" step="0.01" name="precio" class="form-control" value="{{ old('precio', $mueble->precio ?? '') }}">
    </div>
    <div class="col-md-4 mb-3">
        <label class="form-label">Stock</label>
        <input type="number" name="stock" class="form-control" value="{{ old('stock', $mueble->stock ?? 0) }}">
    </div>
    <div class="col-md-4 mb-3">
        <label class="form-label">Categoría</label>
        <input type="text" name="categoria" class="form-control" value="{{ old('categoria', $mueble->categoria ?? '') }}">
    </div>
</div>
<a href="{{ route('muebles.index') }}" class="btn btn-secondary">Cancelar</a>
<button class="btn btn-primary">Guardar</button>
EOF

cat > resources/views/muebles/create.blade.php <<'EOF'
@extends('layouts.app')

@section('content')
<h1 class="h3">Nuevo mueble</h1>
<form action="{{ route('muebles.store') }}" method="POST">
    @csrf
    @include('muebles._form')
</form>
@endsection
EOF

cat > resources/views/muebles/edit.blade.php <<'EOF'
@extends('layouts.app')

@section('content')
<h1 class="h3">Editar mueble</h1>
<form action="{{ route('muebles.update', $mueble) }}" method="POST">
    @csrf @method('PUT')
    @include('muebles._form')
</form>
@endsection
EOF

rm -f tests/Feature/ExampleTest.php
cat > tests/Feature/AccesoTest.php <<'EOF'
<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AccesoTest extends TestCase
{
    use RefreshDatabase;

    private function usuario(string $rol): User
    {
        return User::create([
            'name' => "Usuario $rol",
            'email' => "$rol@ejemplo.com",
            'password' => 'no-se-usa',
            'role' => $rol,
        ]);
    }

    public function test_invitado_es_redirigido_al_login(): void
    {
        $this->get('/muebles')->assertRedirect('/login');
    }

    public function test_empleado_puede_ver_el_catalogo(): void
    {
        $this->actingAs($this->usuario('empleado'))->get('/muebles')->assertOk();
    }

    public function test_empleado_no_puede_crear_muebles(): void
    {
        $this->actingAs($this->usuario('empleado'))->get('/muebles/create')->assertForbidden();
    }

    public function test_admin_puede_crear_muebles(): void
    {
        $this->actingAs($this->usuario('admin'))->get('/muebles/create')->assertOk();
    }

    public function test_validacion_rechaza_precio_negativo(): void
    {
        $this->actingAs($this->usuario('admin'))
            ->post('/muebles', [
                'nombre' => 'Silla', 'precio' => -5, 'stock' => 1, 'categoria' => 'Salón',
            ])
            ->assertSessionHasErrors('precio');
    }
}
EOF

# ---------------------------------------------------------------------
log "7/8 Configuración (.env), base de datos, permisos y pruebas"

sed -i "s/^APP_ENV=.*/APP_ENV=production/; s/^APP_DEBUG=.*/APP_DEBUG=false/; s#^APP_URL=.*#APP_URL=https://$DOMINIO#" .env
grep -q '^LDAP_HOST' .env || cat >> .env <<'EOF'

# --- Active Directory (VALORES DE EJEMPLO: cambiar por los que dé P1) ---
LDAP_CONNECTION=default
LDAP_HOST=dc01.ad.furniturehouse2.com
LDAP_PORT=389
LDAP_BASE_DN="DC=ad,DC=furniturehouse2,DC=com"
LDAP_USERNAME="CN=svc_laravel,CN=Users,DC=ad,DC=furniturehouse2,DC=com"
LDAP_PASSWORD=CAMBIAR
LDAP_TLS=false
LDAP_STARTTLS=false
LDAP_LOGGING=true
EOF

chown -R "$USUARIO":www-data "$APP"
chmod -R ug+rwX storage bootstrap/cache database
chmod 640 .env

as_user php artisan migrate --force
as_user php artisan test || echo "AVISO: alguna prueba ha fallado, revisa la salida de arriba"
as_user php artisan config:cache
as_user php artisan route:cache
as_user php artisan view:cache

# ---------------------------------------------------------------------
log "8/8 Nginx con HTTPS"

mkdir -p /etc/ssl/furniturehouse
if [ ! -f /etc/ssl/furniturehouse/laravel.crt ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/ssl/furniturehouse/laravel.key \
    -out /etc/ssl/furniturehouse/laravel.crt \
    -subj "/CN=$DOMINIO" -addext "subjectAltName=DNS:$DOMINIO"
  chmod 600 /etc/ssl/furniturehouse/laravel.key
fi

cat > /etc/nginx/sites-available/furniturehouse <<'EOF'
server {
    listen 80;
    server_name laravel.ad.furniturehouse2.com _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name laravel.ad.furniturehouse2.com _;

    ssl_certificate     /etc/ssl/furniturehouse/laravel.crt;
    ssl_certificate_key /etc/ssl/furniturehouse/laravel.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    server_tokens off;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    root /var/www/furniturehouse/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php__PHPV__-fpm.sock;
    }

    location ~ /\.(?!well-known) {
        deny all;
    }
}
EOF
sed -i "s/__PHPV__/$PHPV/" /etc/nginx/sites-available/furniturehouse
ln -sf /etc/nginx/sites-available/furniturehouse /etc/nginx/sites-enabled/furniturehouse
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart "php$PHPV-fpm" nginx

# ---------------------------------------------------------------------
log "Comprobaciones finales"
echo "HTTP  (debe redirigir a https):"; curl -sI http://localhost | head -1
echo "HTTPS (debe redirigir a /login):"; curl -skI https://localhost | head -1
ufw status
echo
echo "Listo. IP de este servidor:"; hostname -I
echo "Pendiente: poner en $APP/.env los datos reales del AD (los da P1)"
echo "y después ejecutar:  cd $APP && php artisan config:cache"
