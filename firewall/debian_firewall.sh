#!/bin/bash

WAN_IF="enp1s0"        # interfaz física hacia Ubuntu (ISPs)
LAN_IF="enx00e04c3603ba"        # interfaz física hacia balanceador

# VLANs hacia Ubuntu (ISPs simulados)
VLAN_ISP1_ID=70
VLAN_ISP2_ID=80
ISP1_NET="192.168.70.0/24"
ISP2_NET="192.168.80.0/24"
ISP1_IP="192.168.70.2/24"
ISP2_IP="192.168.80.2/24"
ISP1_GW="192.168.70.1"
ISP2_GW="192.168.80.1"

# VLANs hacia el balanceador
VLAN_LAN1_ID=10
VLAN_LAN2_ID=20
LAN1_NET="10.10.10.0/24"
LAN2_NET="10.10.20.0/24"
LAN1_IP="10.10.10.1/24"
LAN2_IP="10.10.20.1/24"

# ====== FUNCIONES ======

create_vlans() {
  echo "[+] Creando VLANs..."

  # VLANs WAN
  ip link add link $WAN_IF name ${WAN_IF}.${VLAN_ISP1_ID} type vlan id $VLAN_ISP1_ID
  ip link add link $WAN_IF name ${WAN_IF}.${VLAN_ISP2_ID} type vlan id $VLAN_ISP2_ID
  ip addr add $ISP1_IP dev ${WAN_IF}.${VLAN_ISP1_ID}
  ip addr add $ISP2_IP dev ${WAN_IF}.${VLAN_ISP2_ID}
  ip link set ${WAN_IF}.${VLAN_ISP1_ID} up
  ip link set ${WAN_IF}.${VLAN_ISP2_ID} up

  # VLANs LAN
  ip link add link $LAN_IF name ${LAN_IF}.${VLAN_LAN1_ID} type vlan id $VLAN_LAN1_ID
  ip link add link $LAN_IF name ${LAN_IF}.${VLAN_LAN2_ID} type vlan id $VLAN_LAN2_ID
  ip addr add $LAN1_IP dev ${LAN_IF}.${VLAN_LAN1_ID}
  ip addr add $LAN2_IP dev ${LAN_IF}.${VLAN_LAN2_ID}
  ip link set ${LAN_IF}.${VLAN_LAN1_ID} up
  ip link set ${LAN_IF}.${VLAN_LAN2_ID} up
}

enable_forwarding() {
  echo "[+] Habilitando reenvío de paquetes..."
  sysctl -w net.ipv4.ip_forward=1
}

setup_nat() {
  echo "[+] Configurando reglas NAT..."

  # Limpiar reglas previas
  iptables -t nat -F
  iptables -F FORWARD

  # Permitir reenvío
  iptables -P FORWARD ACCEPT

  # NAT: tráfico LAN → WAN
  iptables -t nat -A POSTROUTING -s $LAN1_NET -o ${WAN_IF}.${VLAN_ISP1_ID} -j MASQUERADE
  iptables -t nat -A POSTROUTING -s $LAN1_NET -o ${WAN_IF}.${VLAN_ISP2_ID} -j MASQUERADE
  iptables -t nat -A POSTROUTING -s $LAN2_NET -o ${WAN_IF}.${VLAN_ISP1_ID} -j MASQUERADE
  iptables -t nat -A POSTROUTING -s $LAN2_NET -o ${WAN_IF}.${VLAN_ISP2_ID} -j MASQUERADE
}

setup_routes() {
  echo "[+] Configurando rutas y tablas..."

  # Tablas personalizadas
  echo "100 isp1" >> /etc/iproute2/rt_tables
  echo "200 isp2" >> /etc/iproute2/rt_tables

  # Rutas por tabla
  ip route add $ISP1_NET dev ${WAN_IF}.${VLAN_ISP1_ID} src ${ISP1_IP%/*} table isp1
  ip route add default via $ISP1_GW dev ${WAN_IF}.${VLAN_ISP1_ID} table isp1

  ip route add $ISP2_NET dev ${WAN_IF}.${VLAN_ISP2_ID} src ${ISP2_IP%/*} table isp2
  ip route add default via $ISP2_GW dev ${WAN_IF}.${VLAN_ISP2_ID} table isp2

  # Reglas de política (para tráfico originado desde las IP WAN)
  ip rule add from ${ISP1_IP%/*} table isp1
  ip rule add from ${ISP2_IP%/*} table isp2

  # Rutas LAN locales
  ip route add $LAN1_NET dev ${LAN_IF}.${VLAN_LAN1_ID}
  ip route add $LAN2_NET dev ${LAN_IF}.${VLAN_LAN2_ID}

  # Ruta global por defecto (para tráfico general)
  ip route add default via $ISP1_GW dev ${WAN_IF}.${VLAN_ISP1_ID}
}

cleanup() {
  echo "[+] Limpiando configuración..."

  # Borrar reglas NAT y políticas
  iptables -t nat -F
  iptables -F FORWARD
  ip rule flush
  ip route flush table isp1
  ip route flush table isp2

  # Eliminar VLANs
  ip link del ${WAN_IF}.${VLAN_ISP1_ID} 2>/dev/null
  ip link del ${WAN_IF}.${VLAN_ISP2_ID} 2>/dev/null
  ip link del ${LAN_IF}.${VLAN_LAN1_ID} 2>/dev/null
  ip link del ${LAN_IF}.${VLAN_LAN2_ID} 2>/dev/null
}

# ====== MENÚ ======
case "$1" in
  start)
    create_vlans
    enable_forwarding
    setup_nat
    setup_routes
    ;;
  stop)
    cleanup
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    ;;
esac
