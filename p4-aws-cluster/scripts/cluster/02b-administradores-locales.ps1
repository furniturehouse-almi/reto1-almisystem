# Tras unir el nodo al dominio: adrian y G_SQL_Admins pasan a ser administradores locales.
# Se usa el SID S-1-5-32-544 para que funcione con Windows en cualquier idioma.
. "$PSScriptRoot\00-config.ps1"
Add-LocalGroupMember -SID S-1-5-32-544 -Member "$NetBIOS\adrian", $GrupoAdmins -ErrorAction SilentlyContinue
Get-LocalGroupMember -SID S-1-5-32-544
