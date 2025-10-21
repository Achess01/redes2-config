#!/bin/bash

echo "=========================================="
echo "  CONFIGURACIÓN COMPLETA DE FILTRADO"
echo "  Proxy y Cliente VPN"
echo "  Speedwagon Foundation"
echo "=========================================="
echo ""

# === VARIABLES ===
IFACE_DESDE_R1="enx00e04c360207"        # Puerto donde RECIBO peticiones de Router R1
IFACE_HACIA_BAL="enx00e04c360835"       # Puerto donde ENVÍO hacia Balanceador (tengo Internet)

echo "Interfaces configuradas:"
echo "  Desde Router R1:      $IFACE_DESDE_R1 (192.168.50.1)"
echo "  Hacia Balanceador:    $IFACE_HACIA_BAL (192.168.60.2)"
echo ""

# === PASO 1: LIMPIAR REGLAS ANTERIORES ===
echo "[1/6] Limpiando reglas de firewall anteriores..."
iptables -F
iptables -t nat -F
iptables -X 2>/dev/null
iptables -t nat -X 2>/dev/null
echo "      ✓ Reglas limpiadas"

# === PASO 2: POLÍTICAS POR DEFECTO ===
echo "[2/6] Configurando políticas por defecto..."
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "      ✓ Políticas configuradas (permisivas)"

# === PASO 3: PROXY TRANSPARENTE HTTP ===
echo "[3/6] Configurando proxy transparente para HTTP (puerto 80)..."
# Redirigir tráfico HTTP que viene de R1 hacia Squid
iptables -t nat -A PREROUTING -i $IFACE_DESDE_R1 -p tcp --dport 80 -j REDIRECT --to-port 3128
echo "      ✓ HTTP redirigido a Squid (puerto 3128)"

# === PASO 4: BLOQUEO HTTPS CON STRING MATCHING ===
echo "[4/6] Configurando bloqueo de HTTPS (puerto 443)..."

# Crear cadena personalizada para bloqueos
iptables -N BLOQUEO_HTTPS 2>/dev/null

# === REDES SOCIALES ===
echo "      → Bloqueando redes sociales..."

# Facebook
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "facebook.com" --algo bm -j LOG --log-prefix "BLOCKED_FB: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "facebook.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "fbcdn.net" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "facebook.net" --algo bm -j REJECT --reject-with tcp-reset

# Instagram
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "instagram.com" --algo bm -j LOG --log-prefix "BLOCKED_IG: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "instagram.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "cdninstagram" --algo bm -j REJECT --reject-with tcp-reset

# Twitter/X
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "twitter.com" --algo bm -j LOG --log-prefix "BLOCKED_TW: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "twitter.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "twimg.com" --algo bm -j REJECT --reject-with tcp-reset

# X.com
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "x.com" --algo bm -j LOG --log-prefix "BLOCKED_X: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "x.com" --algo bm -j REJECT --reject-with tcp-reset

# TikTok
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "tiktok.com" --algo bm -j LOG --log-prefix "BLOCKED_TT: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "tiktok.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "tiktokcdn" --algo bm -j REJECT --reject-with tcp-reset

# Snapchat
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "snapchat.com" --algo bm -j LOG --log-prefix "BLOCKED_SC: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "snapchat.com" --algo bm -j REJECT --reject-with tcp-reset

# LinkedIn
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "linkedin.com" --algo bm -j LOG --log-prefix "BLOCKED_LI: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "linkedin.com" --algo bm -j REJECT --reject-with tcp-reset

# === PORNOGRAFÍA ===
echo "      → Bloqueando sitios pornográficos..."

iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "pornhub.com" --algo bm -j LOG --log-prefix "BLOCKED_PORN: " --log-level 4
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "pornhub.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "xvideos.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "xnxx.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "redtube.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "youporn.com" --algo bm -j REJECT --reject-with tcp-reset
iptables -A BLOQUEO_HTTPS -p tcp --dport 443 -m string --string "xhamster.com" --algo bm -j REJECT --reject-with tcp-reset

# Aplicar la cadena de bloqueo al tráfico que viene de R1
iptables -I FORWARD -i $IFACE_DESDE_R1 -j BLOQUEO_HTTPS
echo "      ✓ HTTPS bloqueado para sitios no permitidos"

# === PASO 5: FORWARDING (Pasar tráfico permitido) ===
echo "[5/6] Configurando forwarding de tráfico permitido..."
# Permitir tráfico de R1 hacia Balanceador (salida a Internet)
iptables -A FORWARD -i $IFACE_DESDE_R1 -o $IFACE_HACIA_BAL -j ACCEPT
# Permitir respuestas de Balanceador hacia R1 (tráfico establecido)
iptables -A FORWARD -i $IFACE_HACIA_BAL -o $IFACE_DESDE_R1 -m state --state ESTABLISHED,RELATED -j ACCEPT
echo "      ✓ Forwarding configurado"

# === PASO 6: GUARDAR CONFIGURACIÓN ===
echo "[6/6] Guardando reglas de firewall..."
iptables-save > /etc/iptables/rules.v4
echo "      ✓ Reglas guardadas en /etc/iptables/rules.v4"

# === RESUMEN ===
echo ""
echo "=========================================="
echo "  ✅ CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
echo "=========================================="
echo ""
echo "📊 RESUMEN:"
echo "  • Proxy transparente HTTP:  ACTIVO (Squid puerto 3128)"
echo "  • Bloqueo HTTPS:            ACTIVO (iptables string matching)"
echo "  • IP Forwarding:            $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "🚫 BLOQUEADOS:"
echo "  • Redes sociales: Facebook, Instagram, Twitter/X, TikTok, Snapchat, LinkedIn"
echo "  • Pornografía: Pornhub, Xvideos, Xnxx, Redtube, Youporn, etc."
echo ""
echo "✅ PERMITIDOS:"
echo "  • Sitios .gob.gt (gubernamentales Guatemala)"
echo "  • Bancos de Guatemala"
echo "  • Resto de Internet"
echo ""
echo "📝 LOGS DE BLOQUEOS:"
echo "  sudo tail -f /var/log/kern.log | grep BLOCKED"
echo "  sudo dmesg -w | grep BLOCKED"
echo ""
echo "🔍 VERIFICAR REGLAS:"
echo "  sudo iptables -L BLOQUEO_HTTPS -n -v"
echo "  sudo iptables -t nat -L -n -v"
echo ""
echo "=========================================="
