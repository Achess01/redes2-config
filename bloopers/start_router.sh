#!/bin/bash


WAN_IF="wlo1"
LAN_IF="eno1"

# La dirección IP que tendrá este router en la red local
LAN_IP="192.168.10.1"
# ------------------------------------

# 1. Comprobar si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

echo "--- Iniciando configuración de Router/ICS (Modo Estático) ---"

# 2. Configurar la interfaz LAN con una IP estática
echo "[+] Configurando la interfaz LAN ($LAN_IF) con la IP $LAN_IP..."
ip addr flush dev $LAN_IF
ip addr add ${LAN_IP}/24 dev $LAN_IF
ip link set dev $LAN_IF up

# 3. Habilitar el reenvío de paquetes en el kernel
echo "[+] Habilitando reenvío de IP (IP Forwarding)..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 4. Activar NAT (Masquerade) con iptables
echo "[+] Aplicando regla de NAT con iptables..."
# Limpiar reglas anteriores por si acaso
iptables -t nat -D POSTROUTING -o $WAN_IF -j MASQUERADE 2>/dev/null
# Añadir la nueva regla
iptables -t nat -A POSTROUTING -o $WAN_IF -j MASQUERADE

echo ""
echo "--- ✅ Configuración completada ---"
echo "Ubuntu ahora está compartiendo internet desde '$WAN_IF' hacia '$LAN_IF'."
echo "Tu firewall Debian debe tener una IP estática en la red 192.168.10.0/24."
