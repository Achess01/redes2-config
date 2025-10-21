#!/bin/bash

echo "****************************************************************"
echo "* INICIO DE CONFIGURACIÓN DEL BALANCEADOR DE CARGA Y QOS (TC) *"
echo "****************************************************************"

# echo -e "\n--- configurando interface enp2s0f0 ---"
# #Ejecutar script de configuracion para la interfas
bash interface.sh


# Solicitar ancho de banda para ISP1 (wan70)
echo -e "\n--- Ancho de Banda para ISP1 (wan70) ---"
read -p "Ingrese el máximo de ancho de banda UP (upload) en Mbps para ISP1: " BWU_ISP1
read -p "Ingrese el máximo de ancho de banda DW (download) en Mbps para ISP1: " BWD_ISP1

# Solicitar ancho de banda para ISP2 (wan80)
echo -e "\n--- Ancho de Banda para ISP2 (wan80) ---"
read -p "Ingrese el máximo de ancho de banda UP (upload) en Mbps para ISP2: " BWU_ISP2
read -p "Ingrese el máximo de ancho de banda DW (download) en Mbps para ISP2: " BWD_ISP2


# --- 2. EJECUCIÓN DE SCRIPTS DE TC (QoS) ---
echo -e "\n--- 2.1. Configurando QoS para ISP1 (wan70) con ${BWU_ISP1}Mb UP / ${BWD_ISP1}Mb DW ---"
# Ejecuta conf-isp1.sh y le pasa las variables de ancho de banda para ISP1
echo "$BWU_ISP1
$BWD_ISP1" | bash conf-isp1.sh

echo -e "\n--- 2.2. Configurando QoS para ISP2 (wan80) con ${BWU_ISP2}Mb UP / ${BWD_ISP2}Mb DW ---"
# Ejecuta conf-isp2.sh y le pasa las variables de ancho de banda para ISP2
echo "$BWU_ISP2
$BWD_ISP2" | bash conf-isp2.sh

# Verifica si los scripts de TC terminaron sin errores graves (código de salida 0)
if [ $? -ne 0 ]; then
    echo "ERROR: Uno o ambos scripts de TC fallaron. Deteniendo la configuración."
    exit 1
fi

# --- 3. EJECUCIÓN DEL SCRIPT DE BALANCEO DE CARGA Y FAILOVER ---
echo -e "\n--- 3. Configurando Balanceo de Carga (PBR) y NAT ---"
bash conf-LB.sh

if [ $? -ne 0 ]; then
    echo "ERROR: El script de Balanceo de Carga falló. Deteniendo la configuración."
    exit 1
fi

echo -e "\n****************************************************************"
echo "* CONFIGURACIÓN COMPLETA. INICIANDO PRUEBAS DE SERVICIO.    *"
echo "****************************************************************"

# --- 4. PRUEBAS DE VERIFICACIÓN ---
INTERFACE_ISP1='wan70'
INTERFACE_ISP2='wan80'
GW_ISP1='192.168.70.1'
GW_ISP2='192.168.80.1'

# 4.1. Verificación de Tablas de Enrutamiento
echo -e "\n--- 4.1. Verificando Rutas de Enrutamiento Personalizadas ---"
echo "Rutas para ISP1 (tabla isp1, métrica 10):"
ip route show table isp1 | grep default
echo "Rutas para ISP2 (tabla isp2, métrica 20):"
ip route show table isp2 | grep default

# 4.2. Prueba de Conectividad a Gateways
echo -e "\n--- 4.2. Prueba de Conectividad a Gateways ---"
ping -c 3 $GW_ISP1
ping -c 3 $GW_ISP2
echo "Si ambos pings son exitosos, ambos ISP están UP."

# 4.3. Prueba de Failover (Simulado)
echo -e "\n--- 4.3. Prueba de Failover (Simulada - Basada en la métrica por defecto) ---"
echo "La ruta por defecto actual (principal) debería ser ISP1 (métrica 10):"
ip route show default
# Ejecuta la función de chequeo de failover de conf-LB.sh (debería reafirmar ISP1 si ambos están UP)
echo -e "\nRe-ejecutando la lógica de Failover (check_failover):"
# Se ejecuta el script conf-LB.sh nuevamente para forzar la función check_failover
bash conf-LB.sh | grep 'ISP'
ip route show default
echo "NOTA: Si se desea probar el failover de verdad, el GW_ISP1 debe ser inaccesible y re-ejecutar el script conf-LB.sh"

# 4.4. Prueba de Tráfico Marcado (Comprobación de reglas IPTABLES)
numIsp1='100' # Usar la variable de conf-LB.sh o definirla aquí para el mensaje
numIsp2='200'
echo -e "\n--- 4.4. Prueba de Reglas de Balanceo de Carga (IPTABLES - mangle) ---"
echo "Debería haber reglas marcando HTTP/HTTPS (dports 80,443) con mark $numIsp1 (100) y el resto con mark $numIsp2 (200)."
echo "Contador de paquetes en las reglas de marcado:"
iptables -t mangle -v -n -L PREROUTING | grep "MARK set"

# 4.5. Verificación de configuración TC/QoS
echo -e "\n--- 4.5. Verificación de Árbol de Traffic Control (QoS) ---"
echo "Qdisc en $INTERFACE_ISP1 (Upload):"
tc qdisc show dev $INTERFACE_ISP1 | grep 'htb'
echo "Qdisc en ifb0 (Download):"
tc qdisc show dev ifb0 | grep 'htb'
echo "Clase en $INTERFACE_ISP1 (Upload - ${BWU_ISP1} Mbps):"
tc class show dev $INTERFACE_ISP1 | grep '1:10'
echo "Clase en ifb0 (Download - ${BWD_ISP1} Mbps):"
tc class show dev ifb0 | grep '1:10'


echo -e "\n****************************************************************"
echo "* FIN DE PRUEBAS.                             *"
echo "****************************************************************"
echo "Revisa los contadores de las reglas IPTABLES (4.4) después de generar tráfico (web y otro) para confirmar el balanceo."

# echo -e "\n--- 5. Ejecutando script de failover (check_failover.sh) ---"

# # Ejecuta el script check_failover.sh.
bash check_failover.sh
