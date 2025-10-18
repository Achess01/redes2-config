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

  # Load the necessary module for bridge firewalling
  echo "[+] Loading br_netfilter module..."
  modprobe br_netfilter

  # This allows iptables to see traffic that flows across the bridge
  sysctl -w net.bridge.bridge-nf-call-iptables=1
  sysctl -w net.ipv4.ip_forward=1 # Still needed for filtering rules
}

# File containing ingress rules
RULES_FILE="ingress.rules"

# Function to apply firewall rules
apply_rules() {
  echo "[+] Applying firewall rules from ${RULES_FILE}..."

  # Flush existing rules from the FORWARD chain
  iptables -F FORWARD

  # Set the default policy to DROP. This is crucial for security.
  # Any traffic not explicitly allowed by a rule will be blocked.
  iptables -P FORWARD DROP

  # Allow established connections to return (important for TCP)
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

  # TODO: Remove this (for testing only)
  iptables -A FORWARD -i $WAN_IF -o $LAN_IF -j ACCEPT
  iptables -A FORWARD -i $LAN_IF -o $WAN_IF -j ACCEPT

  # Check if the rules file exists
  if [ ! -f "$RULES_FILE" ]; then
    echo "[!] Warning: Rules file '${RULES_FILE}' not found. All traffic will be blocked."
    return
  fi

  # Read the rules file line by line, skipping comments
  grep -v "^#" "$RULES_FILE" | while IFS=',' read -r origen destino puertos protocolo; do
    # Clean up whitespace
    origen=$(echo "$origen" | xargs)
    destino=$(echo "$destino" | xargs)
    puertos=$(echo "$puertos" | tr -d '[]' | xargs) # Remove brackets
    protocolo=$(echo "$protocolo" | xargs)

    if [ -z "$origen" ] || [ -z "$destino" ] || [ -z "$puertos" ] || [ -z "$protocolo" ]; then
        echo "[-] Skipping invalid rule line."
        continue
    fi

    echo "[+] Adding rule: From ${origen} To ${destino} Ports ${puertos} Proto ${protocolo}"

    # Construct and execute the iptables command
    iptables -A FORWARD -i $WAN_IF -o $LAN_IF \
             -p "$protocolo" \
             -s "$origen" \
             -d "$destino" \
             -m multiport --dports "$puertos" \
             -j ACCEPT
  done

  echo "[+] All ingress rules applied. Firewall is active."
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