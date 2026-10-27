<#
.SYNOPSIS  Prueba de failover para grabar: escribe una fila por segundo a traves del listener y muestra
           que servidor responde. Durante la prueba se apaga la primaria y se ve el relevo.
.NOTES     Ctrl+C para parar. Al final cuenta las filas escritas.
#>
. "$PSScriptRoot\00-config.ps1"
$ok = 0; $fallos = 0
while ($true) {
    try {
        $r = Invoke-Sqlcmd -ServerInstance $Listener -Database $BaseDatos -TrustServerCertificate -QueryTimeout 5 -ConnectionTimeout 5 `
             -Query "INSERT INTO dbo.Prueba DEFAULT VALUES; SELECT @@SERVERNAME AS Servidor, COUNT(*) AS Filas FROM dbo.Prueba;"
        $ok++
        Write-Output ("{0:HH:mm:ss}  OK  -> {1}  (filas: {2})" -f (Get-Date), $r.Servidor, $r.Filas)
    } catch {
        $fallos++
        [System.Data.SqlClient.SqlConnection]::ClearAllPools()
        Write-Output ("{0:HH:mm:ss}  SIN SERVICIO ({1})" -f (Get-Date), $_.Exception.Message.Split([Environment]::NewLine)[0])
    }
    Start-Sleep 1
}
} finally {
    Write-Output "Escrituras correctas: $ok  |  Intentos sin servicio: $fallos"
}
