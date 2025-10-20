#!/bin/bash
# Script de Monitoreo Continuo para Failover

# --- VARIABLES ESENCIALES COPIADAS DE conf-LB.sh ---
interfaceISP1='wan70'
interfaceISP2='wan80'
GW_ISP1='192.168.70.1'
GW_ISP2='192.168.80.1'

# --- FUNCIÓN DE FAILOVER COPIADA DE conf-LB.sh ---
check_failover() {
    ping -c 3 -W 2 $GW_ISP1 > /dev/null
    ISP1_STATUS=$? 
    ping -c 3 -W 2 $GW_ISP2 > /dev/null
    ISP2_STATUS=$?

    if [ $ISP1_STATUS -eq 0 ] && [ $ISP2_STATUS -ne 0 ]; then
        # ISP1 UP, ISP2 DOWN: Usar ISP1
        ip route replace default via $GW_ISP1 dev $interfaceISP1 metric 10
        echo "$(date): ISP1 UP, ISP2 DOWN. Tráfico por ISP1."
    elif [ $ISP1_STATUS -ne 0 ] && [ $ISP2_STATUS -eq 0 ]; then
        # ISP1 DOWN, ISP2 UP: Failover a ISP2
        ip route replace default via $GW_ISP2 dev $interfaceISP2 metric 10
        echo "$(date): ISP1 DOWN, ISP2 UP. Tráfico por ISP2 (FAILOVER)."
    elif [ $ISP1_STATUS -eq 0 ] && [ $ISP2_STATUS -eq 0 ]; then
        # Ambos UP: Usar ISP1 (Primary - Metric 10)
        ip route replace default via $GW_ISP1 dev $interfaceISP1 metric 10
        echo "$(date): Ambos ISP UP. Balanceo de carga activo."
    else
        echo "$(date): ¡Ambos ISP DOWN! No hay conexión a Internet."
    fi
}

# --- BUCLE CONTINUO ---
echo "Iniciando monitoreo continuo de Failover..."
while true; do
    check_failover
    sleep 3  # Espera 5 segundos antes de volver a chequear
done