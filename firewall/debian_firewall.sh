#!/bin/bash

# Interfaces
WAN_IF="enp1s0"         # Interface connected to ISP simulator
LAN_IF="enx00e04c3603ba" # Interface connected to Load Balancer
BRIDGE_IF="br0"

# Function to set up the transparent bridge
setup_bridge() {
  echo "[+] Creating bridge ${BRIDGE_IF}..."

  # Create the bridge interface
  ip link add name $BRIDGE_IF type bridge

  # Clear any existing IPs from physical interfaces
  ip addr flush dev $WAN_IF
  ip addr flush dev $LAN_IF

  # Add physical interfaces to the bridge
  ip link set dev $WAN_IF master $BRIDGE_IF
  ip link set dev $LAN_IF master $BRIDGE_IF

  # Bring up all interfaces
  ip link set dev $WAN_IF up
  ip link set dev $LAN_IF up
  ip link set dev $BRIDGE_IF up

  echo "[+] Enabling kernel settings for bridged traffic filtering..."
  # This allows iptables to see traffic that flows across the bridge
  sysctl -w net.bridge.bridge-nf-call-iptables=1
  sysctl -w net.ipv4.ip_forward=1 # Still needed for filtering rules
}

# Function to apply firewall rules
apply_rules() {
  echo "[+] Applying firewall rules..."

  # Flush existing rules
  iptables -F FORWARD

  # Set default policy to DROP (secure default)
  iptables -P FORWARD DROP

  # --- YOUR INGRESS/EGRESS RULES GO HERE ---
  # Example: Allow all traffic to pass for now for testing
  # In production, you would add specific rules per the project PDF [cite: 116]
  iptables -A FORWARD -i $WAN_IF -o $LAN_IF -j ACCEPT
  iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT
  
  echo "[+] Rules applied. Firewall is active."
}

# Function to clean up the configuration
cleanup() {
  echo "[+] Cleaning up bridge configuration..."
  
  ip link set dev $BRIDGE_IF down
  ip link del dev $BRIDGE_IF

  # Restore interfaces if needed (or just reboot)
  echo "[+] Cleanup complete."
}

# ====== MENU ======
case "$1" in
  start)
    setup_bridge
    apply_rules
    ;;
  stop)
    cleanup
    ;;
  *)
    echo "Uso: $0 {start|stop}"
    ;;
esac