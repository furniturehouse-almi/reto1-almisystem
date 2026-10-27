# Configura el testigo de recurso compartido (3er voto del quorum) en DC03.
# P1 crea antes C:\Witness compartida como \\DC03\Witness con control total para FHSQLCLU$.
. "$PSScriptRoot\00-config.ps1"
Set-ClusterQuorum -Cluster $Cluster -FileShareWitness $Testigo
Get-ClusterQuorum -Cluster $Cluster | Format-List Cluster, QuorumResource, QuorumType
