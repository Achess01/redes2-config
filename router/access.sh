#!/bin/bash

OUT_IF="enx00e04c3601b7"
IP_FILE="/etc/speedwagon/access.ip"
MAC_FILE="/etc/speedwagon/access.mac"

echo "Limpieza de cadenas"
iptables -F INTERNET_IP 2>/dev/null
iptables -F INTERNET_MAC 2>/dev/null
iptables -X INTERNET_IP 2>/dev/null
iptables -X INTERNET_MAC 2>/dev/null

echo "Creando cadenas"
iptables -N INTERNET_IP
iptables -N INTERNET_MAC

# APLICANDO REGLAS PARA IPs
if [ -f "$IP_FILE" ]; then
	while read -r ip; do
		[[ $ip =~ ^# ]] || [[ -z $ip ]] && continue
		iptables -A INTERNET_IP -s "$ip" -j ACCEPT
	done < "$IP_FILE"
else
	echo "No se encontro el archivo $IP_FILE"
fi

# APLICANDO REGLAS PARA MACs
if [ -f "$MAC_FILE" ]; then
	while read -r mac; do
		[[ $mac =~ ^# ]] || [[ -z $mac ]] && continue
		iptables -A INTERNET_MAC -m mac --mac-source "$mac" -j ACCEPT
	done < "$MAC_FILE"
else
	echo "No se encontro el archivo $MAC_FILE"
fi

# INSERTAR LA CADENA INTERNET_MAC
iptables -I FORWARD 1 -o "$OUT_IF" -j INTERNET_MAC

# INSERTAR LA CADENA INTERNET_IP
iptables -I FORWARD 2 -o "$OUT_IF" -j INTERNET_IP

# REGLA PARA DENEGAR TODO LO QUE NO FUE PERMITIDO ARRIBA
iptables -A FORWARD -o "$OUT_IF" -j DROP

echo "Configuracion completada"
