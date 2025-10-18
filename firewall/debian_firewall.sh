#!/bin/bash
# ===========================================================
# Configuración persistente de red - FIREWALL
# VLANs hacia ISPs y VLANs hacia Load Balancer
# ===========================================================

cat <<'EOF' | sudo tee /etc/network/interfaces > /dev/null
# ===========================================================
# Archivo generado automáticamente - FIREWALL
# ===========================================================

# Loopback
auto lo
iface lo inet loopback

# Interfaz hacia los ISPs (Ubuntu)
auto enp1s0
iface enp1s0 inet manual

# Interfaz hacia el Load Balancer
auto enx00e04c3603ba
iface enx00e04c3603ba inet manual

# ===============================
# VLANs WAN hacia los ISPs
# ===============================

# VLAN 70 - ISP1
auto enp1s0.70
iface enp1s0.70 inet static
    address 192.168.70.2
    netmask 255.255.255.0
    gateway 192.168.70.1
    vlan-raw-device enp1s0

# VLAN 80 - ISP2
auto enp1s0.80
iface enp1s0.80 inet static
    address 192.168.80.2
    netmask 255.255.255.0
    gateway 192.168.80.1
    vlan-raw-device enp1s0

# ===============================
# VLANs LAN hacia el Load Balancer
# ===============================

# VLAN 10 - hacia Load Balancer (ISP1 interno)
auto enx00e04c3603ba.10
iface enx00e04c3603ba.10 inet static
    address 10.10.10.1
    netmask 255.255.255.0
    vlan-raw-device enx00e04c3603ba
    post-up ip rule add from 10.10.10.0/24 table isp1
    post-up ip route add default via 192.168.70.1 dev enp1s0.70 table isp1
    pre-down ip rule del from 10.10.10.0/24 table isp1
    pre-down ip route flush table isp1

# VLAN 20 - hacia Load Balancer (ISP2 interno)
auto enx00e04c3603ba.20
iface enx00e04c3603ba.20 inet static
    address 10.10.20.1
    netmask 255.255.255.0
    vlan-raw-device enx00e04c3603ba
    post-up ip rule add from 10.10.20.0/24 table isp2
    post-up ip route add default via 192.168.80.1 dev enp1s0.80 table isp2
    pre-down ip rule del from 10.10.20.0/24 table isp2
    pre-down ip route flush table isp2

# Habilitar reenvío de paquetes IPv4
post-up sysctl -w net.ipv4.ip_forward=1

# Reglas NAT para salida a Internet
post-up iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp1s0.70 -j MASQUERADE
post-up iptables -t nat -A POSTROUTING -s 10.10.20.0/24 -o enp1s0.80 -j MASQUERADE
pre-down iptables -t nat -D POSTROUTING -s 10.10.10.0/24 -o enp1s0.70 -j MASQUERADE
pre-down iptables -t nat -D POSTROUTING -s 10.10.20.0/24 -o enp1s0.80 -j MASQUERADE
EOF

echo "[+] Configuración del FIREWALL escrita en /etc/network/interfaces"
echo "[+] Reinicia el servicio de red con: sudo systemctl restart networking"
