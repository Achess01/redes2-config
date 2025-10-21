#!/bin/bash

if [ "$EUID" -ne 0 ]; then
	echo "Sin permisos SUDO"
	exit 1
fi

# Crear el contenido del archivo
CONFIG_CONTENT="# INTRANET INTERFACE (DEBE ESTAR UP PERO SIN IP)
auto enp2s0
iface enp2s0 inet manual

# VLAN 10 - ADMIN
auto enp2s0.10
iface enp2s0.10 inet static
	address 192.168.10.1
	netmask 255.255.255.0
	vlan-raw-device enp2s0

# VLAN 20 - CLIENTES
auto enp2s0.20
iface enp2s0.20 inet static
	address 192.168.20.1
	netmask 255.255.255.0
	vlan-raw-device enp2s0

# VLAN 30 - ZABBIX SERVER
auto enp2s0.30
iface enp2s0.30 inet static
	address 192.168.30.1
	netmask 255.255.255.0
	vlan-raw-device enp2s0

# VLAN 40 - WORDPRESS SERVER
auto enp2s0.40
iface enp2s0.40 inet static
	address 192.168.40.1
	netmask 255.255.255.0
	vlan-raw-device enp2s0

allow-hotplug enx00e04c3601b7
iface enx00e04c3601b7 inet static
	address 192.168.50.2
	netmask 255.255.255.252
	gateway 192.168.50.1"

# Escribir la nueva configuración
echo "$CONFIG_CONTENT" > /etc/network/interfaces

# Verificar que se escribió correctamente
if [ $? -eq 0 ]; then
	echo "Configuración completada"
else
	echo "Error durante la configuracion"
	exit 1
fi

