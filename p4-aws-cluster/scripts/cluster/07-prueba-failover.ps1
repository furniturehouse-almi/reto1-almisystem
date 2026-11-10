<#
.SYNOPSIS  Prueba de failover para grabar: escribe una fila por segundo a traves del listener FHSQL
           y muestra que servidor responde. Durante la prueba se apaga la primaria y se ve el relevo.
.NOTES     Usa System.Data.SqlClient: funciona en SQL1 y SQL2 sin el modulo SqlServer.
           Ctrl+C para parar. Al final cuenta las escrituras.
#>
$Listener  = 'FHSQL'
$BaseDatos = 'FurnitureApps'
$cadena = "Server=tcp:$Listener,1433;Database=$BaseDatos;Integrated Security=True;MultiSubnetFailover=True;Connect Timeout=5"

function Invoke-Consulta([string]$sql) {
    $cn = New-Object System.Data.SqlClient.SqlConnection $cadena
    try {
        $cn.Open()
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 5
        $rd = $cmd.ExecuteReader(); $null = $rd.Read()
        return @{ Servidor = $rd[0]; Filas = $rd[1] }
    } finally { $cn.Dispose() }
}

# Crea la tabla de prueba si no existe
$null = Invoke-Consulta "IF OBJECT_ID('dbo.Prueba') IS NULL CREATE TABLE dbo.Prueba (Id INT IDENTITY PRIMARY KEY, Hora DATETIME2 DEFAULT SYSDATETIME(), Servidor SYSNAME DEFAULT @@SERVERNAME); SELECT @@SERVERNAME, COUNT(*) FROM dbo.Prueba;"

$ok = 0; $fallos = 0
try {
    while ($true) {
        try {
            $r = Invoke-Consulta "INSERT INTO dbo.Prueba DEFAULT VALUES; SELECT @@SERVERNAME, COUNT(*) FROM dbo.Prueba;"
            $ok++
            Write-Host ("{0:HH:mm:ss}  OK  -> {1}  (filas: {2})" -f (Get-Date), $r.Servidor, $r.Filas) -ForegroundColor Green
        } catch {
            $fallos++
            [System.Data.SqlClient.SqlConnection]::ClearAllPools()
            Write-Host ("{0:HH:mm:ss}  SIN SERVICIO ({1})" -f (Get-Date), $_.Exception.Message.Split([Environment]::NewLine)[0]) -ForegroundColor Red
        }
        Start-Sleep 1
    }
} finally {
    Write-Host "Escrituras correctas: $ok  |  Intentos sin servicio: $fallos" -ForegroundColor Cyan
}
