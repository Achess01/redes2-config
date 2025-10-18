#!/bin/bash
IFACE="enx00e04c3600fa"    # Interfaz física conectada al firewall
VLAN1_ID=10
VLAN2_ID=20
IP_ISP1="10.10.10.3/24"
IP_ISP2="10.10.20.3/24"
GW_ISP1="10.10.10.1"
GW_ISP2="10.10.20.1"

create_vlans() {
  echo "[+] Creando VLANs..."

  ip link add link $IFACE name ${IFACE}.${VLAN1_ID} type vlan id $VLAN1_ID
  ip link add link $IFACE name ${IFACE}.${VLAN2_ID} type vlan id $VLAN2_ID

  ip addr add $IP_ISP1 dev ${IFACE}.${VLAN1_ID}
  ip addr add $IP_ISP2 dev ${IFACE}.${VLAN2_ID}

  ip link set ${IFACE}.${VLAN1_ID} up
  ip link set ${IFACE}.${VLAN2_ID} up
}

setup_routes() {
  echo "[+] Configurando rutas y tablas de ruteo..."

  # Asegurarse de que las tablas existen
  grep -q "100 isp1" /etc/iproute2/rt_tables || echo "100 isp1" >> /etc/iproute2/rt_tables
  grep -q "200 isp2" /etc/iproute2/rt_tables || echo "200 isp2" >> /etc/iproute2/rt_tables

  # Rutas por tabla
  ip route add 10.10.10.0/24 dev ${IFACE}.${VLAN1_ID} src ${IP_ISP1%/*} table isp1
  ip route add default via $GW_ISP1 dev ${IFACE}.${VLAN1_ID} table isp1

  ip route add 10.10.20.0/24 dev ${IFACE}.${VLAN2_ID} src ${IP_ISP2%/*} table isp2
  ip route add default via $GW_ISP2 dev ${IFACE}.${VLAN2_ID} table isp2

  # Reglas por IP de origen
  ip rule add from ${IP_ISP1%/*} table isp1
  ip rule add from ${IP_ISP2%/*} table isp2

  # Ruta por defecto general → ISP1
  ip route add default via $GW_ISP1 dev ${IFACE}.${VLAN1_ID}
}

cleanup() {
  echo "[+] Limpiando configuración previa..."

  iptables -t nat -F
  ip rule flush
  ip route flush table isp1
  ip route flush table isp2

  ip link del ${IFACE}.${VLAN1_ID} 2>/dev/null
  ip link del ${IFACE}.${VLAN2_ID} 2>/dev/null
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
