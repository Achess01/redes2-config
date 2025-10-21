#!/bin/bash

read -p "Ingrese el el maximo de ancho de banda (up) en Mbps: " BWU;
read -p "Ingrese el el maximo de ancho de banda (down) en Mbps: " BWD;

((BWIN=(BWU)*1024)) # ancho de banda subida (upload) en Kbit
((BWOUT=(BWD)*1024)) # ancho de banda bajada (download) en Kbit
echo "*********************************************"
echo "* El ancho de banda total UP es de: ${BWIN}Kbit *"
echo "* El ancho de banda total DOWN es de: ${BWOUT}Kbit *"
echo "*********************************************"

# --- VARIABLES ACTUALIZADAS (PARA wan80 Y 192.168.80.3) ---
interfaceISP='wan80'; # Sub-interfaz VLAN 80 
INTERFACE_IN='wan80'; # Sub-interfaz VLAN 80 (entrada)
INTERFACE_OUT='ifb0'; # Interfaz virtual para el tráfico de bajada (download)
IP='192.168.80.3'; # IP del balanceador para este ISP
IN="/usr/sbin/tc  filter add dev $INTERFACE_IN parent 1:0 protocol ip prio 1 u32 match ip dst"
OUT="/usr/sbin/tc  filter add dev $INTERFACE_OUT parent 1:0 protocol ip prio 1 u32 match ip src"

# limpiar
/usr/sbin/tc qdisc del dev $interfaceISP root 2>/dev/null
/usr/sbin/tc qdisc del dev $interfaceISP ingress 2>/dev/null
/usr/sbin/tc qdisc del dev ifb0 root 2>/dev/null


modprobe ifb numifbs=1
ip link set dev $INTERFACE_OUT up

/usr/sbin/tc  qdisc del dev $INTERFACE_IN root 2>/dev/null
/usr/sbin/tc  qdisc del dev $INTERFACE_IN ingress 2>/dev/null
/usr/sbin/tc  qdisc del dev $INTERFACE_OUT root 2>/dev/null

# Redirección de tráfico entrante a ifb0 para aplicar QoS (Download)
/usr/sbin/tc  qdisc add dev $INTERFACE_IN handle ffff: ingress
/usr/sbin/tc  filter add dev $INTERFACE_IN parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev $INTERFACE_OUT

# Creando enlace para SUBIDA (Upload) - Se aplica en la interfaz física $INTERFACE_IN
/usr/sbin/tc  qdisc add dev $INTERFACE_IN root handle 1: htb
/usr/sbin/tc  class add dev $INTERFACE_IN parent 1: classid 1:10 htb rate ${BWIN}kbit ceil ${BWIN}kbit
/usr/sbin/tc qdisc add dev $INTERFACE_IN parent 1:10 handle 10: sfq perturb 10

# Creando enlace para BAJADA (Download) - Se aplica en la interfaz virtual $INTERFACE_OUT
/usr/sbin/tc  qdisc add dev $INTERFACE_OUT root handle 1: htb
/usr/sbin/tc  class add dev $INTERFACE_OUT parent 1: classid 1:10 htb rate ${BWOUT}kbit ceil ${BWOUT}kbit
/usr/sbin/tc qdisc add dev $INTERFACE_OUT parent 1:10 handle 10: sfq perturb 10

# Asignando IP (No es necesario si se usa HTB, pero se mantiene la estructura de tu script)
$IN $IP flowid 1:10
$OUT $IP flowid 1:10
