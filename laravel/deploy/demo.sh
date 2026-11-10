#!/bin/bash
# Modo demostración: dos usuarios locales (admin y empleado) mientras no esté el AD.
# Activar:     sudo bash demo.sh
# Desactivar:  sudo bash demo.sh off
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Ejecuta así:  sudo bash demo.sh"; exit 1; }

APP=/var/www/furniturehouse
USUARIO="${SUDO_USER:-paul}"
cd "$APP"
as_user() { sudo -u "$USUARIO" -H "$@"; }

if [ "${1:-}" = "off" ]; then
  rm -f storage/app/demo_login
  as_user php artisan tinker --execute="App\Models\User::whereIn('email',['demo.admin','demo.empleado'])->delete();"
  echo "Modo demostración DESACTIVADO y usuarios de prueba borrados."
  exit 0
fi

# 1. El login acepta usuarios locales solo si existe el archivo storage/app/demo_login
python3 - <<'PY'
p = 'app/Http/Controllers/LoginController.php'
s = open(p).read()
if 'demo_login' not in s:
    old = "        if (Auth::attempt("
    new = """        // Modo demostración: usuarios locales mientras no esté conectado el AD.
        if (file_exists(storage_path('app/demo_login'))) {
            $local = \\App\\Models\\User::where('email', $data['username'])->whereNull('guid')->first();
            if ($local) {
                if (\\Illuminate\\Support\\Facades\\Hash::check($data['password'], $local->password)) {
                    Auth::login($local);
                    $request->session()->regenerate();
                    return redirect()->intended(route('muebles.index'));
                }

                return back()
                    ->withErrors(['username' => 'Usuario o contraseña incorrectos, o sin permiso de acceso.'])
                    ->onlyInput('username');
            }
        }

        if (Auth::attempt("
    if old not in s:
        raise SystemExit("ERROR: no encontré el punto de LoginController.php donde añadir el modo demo")
    s = s.replace(old, new, 1)
    open(p, 'w').write(s)
    print("LoginController actualizado")
PY

touch storage/app/demo_login
chown "$USUARIO":www-data storage/app/demo_login

# 2. Usuarios de prueba con contraseñas aleatorias
PASS_ADMIN=$(openssl rand -base64 9 | tr -dc 'A-Za-z0-9' | head -c 10)
PASS_EMP=$(openssl rand -base64 9 | tr -dc 'A-Za-z0-9' | head -c 10)

as_user php artisan tinker --execute="
foreach ([['demo.admin','Admin de prueba','admin','$PASS_ADMIN'],['demo.empleado','Empleado de prueba','empleado','$PASS_EMP']] as [\$u,\$n,\$r,\$p]) {
  App\Models\User::updateOrCreate(['email'=>\$u], ['name'=>\$n,'role'=>\$r,'password'=>\$p]);
}"

# 3. Unos muebles de ejemplo si el catálogo está vacío
as_user php artisan tinker --execute="
if (App\Models\Mueble::count() === 0) {
  App\Models\Mueble::create(['nombre'=>'Sofá Oslo','descripcion'=>'Sofá de tres plazas','precio'=>649.00,'stock'=>4,'categoria'=>'Salón']);
  App\Models\Mueble::create(['nombre'=>'Mesa Nogal','descripcion'=>'Mesa de comedor extensible','precio'=>389.90,'stock'=>7,'categoria'=>'Comedor']);
  App\Models\Mueble::create(['nombre'=>'Silla Nórdica','descripcion'=>'Silla de madera y tela','precio'=>59.95,'stock'=>24,'categoria'=>'Comedor']);
}"

as_user php artisan route:cache >/dev/null
as_user php artisan view:cache >/dev/null

echo
echo "================ MODO DEMOSTRACIÓN ACTIVO ================"
echo " Web: https://localhost:8443"
echo
echo " ADMIN     usuario: demo.admin       contraseña: $PASS_ADMIN"
echo " EMPLEADO  usuario: demo.empleado    contraseña: $PASS_EMP"
echo
echo " Para quitarlo cuando esté el AD:  sudo bash demo.sh off"
echo "==========================================================="
