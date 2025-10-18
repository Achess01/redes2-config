#!/bin/bash

# ==============================================================================
# Script para detener el modo router y limpiar la configuración.
# ==============================================================================

# --- ¡CONFIGURAR ESTAS VARIABLES! ---
# Deben ser las mismas que en el script de configuración.
WAN_IF="wlan0"
LAN_IF="eno1"
# ------------------------------------

# 1. Comprobar si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

echo "--- Iniciando limpieza del modo Router/ICS ---"

# 2. Eliminar la regla de NAT de iptables
echo "[+] Eliminando regla de NAT de iptables..."
iptables -t nat -D POSTROUTING -o $WAN_IF -j MASQUERADE 2>/dev/null

# 3. Deshabilitar el reenvío de paquetes
echo "[+] Deshabilitando reenvío de IP..."
sysctl -w net.ipv4.ip_forward=0 > /dev/null

# 4. Detener dnsmasq y limpiar la configuración
echo "[+] Deteniendo y limpiando el servidor DHCP (dnsmasq)..."
systemctl stop dnsmasq
rm -f /etc/dnsmasq.d/ics-config

# 5. Resetear la interfaz LAN
echo "[+] Reseteando la interfaz LAN ($LAN_IF)..."
ip addr flush dev $LAN_IF
ip link set dev $LAN_IF down

echo ""
echo "--- ✅ Limpieza completada ---"
echo "La configuración de red ha sido restaurada."
