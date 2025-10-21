#!/bin/bash

set -e 

echo "Creando configuración de red con Netplan..."

NETPLAN_CONFIG="/etc/netplan/01-network.yaml"

# Crear el contenido YAML
cat <<EOF | sudo tee $NETPLAN_CONFIG > /dev/null
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    enx00e04c360031:
      dhcp4: no

  vlans:
    vlan10:
      id: 10
      link: enx00e04c360031
    vlan20:
      id: 20
      link: enx00e04c360031
    vlan30:
      id: 30
      link: enx00e04c360031
    vlan40:
      id: 40
      link: enx00e04c360031

  bridges:
    br10:
      interfaces: [vlan10]
      dhcp4: no
      addresses: [192.168.10.2/24] # IP estática para la VLAN de Administración
    br20:
      interfaces: [vlan20]
      dhcp4: no
      addresses: [192.168.20.2/24] # IP estática para la VLAN de Clientes
    br30:
      interfaces: [vlan30]
      dhcp4: no
      addresses: [192.168.30.2/24] # IP estática para la VLAN de zabbix
    br40:
      interfaces: [vlan40]
      dhcp4: no
      addresses: [192.168.40.2/24] # IP estática para la VLAN de WordPress
EOF

echo "Aplicando configuración de red..."
sudo netplan apply

echo "Configuración completada."