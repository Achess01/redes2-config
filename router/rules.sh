#!/bin/bash

# CHECK SUDO
if [ "$EUID" -ne 0 ]; then
  echo "Sin permiso SUDO"
  exit 1
fi

# ######################################################################

# VLANs
ADMIN_VLAN="192.168.10.0/24"
CLIENTS_VLAN="192.168.20.0/24"
ZABBIX_VLAN="192.168.30.0/24"
WP_VLAN="192.168.40.0/24"
# SERVERS
ZABBIX_SERVER_IP="192.168.30.10"
WP_SERVER_IP="192.168.40.10"
# PROXY
IF_PROXY="enx00e04c3601b7"
PROXY_NET="192.168.50.0/30"
# RED PARA CONFIGURACION DE ROUTER POR SSH (FOR DEVELOPMENT ONLY)
ROUTER_CONF_NET="192.168.255.0/30"

# ######################################################################
echo "Limpieza de reglas existentes y estableciendo políticas todo denegado"

# CLEAN RULES
iptables -F
iptables -X
iptables -Z

# DEFAULT DENY POLICY (POLITICA TODO DENEGADO)
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# ######################################################################
echo "Reglas para loopback y conexiones establecidas"

# Permitir trafico de loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Permitir el tráfico de retorno para conexiones
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# ######################################################################
echo "Reglas para VLAN de Administración"

# CONEXION SSH: ADMIN -> ROUTER 
iptables -A INPUT -s $ADMIN_VLAN -p tcp --dport 22 -j ACCEPT
# CONEXION ICMP: PROXY <-> ROUTER
iptables -A INPUT -i $IF_PROXY -s $PROXY_NET -p icmp -j ACCEPT

# ADMIN -> ZABBIX SERVER
iptables -A FORWARD -s $ADMIN_VLAN -d $ZABBIX_SERVER_IP -p tcp -m multiport --dports 80,443 -j ACCEPT

# ADMIN -> WORDPRESS SERVER
iptables -A FORWARD -s $ADMIN_VLAN -d $WP_SERVER_IP -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -s $ADMIN_VLAN -d $WP_SERVER_IP -p tcp -m multiport --dports 80,443 -j ACCEPT

# ADMIN -> EQUIPO DE INFRAESTRUCTURA (PROXY, LOAD BALANCER, FIREWALL)
iptables -A FORWARD -s $ADMIN_VLAN -p tcp --dport 22 -j ACCEPT

# CONEXION DIRECTA SSH CON EL ROUTER
iptables -A INPUT -s $ROUTER_CONF_NET -p tcp --dport 22 -j ACCEPT

# PARA PING ENTRE VLANS
iptables -A FORWARD -p icmp -j ACCEPT

# ######################################################################
echo "Reglas para VLAN de Clientes"

# CLIENTES -> WORDPRESS SERVER (HTTP y HTTPS)
iptables -A FORWARD -s $CLIENTS_VLAN -d $WP_SERVER_IP -p tcp -m multiport --dports 80,443 -j ACCEPT

# ######################################################################

echo "Reglas de salida para el Router"

# consultas DNS y pings
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT

# ######################################################################
echo "Regla NAT para la salida a Internet"

iptables -t nat -A POSTROUTING -o $IF_PROXY -j MASQUERADE

echo ""
echo "Configuracion de Router completada"


