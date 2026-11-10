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
