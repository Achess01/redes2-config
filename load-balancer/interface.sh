#!/bin/bash

# ----------------------------------------------------------------------
# Script de configuración de interfaz estática en Debian (ifupdown)
# Interfaz: enp2s0f0
# Requiere permisos de superusuario (sudo).
# ----------------------------------------------------------------------

# Variables de configuración (Ajustar si es necesario)
IFACE="enp2s0f0"
IP_ADDRESS="192.168.60.10" # IP estática para la interfaz
NETMASK="255.255.255.0"
GATEWAY="192.168.60.3"    # Gateway (192.168.60.3)

echo "Iniciando configuración estática para la interfaz $IFACE..."

# 1. Crear el bloque de configuración estática
CONFIG_BLOCK="
# Configuración estática para $IFACE (Generada por script)
auto $IFACE
iface $IFACE inet static
    address $IP_ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
"

# 2. Agregar la configuración al archivo /etc/network/interfaces
#    Utilizamos 'tee -a' para agregar al final del archivo.
echo "$CONFIG_BLOCK" | sudo tee -a /etc/network/interfaces > /dev/null

echo "Configuración escrita en /etc/network/interfaces."

# 3. Aplicar la configuración levantando la interfaz
#    El comando 'ifup' lee la nueva configuración del archivo y la aplica.
echo "Aplicando la configuración con ifup..."
sudo ifup "$IFACE"

# 4. Verificar la configuración
echo "Verificación de la configuración de $IFACE:"
ip a show "$IFACE"

echo "Ruta por defecto (Gateway) configurada en $GATEWAY:"
ip r show default

echo "¡Configuración finalizada!"