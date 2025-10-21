# ACCEPT ALL
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# FLUSH RULES
sudo iptables -F

# DELETE CUSTOM RULES (INTERNET_IP, INTERNET_MAC)
sudo iptables -X

# DELETE REMAINNING RULES
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X


