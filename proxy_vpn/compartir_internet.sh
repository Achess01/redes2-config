#!/bin/bash
# Script para configurar NAT y compartir internet
# Autor: Byron
# Fecha: $(date)

echo "-----------------------------------------"
echo " 🔧 Iniciando configuración de red..."
echo "-----------------------------------------"

# Habilitar reenvío de paquetes (IP Forwarding)
echo ""
echo "➡️  Habilitando reenvío de paquetes..."
sudo sysctl -w net.ipv4.ip_forward=1

echo "Verificando estado de IP Forward..."
estado=$(cat /proc/sys/net/ipv4/ip_forward)
echo "Resultado: net.ipv4.ip_forward = $estado"

# Eliminar ruta por defecto actual
echo ""
echo "➡️  Eliminando ruta por defecto actual..."
sudo ip route del default && echo "Ruta por defecto eliminada."

# Agregar nueva ruta por defecto
echo ""
echo "➡️  Agregando nueva ruta por defecto via 192.168.60.3..."
sudo ip route add default via 192.168.60.3 dev enx00e04c360835 && echo "Ruta por defecto configurada correctamente."

echo ""
echo "➡️  Configurando DNS (nameserver 8.8.8.8)..."
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null && echo "DNS configurado correctamente."


# Configurar NAT con iptables
echo ""
echo "➡️  Configurando NAT (masquerade)..."
sudo iptables -t nat -A POSTROUTING -o enx00e04c360835 -j MASQUERADE && echo "Regla NAT agregada correctamente."

echo ""
echo "-----------------------------------------"
echo " ✅ Internet compartido correctamente."
echo "-----------------------------------------"




