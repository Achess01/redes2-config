#!/bin/bash
IFACE="enx00e04c3600fa"    # Interfaz física conectada al firewall
VLAN1_ID=10
VLAN2_ID=20
IP_ISP1="10.10.10.3/24"
IP_ISP2="10.10.20.3/24"
GW_ISP1="10.10.10.1"
GW_ISP2="10.10.20.1"

# Nombres cortos para las VLANs
VLAN1_NAME="wan10"
VLAN2_NAME="wan20"

create_vlans() {
  echo "[+] Creando VLANs..."

  # Eliminar si existen (para evitar errores)
  ip link del $VLAN1_NAME 2>/dev/null
  ip link del $VLAN2_NAME 2>/dev/null

  # Crear interfaces VLAN
  ip link add link $IFACE name $VLAN1_NAME type vlan id $VLAN1_ID
  ip link add link $IFACE name $VLAN2_NAME type vlan id $VLAN2_ID

  # Asignar IPs
  ip addr add $IP_ISP1 dev $VLAN1_NAME
  ip addr add $IP_ISP2 dev $VLAN2_NAME

  # Activar interfaces
  ip link set $VLAN1_NAME up
  ip link set $VLAN2_NAME up

  # Esperar para que el kernel reconozca las interfaces
  sleep 2
}

setup_routes() {
  echo "[+] Configurando rutas y tablas de ruteo..."

  # Crear tablas personalizadas solo si no existen
  grep -q "100 isp1" /etc/iproute2/rt_tables || echo "100 isp1" >> /etc/iproute2/rt_tables
  grep -q "200 isp2" /etc/iproute2/rt_tables || echo "200 isp2" >> /etc/iproute2/rt_tables

  # Limpiar posibles rutas previas
  ip route flush table isp1
  ip route flush table isp2

  # Asegurarse de que las interfaces estén activas
  ip link set $VLAN1_NAME up
  ip link set $VLAN2_NAME up

  # Rutas específicas por tabla
  ip route add 10.10.10.0/24 dev $VLAN1_NAME src ${IP_ISP1%/*} table isp1
  ip route add default via $GW_ISP1 dev $VLAN1_NAME table isp1

  ip route add 10.10.20.0/24 dev $VLAN2_NAME src ${IP_ISP2%/*} table isp2
  ip route add default via $GW_ISP2 dev $VLAN2_NAME table isp2

  # Limpiar reglas previas de estas IPs (para evitar duplicados)
  ip rule del from ${IP_ISP1%/*} table isp1 2>/dev/null
  ip rule del from ${IP_ISP2%/*} table isp2 2>/dev/null

  # Reglas de policy routing
  ip rule add from ${IP_ISP1%/*} table isp1
  ip rule add from ${IP_ISP2%/*} table isp2

  # Ruta por defecto global (solo si no existe)
  if ! ip route | grep -q "^default"; then
    ip route add default via $GW_ISP1 dev $VLAN1_NAME
  else
    echo "[!] Ruta por defecto ya existente, no se reemplaza."
  fi
}

cleanup() {
  echo "[+] Limpiando configuración previa..."

  # Limpiar reglas específicas
  ip rule del from ${IP_ISP1%/*} table isp1 2>/dev/null
  ip rule del from ${IP_ISP2%/*} table isp2 2>/dev/null

  # Limpiar rutas
  ip route flush table isp1
  ip route flush table isp2

  # Eliminar VLANs
  ip link del $VLAN1_NAME 2>/dev/null
  ip link del $VLAN2_NAME 2>/dev/null

  echo "[+] Limpieza completa."
}

# ====== MENÚ ======
case "$1" in
  start)
    create_vlans
    setup_routes
    ;;
  stop)
    cleanup
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    ;;
esac
