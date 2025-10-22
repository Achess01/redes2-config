#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Sin permiso SUDO"
  exit 1
fi

IF_PROXY="enx00e04c3601b7"

# PERMITIR todo
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# FLUSH RULES
iptables -F

# DELETE CUSTOM RULES (INTERNET_IP, INTERNET_MAC)
iptables -X

# Limpiar la tabla NAT
iptables -t nat -F
iptables -t nat -X
# Limpiar la tabla Mangle
iptables -t mangle -F
iptables -t mangle -X

# regla para que las VLANs salgan a internet
iptables -t nat -A POSTROUTING -o $IF_PROXY -j MASQUERADE


