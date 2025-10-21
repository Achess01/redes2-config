#!/bin/bash

# --- VARIABLES DE INTERFAZ Y RED (ACTUALIZADAS) ---
interfaceCliente='enp2s0f0'  # INTERFAZ CLIENTE
interfaceISP1='wan70' # Sub-interfaz VLAN 70 para ISP1
interfaceISP2='wan80' # Sub-interfaz VLAN 80 para ISP2

# Direcciones y Gateways
IP_LB_ISP1='192.168.70.3'
GW_ISP1='192.168.70.1'
RED_ISP1='192.168.70.0/24'

IP_LB_ISP2='192.168.80.3'
GW_ISP2='192.168.80.1'
RED_ISP2='192.168.80.0/24'

# IP de la interfaz del cliente (ACTUALIZADA A 192.168.60.3)
IP_CLIENTE='192.168.60.3'
RED_CLIENTE='192.168.60.0/24'

numIsp1='100'
numIsp2='200'

RULES_FILE="LB_rules.conf"
ZABBIX_SERVER_IP="192.168.30.10"

# --- 1. PREPARACIÓN Y CONFIGURACIÓN BÁSICA ---
echo "Configurando reenvío IP (IP Forwarding)..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Limpiar configuraciones previas
echo "Limpiando configuraciones de PBR y NAT previas..."
iptables -t mangle -F PREROUTING
iptables -t nat -F POSTROUTING
ip route flush table isp1
ip route flush table isp2
ip rule del fwmark 100 table isp1 2>/dev/null
ip rule del fwmark 200 table isp2 2>/dev/null
ip route del default 2>/dev/null

# --- 2. CONFIGURACIÓN DE LA INTERFAZ CLIENTE ---
echo "Configurando interfaz del cliente: $interfaceCliente con IP $IP_CLIENTE"
# Asegurar que la interfaz esté activa
ip link set dev $interfaceCliente up
# Configurar IP del cliente
ip addr add $IP_CLIENTE/24 dev $interfaceCliente 2>/dev/null

# --- 3. ENRUTAMIENTO BASADO EN POLÍTICAS (PBR) ---
echo "Configurando tablas de enrutamiento personalizadas (PBR)..."

# Rutas y reglas para ISP1
ip route add default via $GW_ISP1 dev $interfaceISP1 metric 10 table isp1
ip rule add from $IP_LB_ISP1 table isp1 prio 1000

# Rutas y reglas para ISP2
ip route add default via $GW_ISP2 dev $interfaceISP2 metric 20 table isp2
ip rule add from $IP_LB_ISP2 table isp2 prio 2000

# Reglas para tráfico marcado
ip rule add fwmark $numIsp1 table isp1 prio 33000
ip rule add fwmark $numIsp2 table isp2 prio 33000

# Ruta por defecto en tabla principal
ip route add default via $GW_ISP1 metric 10

# --- 4. FAILOVER ACTIVO ---
check_failover() {
    ping -c 3 -W 2 $GW_ISP1 > /dev/null
    ISP1_STATUS=$? 
    ping -c 3 -W 2 $GW_ISP2 > /dev/null
    ISP2_STATUS=$?

    if [ $ISP1_STATUS -eq 0 ] && [ $ISP2_STATUS -ne 0 ]; then
        ip route replace default via $GW_ISP1 dev $interfaceISP1 metric 10
        echo "$(date): ISP1 UP, ISP2 DOWN. Tráfico por ISP1."
    elif [ $ISP1_STATUS -ne 0 ] && [ $ISP2_STATUS -eq 0 ]; then
        ip route replace default via $GW_ISP2 dev $interfaceISP2 metric 10
        echo "$(date): ISP1 DOWN, ISP2 UP. Tráfico por ISP2 (FAILOVER)."
    elif [ $ISP1_STATUS -eq 0 ] && [ $ISP2_STATUS -eq 0 ]; then
        ip route replace default via $GW_ISP1 dev $interfaceISP1 metric 10
        echo "$(date): Ambos ISP UP. Balanceo de carga activo."
    else
        echo "$(date): ¡Ambos ISP DOWN! No hay conexión a Internet."
    fi
}

check_failover

# --- 5. IPTABLES (LOAD BALANCING) ---
# 5.1. Persistencia de Conexión
iptables -t mangle -A PREROUTING -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -m mark ! --mark 0 -j ACCEPT

# 5.2. Aplicar reglas solo al tráfico de la interfaz del cliente
echo "Aplicando reglas de balanceo para interfaz $interfaceCliente..."

if [ -f "$RULES_FILE" ]; then
    grep -vE '^(#|$)' "$RULES_FILE" | while IFS=, read -r IP_ORIGEN PUERTOS PROTOCOLO ISP_SALIDA; do
        IP_ORIGEN=$(echo $IP_ORIGEN | xargs); PUERTOS=$(echo $PUERTOS | tr -d '[]' | tr ',' ' ')
        PROTOCOLO=$(echo $PROTOCOLO | xargs | tr '[:upper:]' '[:lower:]')
        ISP_SALIDA=$(echo $ISP_SALIDA | xargs)

        if [ "$ISP_SALIDA" == "ISP1" ]; then MARK_VAL=$numIsp1; else MARK_VAL=$numIsp2; fi

        echo "-> Regla: $IP_ORIGEN - $PUERTOS/$PROTOCOLO -> $ISP_SALIDA"
        iptables -t mangle -A PREROUTING -i $interfaceCliente -s $IP_ORIGEN -p $PROTOCOLO -m multiport --dports $PUERTOS -j MARK --set-mark $MARK_VAL
    done
else
    echo "Advertencia: Archivo $RULES_FILE no encontrado. Se omiten reglas específicas."
fi

# 5.3. Reglas por defecto (solo para tráfico del cliente)
echo "-> Regla por defecto: HTTP/HTTPS (80, 443) -> ISP1"
iptables -t mangle -A PREROUTING -i $interfaceCliente -p tcp -m multiport --dports 80,443 -j MARK --set-mark $numIsp1
echo "-> Regla por defecto: Resto del tráfico -> ISP2"
iptables -t mangle -A PREROUTING -i $interfaceCliente -j MARK --set-mark $numIsp2

# 5.4. Persistencia final
iptables -t mangle -A PREROUTING -j CONNMARK --save-mark

# 5.5. NAT para el tráfico del cliente
echo "Configurando NAT para tráfico del cliente..."
iptables -t nat -A POSTROUTING -o $interfaceISP1 -s $RED_CLIENTE -j MASQUERADE
iptables -t nat -A POSTROUTING -o $interfaceISP2 -s $RED_CLIENTE -j MASQUERADE

# --- 6. CONFIGURACIÓN ADICIONAL PARA EL CLIENTE ---
# Habilitar forwarding para la red del cliente
iptables -A FORWARD -i $interfaceCliente -j ACCEPT
iptables -A FORWARD -o $interfaceCliente -j ACCEPT

echo "Configuración del Balanceador de Carga completada."
echo "Interfaz cliente: $interfaceCliente"
echo "IP del balanceador para clientes: $IP_CLIENTE"
echo "Los clientes deben usar $IP_CLIENTE como gateway por defecto"
