<#
.SYNOPSIS  Base de datos de Laravel en el cluster: login laravel_app con el MISMO SID en los dos nodos,
           BD LaravelApp (recuperacion FULL) y alta en el grupo de disponibilidad AG_Furniture.
.NOTES     Ejecutar en el nodo PRIMARIO. Pide la contrasena de laravel_app por consola (no se guarda).
           Requisito previo: autenticacion mixta en SQL1 y SQL2 (LoginMode = 2).
#>
$AG = 'AG_Furniture'; $BD = 'LaravelApp'; $Login = 'laravel_app'
$q = "SELECT ar.replica_server_name AS Replica, ars.role_desc AS Rol FROM sys.dm_hadr_availability_replica_states ars JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id"
$roles = Invoke-Sqlcmd -ServerInstance $env:COMPUTERNAME -TrustServerCertificate -Query $q
$P = ($roles | Where-Object Rol -eq 'PRIMARY').Replica
$S = ($roles | Where-Object Rol -eq 'SECONDARY').Replica
Write-Host "Primaria: $P   Secundaria: $S" -ForegroundColor Cyan

$sec = Read-Host "Contrasena para $Login (min. 8, mayus, minus, numero)" -AsSecureString
$pw  = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)).Replace("'","''")

function Sql($srv, $query, $db = 'master') { Invoke-Sqlcmd -ServerInstance $srv -Database $db -TrustServerCertificate -QueryTimeout 120 -Query $query }

# 1. Login en la primaria y mismo SID en la secundaria (si no, el usuario de la BD queda huerfano tras un failover)
Sql $P "IF SUSER_ID('$Login') IS NULL CREATE LOGIN [$Login] WITH PASSWORD = N'$pw', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF"
$sid = (Sql $P "SELECT CONVERT(varchar(100), SUSER_SID('$Login'), 1) AS Sid").Sid
Sql $S "IF SUSER_ID('$Login') IS NULL CREATE LOGIN [$Login] WITH PASSWORD = N'$pw', SID = $sid, CHECK_POLICY = ON, CHECK_EXPIRATION = OFF"

# 2. Base de datos, usuario y copia completa inicial (requisito para entrar en el AG)
Sql $P "IF DB_ID('$BD') IS NULL CREATE DATABASE [$BD]; ALTER DATABASE [$BD] SET RECOVERY FULL;"
Sql $P "IF USER_ID('$Login') IS NULL CREATE USER [$Login] FOR LOGIN [$Login]; ALTER ROLE db_owner ADD MEMBER [$Login];" $BD
Sql $P "BACKUP DATABASE [$BD] TO DISK = N'$BD-inicial.bak' WITH INIT, COMPRESSION"

# 3. Alta en el AG con siembra automatica
Sql $S "ALTER AVAILABILITY GROUP [$AG] GRANT CREATE ANY DATABASE"
Sql $P "IF NOT EXISTS (SELECT 1 FROM sys.availability_databases_cluster WHERE database_name = '$BD') ALTER AVAILABILITY GROUP [$AG] ADD DATABASE [$BD]"
Write-Host "Esperando a la siembra automatica en $S..." -ForegroundColor Cyan
Start-Sleep 20

# 4. Comprobaciones
Sql $P "SELECT ar.replica_server_name AS Replica, DB_NAME(drs.database_id) AS BD, drs.synchronization_state_desc AS Estado, drs.synchronization_health_desc AS Salud FROM sys.dm_hadr_database_replica_states drs JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id WHERE DB_NAME(drs.database_id) = '$BD'" | Format-Table -AutoSize
$P, $S | ForEach-Object { Sql $_ "SELECT @@SERVERNAME AS Servidor, name AS Login, CONVERT(varchar(100), sid, 1) AS SID FROM sys.sql_logins WHERE name = '$Login'" } | Format-Table -AutoSize
Invoke-Sqlcmd -ServerInstance FHSQL -Database $BD -Username $Login -Password $pw.Replace("''","'") -TrustServerCertificate -Query "SELECT @@SERVERNAME AS Responde, DB_NAME() AS BD, SUSER_NAME() AS Usuario" | Format-Table -AutoSize
Remove-Variable pw, sec
