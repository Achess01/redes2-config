#!/bin/bash

echo "Activando IP forwarding"

# Agregar la configuración al archivo sysctl.conf
echo "net.ipv4.ip_forward=1" > /etc/sysctl.conf

# Aplicar los cambios inmediatamente
sysctl -p

# Verificar que se activó correctamente
echo "Verificación:"
echo "en sysctl: $(sysctl net.ipv4.ip_forward)"
echo "en /proc/sys/net/ipv4/ip_forward: $(cat /proc/sys/net/ipv4/ip_forward)"
