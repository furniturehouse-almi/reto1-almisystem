<#
.SYNOPSIS  Instalacion desatendida de SQL Server 2022 (motor) + requisitos del cluster en el nodo actual.
.NOTES     Montar antes la ISO de SQL Server 2022 en la VM. Pide la contrasena de svc_sql (no queda escrita).
#>
. "$PSScriptRoot\00-config.ps1"

Install-WindowsFeature Failover-Clustering -IncludeManagementTools
New-NetFirewallRule -DisplayName 'SQL Server 1433'      -Direction Inbound -Protocol TCP -LocalPort 1433 -RemoteAddress 192.168.12.0/24 -Action Allow
New-NetFirewallRule -DisplayName 'SQL AG endpoint 5022' -Direction Inbound -Protocol TCP -LocalPort 5022 -RemoteAddress 192.168.12.0/24 -Action Allow

# La ISO de SQL es la unica unidad con carpeta x64 (la de Windows no la tiene)
$cd  = (Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path "$($_.Root)x64" } | Select-Object -First 1).Root
if (-not $cd) { throw 'No encuentro la ISO de SQL Server montada' }
$svc = Get-Credential $CuentaSQL -Message 'Contrasena de la cuenta de servicio de SQL'
$pw  = $svc.GetNetworkCredential().Password

& "$($cd)setup.exe" /Q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=MSSQLSERVER `
  /SQLSVCACCOUNT="$CuentaSQL" /SQLSVCPASSWORD="$pw" /AGTSVCACCOUNT="$CuentaSQL" /AGTSVCPASSWORD="$pw" `
  /SQLSYSADMINACCOUNTS="$GrupoAdmins" /SQLMAXMEMORY=2048 /TCPENABLED=1 /UPDATEENABLED=False /IACCEPTSQLSERVERLICENSETERMS

Set-Service SQLSERVERAGENT -StartupType Automatic
Start-Service SQLSERVERAGENT
Get-Service MSSQLSERVER, SQLSERVERAGENT | Format-Table Name, Status, StartType
