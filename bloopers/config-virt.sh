#!/bin/bash

# ==============================================================================
# Script para Simular dos Proveedores de Internet (ISPs) usando
# VLANs y Network Namespaces en Ubuntu.
# ==============================================================================


WIFI_IF="wlo1"

ETH_IF="eno1"

# 1. Comprobar si el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

echo "--- Iniciando configuración del simulador de ISPs ---"

# 2. Habilitar el reenvío de paquetes IP
echo "[+] Habilitando IP Forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 3. Crear las interfaces VLAN
echo "[+] Creando interfaces VLAN (10 y 20) en $ETH_IF..."
ip link add link $ETH_IF name $ETH_IF.10 type vlan id 10
ip link add link $ETH_IF name $ETH_IF.20 type vlan id 20
ip link set $ETH_IF up
ip link set $ETH_IF.10 up
ip link set $ETH_IF.20 up

# 4. Crear los Namespaces de Red
echo "[+] Creando Namespaces 'isp1' e 'isp2'..."
ip netns add isp1
ip netns add isp2

# 5. Crear los pares de interfaces virtuales (veth pairs)
echo "[+] Creando 'cables virtuales' (veth pairs)..."
ip link add veth-isp1 type veth peer name veth-ns1
ip link add veth-isp2 type veth peer name veth-ns2

# 6. Mover un extremo de cada veth a su respectivo namespace
echo "[+] Conectando 'cables' a los namespaces..."
ip link set veth-ns1 netns isp1
ip link set veth-ns2 netns isp2

# 7. Crear los puentes (bridges)
echo "[+] Creando puentes (br-isp1 y br-isp2)..."
ip link add name br-isp1 type bridge
ip link add name br-isp2 type bridge

# 8. Conectar las VLANs y los veths a los puentes
echo "[+] Conectando VLANs y veths a los puentes..."
ip link set $ETH_IF.10 master br-isp1
ip link set veth-isp1 master br-isp1
ip link set br-isp2 up

ip link set $ETH_IF.20 master br-isp2
ip link set veth-isp2 master br-isp2
ip link set br-isp1 up

# 9. Configurar la red DENTRO de cada namespace
echo "[+] Configurando IPs y rutas dentro de los namespaces..."
# Configuración para ISP1
ip netns exec isp1 ip addr add 192.168.10.1/24 dev veth-ns1
ip netns exec isp1 ip link set veth-ns1 up
ip netns exec isp1 ip link set lo up
ip netns exec isp1 ip route add default via 192.168.10.1

# Configuración para ISP2
ip netns exec isp2 ip addr add 192.168.20.1/24 dev veth-ns2
ip netns exec isp2 ip link set veth-ns2 up
ip netns exec isp2 ip link set lo up
ip netns exec isp2 ip route add default via 192.168.20.1

# 10. Aplicar reglas de NAT con iptables
echo "[+] Aplicando reglas de NAT (Masquerade) con iptables..."
iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -o $WIFI_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.20.0/24 -o $WIFI_IF -j MASQUERADE

echo ""
echo "--- ✅ Configuración completada ---"
echo "Tu máquina Ubuntu ahora está simulando dos ISPs."
echo "Conecta el cable desde '$ETH_IF' a tu firewall Debian."
echo ""
echo "Para simular una caída de ISP1, usa: sudo ip link set br-isp1 down"
echo "Para reactivarlo, usa: sudo ip link set br-isp1 up"
echo ""