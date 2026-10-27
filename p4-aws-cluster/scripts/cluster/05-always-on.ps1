<#
.SYNOPSIS  Activa Always On y crea endpoints, base de datos, grupo de disponibilidad y listener.
.NOTES     Ejecutar en SQL1 con un usuario de G_SQL_Admins. Requiere el modulo SqlServer.
#>
. "$PSScriptRoot\00-config.ps1"

if (-not (Get-Module SqlServer -ListAvailable)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider NuGet -Force | Out-Null
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    Install-Module SqlServer -Scope AllUsers -Force -AllowClobber
}
function Sql([string]$Servidor, [string]$Consulta) {
    Invoke-Sqlcmd -ServerInstance $Servidor -TrustServerCertificate -Query $Consulta
}

foreach ($n in $Nodos.Keys) {
    Enable-SqlAlwaysOn -ServerInstance $n -Force          # reinicia el servicio de SQL
    Sql $n @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$CuentaSQL') CREATE LOGIN [$CuentaSQL] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.database_mirroring_endpoints)
    CREATE ENDPOINT [Hadr_endpoint] STATE = STARTED AS TCP (LISTENER_PORT = 5022)
    FOR DATABASE_MIRRORING (ROLE = ALL, AUTHENTICATION = WINDOWS NEGOTIATE, ENCRYPTION = REQUIRED ALGORITHM AES);
GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [$CuentaSQL];
GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM];
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM];
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM];
ALTER EVENT SESSION AlwaysOn_health ON SERVER WITH (STARTUP_STATE = ON);
"@
}

# Base de datos: recuperacion FULL + copia completa (requisito para entrar en un AG)
Sql SQL1 "IF DB_ID(N'$BaseDatos') IS NULL CREATE DATABASE [$BaseDatos]; ALTER DATABASE [$BaseDatos] SET RECOVERY FULL;"
Invoke-Sqlcmd -ServerInstance SQL1 -Database $BaseDatos -TrustServerCertificate -Query @"
IF OBJECT_ID('dbo.Prueba') IS NULL
  CREATE TABLE dbo.Prueba (Id INT IDENTITY PRIMARY KEY, Servidor SYSNAME DEFAULT @@SERVERNAME, Fecha DATETIME2 DEFAULT SYSDATETIME());
"@
Sql SQL1 "BACKUP DATABASE [$BaseDatos] TO DISK = N'NUL';"

$replica = { param($n) "N'$n' WITH (ENDPOINT_URL = N'TCP://$n.$($Dominio):5022', AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, FAILOVER_MODE = AUTOMATIC, SEEDING_MODE = AUTOMATIC, SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY))" }
Sql SQL1 @"
CREATE AVAILABILITY GROUP [$AG]
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY, DB_FAILOVER = ON)
FOR DATABASE [$BaseDatos]
REPLICA ON $(& $replica 'SQL1'), $(& $replica 'SQL2');
"@
Sql SQL2 "ALTER AVAILABILITY GROUP [$AG] JOIN; ALTER AVAILABILITY GROUP [$AG] GRANT CREATE ANY DATABASE;"
Sql SQL1 "ALTER AVAILABILITY GROUP [$AG] ADD LISTENER N'$Listener' (WITH IP ((N'$IpListener', N'255.255.255.0')), PORT = 1433);"

Start-Sleep 20
Sql SQL1 @"
SELECT ar.replica_server_name AS Replica, ars.role_desc AS Rol, ars.synchronization_health_desc AS Salud
FROM sys.availability_replicas ar JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
"@ | Format-Table -AutoSize
