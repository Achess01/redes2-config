#!/bin/bash
# Script de Test para Balanceo de Carga y PBR (test-LB.sh)

# --- 1. CONFIGURACIÓN DE VARIABLES (Deben coincidir con conf-LB.sh) ---
CLIENT_IFACE='enp2s0f0'
ISP1_IFACE='wan70'
ISP2_IFACE='wan80'

CLIENT_IP_TEST1='192.168.60.10' # Cliente de prueba 1
CLIENT_IP_TEST2='192.168.60.11' # Cliente de prueba 2
RULES_FILE="LB_rules.conf"

echo "--- 1. CREANDO ARCHIVO DE REGLAS DE PRUEBA ($RULES_FILE) ---"
cat <<EOF > $RULES_FILE
# Formato: IP_ORIGEN, PUERTOS, PROTOCOLO, ISP_SALIDA
# 1. Tráfico HTTP (80) desde un cliente específico a ISP1
$CLIENT_IP_TEST1, 80, TCP, ISP1

# 2. Tráfico HTTPS (443) desde otro cliente a ISP2
$CLIENT_IP_TEST2, 443, TCP, ISP2

# 3. Tráfico DNS (53) desde cualquier cliente a ISP1
192.168.60.0/24, 53, UDP, ISP1
EOF
echo "Archivo $RULES_FILE creado con éxito para los tests."

# --- 2. EJECUTANDO SCRIPT DE CONFIGURACIÓN PRINCIPAL ---
echo
echo "--- 2. EJECUTANDO conf-LB.sh PARA APLICAR REGLAS ---"
if [ -f "conf-LB.sh" ]; then
    bash conf-LB.sh
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
iptables -t mangle -L PREROUTING -n | grep -E 'MARK|CONNMARK|numIsp'
echo "Nota: Busque las marcas 0x64 (ISP1) y 0xc8 (ISP2)."

# --- 4. INSTRUCCIONES DE PRUEBA (TRÁFICO DE CLIENTE) ---
echo
echo "--- 4. PLAN DE PRUEBAS DE TRÁFICO ---"
echo "Para verificar el balanceo, ejecute los comandos de tcpdump y luego los comandos de prueba en sus CLIENTES:"

echo "------------------------------------------------------------------"
echo "PASO 4.1: INICIE EL MONITOREO EN UNA TERMINAL SEPARADA (EN EL BALANCEADOR)"
echo "  sudo tcpdump -i $ISP1_IFACE or $ISP2_IFACE -n host $CLIENT_IP_TEST1 or host $CLIENT_IP_TEST2"
echo "------------------------------------------------------------------"

echo "PASO 4.2: EJECUTE LAS PRUEBAS EN LOS CLIENTES (Gateway: 192.168.60.3)"
echo "------------------------------------------------------------------"
echo " PRUEBA 1 (HTTP/80 de $CLIENT_IP_TEST1):"
echo "   COMANDO (Cliente $CLIENT_IP_TEST1): curl -m 5 http://ejemplo.com"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP1_IFACE'."
echo "------------------------------------------------------------------"
echo "PRUEBA 2 (HTTPS/443 de $CLIENT_IP_TEST2):"
echo "   COMANDO (Cliente $CLIENT_IP_TEST2): curl -m 5 https://ejemplo.com"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP2_IFACE'."
echo "------------------------------------------------------------------"
echo " PRUEBA 3 (DNS/53 de cualquier cliente):"
echo "   COMANDO (Cliente $CLIENT_IP_TEST1): dig @8.8.8.8 google.com"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP1_IFACE'."
echo "------------------------------------------------------------------"
echo " PRUEBA 4 (ICMP/Ping - Regla por defecto):"
echo "   COMANDO (Cliente $CLIENT_IP_TEST1): ping -c 3 8.8.8.8"
echo "   RESULTADO ESPERADO (tcpdump): Tráfico de salida por la interfaz '$ISP2_IFACE' (Regla por defecto)."
echo "------------------------------------------------------------------"

# --- 5. PRUEBA DE FAILOVER (Rutina) ---
echo
echo "--- 5. VERIFICACIÓN DE FAILOVER RÁPIDA ---"
echo "Ruta por defecto actual:"
ip route show default
echo ""

