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
