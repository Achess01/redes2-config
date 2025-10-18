#!/bin/bash
# ubuntu_isp_static.sh
# Simula dos ISP mediante VLANs con IPs estáticas y NAT hacia wlan0

### CONFIGURACIÓN ###
LAN_IF="eno1"      # interfaz cableada al firewall
WAN_IF="wlo1"       # interfaz con Internet
VLAN1_ID=70
VLAN2_ID=80
VLAN1_IP="192.168.70.1/24"
VLAN2_IP="192.168.80.1/24"

### FUNCIONES ###
create_vlans() {
  echo "[+] Creando VLANs..."
  ip link add link $LAN_IF name ${LAN_IF}.${VLAN1_ID} type vlan id $VLAN1_ID
  ip link add link $LAN_IF name ${LAN_IF}.${VLAN2_ID} type vlan id $VLAN2_ID

  ip addr add $VLAN1_IP dev ${LAN_IF}.${VLAN1_ID}
  ip addr add $VLAN2_IP dev ${LAN_IF}.${VLAN2_ID}

  ip link set ${LAN_IF}.${VLAN1_ID} up
  ip link set ${LAN_IF}.${VLAN2_ID} up
}

enable_nat() {
  echo "[+] Activando NAT..."
  iptables -t nat -A POSTROUTING -o $WAN_IF -s 192.168.70.0/24 -j MASQUERADE
  iptables -t nat -A POSTROUTING -o $WAN_IF -s 192.168.80.0/24 -j MASQUERADE
}

disable_nat() {
  echo "[+] Limpiando reglas NAT..."
  iptables -t nat -F
}

delete_vlans() {
  echo "[+] Eliminando VLANs..."
  ip link del ${LAN_IF}.${VLAN1_ID} 2>/dev/null
  ip link del ${LAN_IF}.${VLAN2_ID} 2>/dev/null
}

disable_vlan() {
  VLAN=$1
  echo "[+] Apagando VLAN $VLAN..."
  ip link set ${LAN_IF}.${VLAN} down
}

enable_vlan() {
  VLAN=$1
  echo "[+] Encendiendo VLAN $VLAN..."
  ip link set ${LAN_IF}.${VLAN} up
}

### MENÚ ###
case "$1" in
  start)
    create_vlans
    enable_nat
    ;;
  stop)
    disable_nat
    delete_vlans
    ;;
  isp1_off)
    disable_vlan $VLAN1_ID
    ;;
  isp1_on)
    enable_vlan $VLAN1_ID
    ;;
  isp2_off)
    disable_vlan $VLAN2_ID
    ;;
  isp2_on)
    enable_vlan $VLAN2_ID
    ;;
  *)
    echo "Uso: $0 {start|stop|isp1_off|isp1_on|isp2_off|isp2_on}"
    ;;
esac
