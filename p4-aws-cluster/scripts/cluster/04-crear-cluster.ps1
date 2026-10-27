<#
.SYNOPSIS  Valida y crea el cluster de Windows FHSQLCLU (sin discos compartidos).
.NOTES     P1 deja pre-creado el objeto FHSQLCLU en AD (deshabilitado) con control total para adrian.
#>
. "$PSScriptRoot\00-config.ps1"

Test-Cluster -Node $Nodos.Keys
New-Cluster -Name $Cluster -Node $Nodos.Keys -StaticAddress $IpCluster -NoStorage

# Latidos mas tolerantes para VMs en VirtualBox (evita expulsiones y cuarentenas por picos de carga)
$c = Get-Cluster $Cluster
$c.SameSubnetDelay     = 2000   # ms entre latidos (por defecto 1000)
$c.SameSubnetThreshold = 20     # latidos perdidos antes de dar el nodo por caido (por defecto 10)

# La cuenta del servicio de SQL necesita permiso sobre el cluster para Always On
Grant-ClusterAccess -Cluster $Cluster -User $CuentaSQL -Full
Get-ClusterNode -Cluster $Cluster | Format-Table Name, State
