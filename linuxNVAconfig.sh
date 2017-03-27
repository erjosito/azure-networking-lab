
# Enable IP forwarding
sudo -i sysctl -w net.ipv4.ip_forward=1

# Enable eth1 and get an IP address
sudo ifconfig eth1 up
sudo dhclient

# Enable a listener on port 1138 (for the internal LB, verify with netstat -lntp)
while true; do nc -lk -p 1138; done &
# while true; do nc -lk -p 1138; done &    # We should know the IP for each NVA...

# Enable a listener on port 1139 (for the external LB, verify with netstat -lntp)
while true; do nc -lk -p 1139; done &


# Set up a better routing metric on eth1 (external, 10.4.3.0/24)
sudo apt-get install ifmetric -y
sudo ifmetric eth0 100
sudo ifmetric eth1 10

# configure static routes for the vnet space to eth0
sudo route add -net 10.0.0.0/13 gw 10.4.2.1 dev eth0
# and the Internet default to eth1 (just to be sure)
sudo route add -net 0.0.0.0/0 gw 10.4.3.1 dev eth1
# and just to be sure...
#sudo route add -host 168.63.129.16 gw 10.4.2.1 dev eth0

# Create a custom routing table for internal LB probes
sudo echo 200 slb >> /etc/iproute2/rt_tables   # permission denied!!!! (selinux??)
sudo ip rule add from 10.4.2.101 to 168.63.129.16 lookup slb
sudo ip route add 168.63.129.16 via 10.4.2.1 dev eth0 table slb

# Firewall config rules
# =====================

# Deny forwarded ICMP
sudo iptables -A FORWARD -p icmp -j DROP
# Allow forwarded traffic
sudo iptables -A FORWARD -i eth1 -j ACCEPT
sudo iptables -A FORWARD -o eth1 -j ACCEPT

# SNAT for traffic going to the vnets
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# SNAT for traffic going to the Internet
sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
