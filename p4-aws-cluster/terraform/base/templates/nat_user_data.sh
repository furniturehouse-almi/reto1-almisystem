#!/bin/bash
# Convierte una Amazon Linux 2023 en router NAT (se ejecuta solo al crearla)
# 14 oct: corregido. En el primer arranque "dnf install" falló (repositorios aún
# no disponibles) y, como el script se paraba al primer error, nunca se creó la
# regla MASQUERADE → las máquinas privadas no salían a Internet. Ahora reintenta.
exec > >(tee -a /var/log/nat-setup.log) 2>&1

# 1. Activar el reenvío de paquetes (para siempre)
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/90-nat.conf
sysctl -p /etc/sysctl.d/90-nat.conf

# 2. Instalar iptables-services, reintentando hasta 10 veces
for i in $(seq 1 10); do
  dnf install -y iptables-services && break
  echo "dnf falló (intento $i), reintento en 15 s..."
  sleep 15
done
systemctl enable --now iptables

# 3. Reglas: enmascarar (NAT) todo lo que salga por la tarjeta principal
IFACE=$(ip route show default | awk '{print $5}' | head -1)
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables

# 4. Comprobación en el log
iptables -t nat -S | grep -q MASQUERADE && echo "NAT OK" || echo "ERROR: falta la regla MASQUERADE"
