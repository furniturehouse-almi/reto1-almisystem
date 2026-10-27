# Configuracion comun del cluster SQL Server local (P4)
# Se carga desde el resto de scripts con:  . "$PSScriptRoot\00-config.ps1"

$Dominio      = 'ad.furniturehouse2.com'
$NetBIOS      = 'FURNITURE'
$DnsPrimario  = '192.168.12.10'   # DC01 (P1)
$DnsSecundario= '192.168.12.30'   # DC03
$Gateway      = '192.168.12.1'
$OuSQL        = 'OU=SQL,OU=Servidores,DC=ad,DC=furniturehouse2,DC=com'

$Nodos        = @{ SQL1 = '192.168.12.31'; SQL2 = '192.168.12.32' }
$Cluster      = 'FHSQLCLU'
$IpCluster    = '192.168.12.33'
$AG           = 'AG_Furniture'
$Listener     = 'FHSQL'
$IpListener   = '192.168.12.34'
$BaseDatos    = 'FurnitureApps'
$Testigo      = '\\DC03\Witness'
$CuentaSQL    = "$NetBIOS\svc_sql"
$GrupoAdmins  = "$NetBIOS\G_SQL_Admins"
