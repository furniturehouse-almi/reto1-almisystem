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
