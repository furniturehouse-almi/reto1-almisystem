# P4 · AWS y clúster SQL Server

## Clúster SQL Server Always On (local, VirtualBox)
| Elemento | Valor |
|---|---|
| Dominio | `ad.furniturehouse2.com` (NetBIOS `FURNITURE`) |
| Nodos | `SQL1` 192.168.12.31 · `SQL2` 192.168.12.32 (Windows Server 2022, SQL Server 2022) |
| Clúster de Windows | `FHSQLCLU` 192.168.12.33 · sin discos compartidos |
| Testigo | `\\DC03\Witness` (DC03 192.168.12.30) |
| Grupo de disponibilidad | `AG_Furniture` · síncrono · failover automático · seeding automático |
| Listener | **`FHSQL` 192.168.12.34:1433** ← las aplicaciones se conectan siempre aquí |
| Cuentas | servicio `FURNITURE\svc_sql` · administradores `FURNITURE\G_SQL_Admins` |

### Scripts (`scripts/cluster`) — en orden
| Script | Dónde | Qué hace |
|---|---|---|
| `00-config.ps1` | — | Nombres e IPs comunes |
| `01-preparar-nodo.ps1 -Nombre SQL1` | cada nodo | IP fija, DNS, ping, nombre |
| `02-unir-dominio.ps1` + `02b-…` | cada nodo | Unir al dominio en la OU `Servidores\SQL` y administradores locales |
| `03-instalar-sql.ps1` | cada nodo | Failover Clustering, firewall 1433/5022, SQL Server desatendido |
| `04-crear-cluster.ps1` | SQL1 | Test-Cluster, New-Cluster, latidos tolerantes, permisos de svc_sql |
| `05-always-on.ps1` | SQL1 | Always On, endpoints, base de datos, AG y listener |
| `06-testigo.ps1` | SQL1 | Testigo de recurso compartido |
| `07-prueba-failover.ps1` | SQL1 | Escritura continua para la prueba de failover |

> Requisitos que hace P1 en el dominio: usuario `adrian`, grupo `G_SQL_Admins`, cuenta `svc_sql` (sin caducidad), OU `Servidores\SQL`, objeto `FHSQLCLU` pre-creado, permiso "Crear objetos de equipo" para `FHSQLCLU$` y SPN de `svc_sql`.

### Cómo apagar y encender
- **Apagar:** SQL2 → SQL1 → DC03, siempre con `Stop-Computer` (nunca "Guardar estado" en VirtualBox).
- **Encender:** DC01 encendido → SQL1 → SQL2 → DC03. Comprobar `Get-ClusterNode -Cluster FHSQLCLU`.

## AWS (`terraform/`)
- `terraform/base`: VPC 10.40.0.0/16 en 3 zonas, subredes públicas/app/datos, **instancia NAT** (más barata que un NAT gateway), Security Groups. Las Windows de ensayo del clúster solo se crean con `-var="windows_lab=true"`.
- `terraform/web`: WordPress (ALB + Auto Scaling + EFS + base de datos MySQL) — en construcción.

```powershell
cd p4-aws-cluster/terraform/base
terraform init
terraform plan
terraform apply      # al acabar el día: terraform destroy
```
El estado (`*.tfstate`) y las credenciales **no se suben** al repositorio.
