<#
.SYNOPSIS  Une el nodo al dominio de P1 en la OU Servidores\SQL.
.NOTES     Ejecutar como Administrador local. Tras el reinicio, ejecutar 02b para los administradores.
#>
. "$PSScriptRoot\00-config.ps1"
$cred = Get-Credential "adrian@$Dominio" -Message 'Usuario del dominio con permiso para unir equipos'
Add-Computer -DomainName $Dominio -OUPath $OuSQL -Credential $cred -Restart
