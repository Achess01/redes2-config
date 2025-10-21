#!/bin/bash

# --- 1. CONFIGURACIÓN DE VARIABLES (Deben coincidir con conf-LB.sh) ---
ISP1_IFACE='wan70'
ISP2_IFACE='wan80'
CLIENT_IP_TEST1='192.168.60.10' # Cliente de prueba 1
CLIENT_IP_TEST2='192.168.60.11' # Cliente de prueba 2
GATEWAY_IP='192.168.60.3' # IP del Balanceador para clientes
RULES_FILE="LB_rules.conf"

echo "--- 1. CREANDO ARCHIVO DE REGLAS ESPECÍFICAS ($RULES_FILE) ---"
cat <<EOF > $RULES_FILE
# Formato: IP_ORIGEN, PUERTOS, PROTOCOLO, ISP_SALIDA
# Regla 1: Tráfico específico que DEBE IR a ISP2
$CLIENT_IP_TEST1, 53, UDP, ISP2
EOF
echo "Archivo $RULES_FILE creado con regla DNS (53/UDP) forzada a ISP2."

# --- 2. EJECUTANDO SCRIPT DE CONFIGURACIÓN PRINCIPAL ---
echo
echo "--- 2. EJECUTANDO conf-LB.sh PARA APLICAR REGLAS ---"
if [ -f "conf-LB.sh" ]; then
    sudo bash conf-LB.sh
    if [ $? -ne 0 ]; then
        echo "ERROR: Falló la ejecución de conf-LB.sh. Abortando pruebas."
        exit 1
    fi
else
    echo "ERROR: El script conf-LB.sh no se encontró en el directorio actual. Abortando."
    exit 1
fi

# --- 3. VERIFICACIÓN DE REGLAS IPTABLES ---
echo
echo "--- 3. VERIFICACIÓN DE REGLAS MANGLE/PREROUTING (BUSCAR MARCAS 100/200) ---"
echo "Las marcas 0x64 es ISP1 y 0xc8 es ISP2."
iptables -t mangle -L PREROUTING -n | grep -E 'MARK|CONNMARK|numIsp'

# --- 4. INSTRUCCIONES Y PLAN DE PRUEBAS DE TRÁFICO ---
echo
echo "--- 4. PLAN DE PRUEBAS DE TRÁFICO (CLIENTES -> $GATEWAY_IP) ---"
echo "Para verificar, ejecute el comando de tcpdump y luego los comandos de prueba en sus CLIENTES:"

echo "------------------------------------------------------------------"
echo "PASO 4.1: INICIE EL MONITOREO EN UNA TERMINAL SEPARADA (EN EL BALANCEADOR)"
echo "  sudo tcpdump -i $ISP1_IFACE or $ISP2_IFACE -n host $CLIENT_IP_TEST1 or host $CLIENT_IP_TEST2"
echo "------------------------------------------------------------------"

echo "PASO 4.2: EJECUTE LAS PRUEBAS EN LOS CLIENTES (Gateway: $GATEWAY_IP)"
echo "------------------------------------------------------------------"

# PRUEBA A: Regla específica (DNS 53/UDP)
echo "✅ PRUEBA A: Regla Específica (DNS 53/UDP de $CLIENT_IP_TEST1)"
echo "   COMANDO (Cliente $CLIENT_IP_TEST1): dig @8.8.8.8 google.com"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP2_IFACE' (Regla en LB_rules.conf)."
echo "------------------------------------------------------------------"

# PRUEBA B: Regla por defecto HTTP/HTTPS
echo " PRUEBA B: Regla por Defecto (HTTPS 443/TCP de $CLIENT_IP_TEST2)"
echo "   COMANDO (Cliente $CLIENT_IP_TEST2): curl -m 5 https://ejemplo.com"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP1_IFACE' (Regla por defecto: HTTP/S)."
echo "------------------------------------------------------------------"

# PRUEBA C: Regla por defecto Resto del tráfico (ISP2)
echo " PRUEBA C: Regla por Defecto (ICMP/Ping de $CLIENT_IP_TEST1)"
echo "   COMANDO (Cliente $CLIENT_IP_TEST1): ping -c 3 8.8.8.8"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP2_IFACE' (Regla por defecto: Resto del tráfico)."
echo "------------------------------------------------------------------"

echo "Script de test completado. Procede a ejecutar los comandos en los clientes y monitorear con tcpdump."
