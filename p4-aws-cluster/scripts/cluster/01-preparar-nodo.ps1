<#
.SYNOPSIS  Deja un nodo listo antes de unirlo al dominio: IP fija, DNS, ping y nombre.
.EXAMPLE   .\01-preparar-nodo.ps1 -Nombre SQL1
#>
param([Parameter(Mandatory)][ValidateSet('SQL1','SQL2')][string]$Nombre)
. "$PSScriptRoot\00-config.ps1"

$nic = (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name
New-NetIPAddress -InterfaceAlias $nic -IPAddress $Nodos[$Nombre] -PrefixLength 24 -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $nic -ServerAddresses $DnsPrimario, $DnsSecundario
Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In          # responder al ping (bloqueado por defecto)
Rename-Computer -NewName $Nombre -Restart
