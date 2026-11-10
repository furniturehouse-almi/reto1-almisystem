<#
.SYNOPSIS  Business Central (BC 28) al cluster: restaura la copia de SRV-GESTION en la primaria, la pasa a
           recuperacion FULL, la anade a AG_Furniture y da acceso a la cuenta de equipo del servicio de BC.
.NOTES     Ejecutar en el nodo PRIMARIO. La copia .bak tiene que estar en C:\BCBackup del primario
           (recurso \\SQL1\BCBackup). El servicio de BC corre como NETWORK SERVICE en SRV-GESTION,
           asi que en SQL entra como la cuenta de equipo FURNITURE\SRV-GESTION$ (mismo SID en los dos nodos).
#>
param([string]$Bak = 'C:\BCBackup\BC28.bak')
$AG = 'AG_Furniture'; $BD = 'Demo Database BC (28-0)'; $Login = 'FURNITURE\SRV-GESTION$'
function Sql($srv, $query, $db = 'master') { Invoke-Sqlcmd -ServerInstance $srv -Database $db -TrustServerCertificate -QueryTimeout 1800 -Query $query }

$q = "SELECT ar.replica_server_name AS Replica, ars.role_desc AS Rol FROM sys.dm_hadr_availability_replica_states ars JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id"
$roles = Sql $env:COMPUTERNAME $q
$P = ($roles | Where-Object Rol -eq 'PRIMARY').Replica
$S = ($roles | Where-Object Rol -eq 'SECONDARY').Replica
Write-Host "Primaria: $P   Secundaria: $S" -ForegroundColor Cyan
if ($P -ne $env:COMPUTERNAME) { throw "Ejecuta este script en la primaria ($P)" }

# 1. Restaurar con los ficheros en las rutas por defecto de la instancia
$rutas = Sql $P "SELECT CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260)) AS D, CAST(SERVERPROPERTY('InstanceDefaultLogPath') AS nvarchar(260)) AS L"
$ficheros = Sql $P "RESTORE FILELISTONLY FROM DISK = N'$Bak'"
$move = ($ficheros | ForEach-Object {
    $dest = if ($_.Type -eq 'L') { "$($rutas.L)BC28_log.ldf" } else { "$($rutas.D)BC28.mdf" }
    "MOVE N'$($_.LogicalName)' TO N'$dest'" }) -join ', '
Write-Host "Restaurando $BD (puede tardar unos minutos)..." -ForegroundColor Cyan
Sql $P "IF DB_ID(N'$BD') IS NULL RESTORE DATABASE [$BD] FROM DISK = N'$Bak' WITH $move, RECOVERY, STATS = 10"

# 2. Recuperacion FULL + copia completa (requisito del AG)
Sql $P "ALTER DATABASE [$BD] SET RECOVERY FULL; BACKUP DATABASE [$BD] TO DISK = N'BC28-inicial.bak' WITH INIT, COMPRESSION"

# 3. Acceso del servicio de BC en los dos nodos (login de Windows: el SID lo da el dominio)
foreach ($srv in $P, $S) { Sql $srv "IF SUSER_ID(N'$Login') IS NULL CREATE LOGIN [$Login] FROM WINDOWS" }
Sql $P "IF USER_ID(N'$Login') IS NULL CREATE USER [$Login] FOR LOGIN [$Login]; ALTER ROLE db_owner ADD MEMBER [$Login];" $BD

# 4. Alta en el AG con siembra automatica
Sql $S "ALTER AVAILABILITY GROUP [$AG] GRANT CREATE ANY DATABASE"
Sql $P "IF NOT EXISTS (SELECT 1 FROM sys.availability_databases_cluster WHERE database_name = N'$BD') ALTER AVAILABILITY GROUP [$AG] ADD DATABASE [$BD]"
Write-Host "Esperando a la siembra automatica en $S (1 GB)..." -ForegroundColor Cyan
Start-Sleep 60

# 5. Comprobaciones
Sql $P "SELECT ar.replica_server_name AS Replica, DB_NAME(drs.database_id) AS BD, drs.synchronization_state_desc AS Estado, drs.synchronization_health_desc AS Salud FROM sys.dm_hadr_database_replica_states drs JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id WHERE DB_NAME(drs.database_id) = N'$BD'" | Format-Table -AutoSize
$P, $S | ForEach-Object { Sql $_ "SELECT @@SERVERNAME AS Servidor, name AS Login, type_desc AS Tipo FROM sys.server_principals WHERE name = N'$Login'" } | Format-Table -AutoSize
