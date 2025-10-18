#!/bin/bash

# ==============================================================================
# Script para configurar una máquina Ubuntu como un simulador de dos ISPs
# VERSIÓN 3: Script robusto con verificación y limpieza forzada.
# ==============================================================================

# Detiene el script inmediatamente si un comando falla
set -e

# --- Variables de Interfaz (Hardcoded) ---
WAN_IF="wlo1"
LAN_IF="eno1"

# --- Verificación de Privilegios ---
if [ "$EUID" -ne 0 ]; then
  echo "Error: Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

echo "--- Iniciando configuración del Simulador de ISPs ---"

# --- [PASO 0] LIMPIEZA FORZADA Y VERIFICACIÓN ---
echo "[0/5] Limpiando configuraciones de red anteriores..."

# Función para eliminar una VLAN si existe
cleanup_vlan() {
  local vlan_if=$1
  if ip link show "$vlan_if" > /dev/null 2>&1; then
    echo "Interfaz '$vlan_if' encontrada. Eliminando..."
    ip link set dev "$vlan_if" down
    ip link delete "$vlan_if"
    echo "Interfaz '$vlan_if' eliminada."
  else
    echo "Interfaz '$vlan_if' no existe, no se necesita limpieza."
  fi
}

cleanup_vlan "$LAN_IF.10"
cleanup_vlan "$LAN_IF.20"
echo "Limpieza completada."
echo ""

# --- [PASO 1] Configuración de las Interfaces de Red y VLANs ---
echo "[1/5] Configurando las interfaces de red y VLANs..."

# Levantar la interfaz física que va hacia el firewall
ip link set dev "$LAN_IF" up

# Crear y configurar la sub-interfaz para ISP1 (VLAN 10)
echo "Creando VLAN 10..."
ip link add link "$LAN_IF" name "$LAN_IF.10" type vlan id 10
ip addr add 192.168.100.1/24 brd + dev "$LAN_IF.10"
ip link set dev "$LAN_IF.10" up
echo "ISP1 (VLAN 10) configurado en $LAN_IF.10 con IP 192.168.100.1"

# Crear y configurar la sub-interfaz para ISP2 (VLAN 20)
echo "Creando VLAN 20..."
ip link add link "$LAN_IF" name "$LAN_IF.20" type vlan id 20
ip addr add 192.168.200.1/24 brd + dev "$LAN_IF.20"
ip link set dev "$LAN_IF.20" up
echo "ISP2 (VLAN 20) configurado en $LAN_IF.20 con IP 192.168.200.1"
echo ""

# --- [PASO 2] Habilitar el Reenvío de Paquetes (IP Forwarding) ---
echo "[2/5] Habilitando el reenvío de paquetes en el kernel..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null
echo "IP Forwarding habilitado."
echo ""

# --- [PASO 3] Configuración de NAT con iptables ---
echo "[3/5] Configurando NAT con iptables..."
# Limpiar reglas anteriores para evitar conflictos
iptables -t nat -F POSTROUTING

# Crear las nuevas reglas de NAT
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o "$WAN_IF" -j MASQUERADE
iptables -t nat -A POSTROUTING -s 192.168.200.0/24 -o "$WAN_IF" -j MASQUERADE
echo "Reglas de NAT creadas para ambas redes."
echo ""

# --- [PASO 4] Fin ---
echo "[4/5] ¡Configuración completada!"
echo "La máquina Ubuntu ahora está simulando dos ISPs en la interfaz $LAN_IF."