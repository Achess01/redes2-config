#!/bin/bash
# debian_firewall_static.sh
# Configura las VLANs estáticas del firewall hacia los 2 ISPs simulados

# /etc/iproute2/rt_tables
# 100 isp1
# 200 isp2


### CONFIGURACIÓN ###
IFACE="enp1s0"      # interfaz conectada al Ubuntu
VLAN1_ID=70
VLAN2_ID=80
IP_ISP1="192.168.70.2/24"
IP_ISP2="192.168.80.2/24"
GW_ISP1="192.168.70.1"
GW_ISP2="192.168.80.1"

### FUNCIONES ###
setup_vlans() {
  echo "[+] Creando VLANs..."
  ip link add link $IFACE name ${IFACE}.${VLAN1_ID} type vlan id $VLAN1_ID
  ip link add link $IFACE name ${IFACE}.${VLAN2_ID} type vlan id $VLAN2_ID

  ip addr add $IP_ISP1 dev ${IFACE}.${VLAN1_ID}
  ip addr add $IP_ISP2 dev ${IFACE}.${VLAN2_ID}

  ip link set ${IFACE}.${VLAN1_ID} up
  ip link set ${IFACE}.${VLAN2_ID} up
}

add_route() {
  echo "[+] Añadiendo rutas..."

  sudo ip route add default via $GW_ISP1 dev ${IFACE}.${VLAN1_ID}
  # Rutas base
  sudo ip route add 192.168.70.0/24 dev ${IFACE}.${VLAN1_ID} src 192.168.70.2 table isp1
  sudo ip route add default via 192.168.70.1 dev ${IFACE}.${VLAN1_ID} table isp1

  sudo ip route add 192.168.80.0/24 dev ${IFACE}.${VLAN2_ID} src 192.168.80.2 table isp2
  sudo ip route add default via 192.168.80.1 dev ${IFACE}.${VLAN2_ID} table isp2

  sudo ip rule add from 192.168.70.2 table isp1
  sudo ip rule add from 192.168.80.2 table isp2
}

test_connectivity() {
  echo "[+] Probando conectividad con gateways..."
  ping -c 2 $GW_ISP1
  ping -c 2 $GW_ISP2
}

cleanup() {
  echo "[+] Limpiando configuración..."
  ip link del ${IFACE}.${VLAN1_ID} 2>/dev/null
  ip link del ${IFACE}.${VLAN2_ID} 2>/dev/null
}

### MENÚ ###
case "$1" in
  start)
    setup_vlans
    add_route
    test_connectivity
    ;;
  stop)
    cleanup
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    ;;
esac
