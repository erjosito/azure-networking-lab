# These actions will be run at provisioning time
# Most of these commands are ephemeral, so you will probably have to rerun them if you reboot the VM

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

# Install Apache and PHP
sudo apt-get update
sudo apt-get install apache2 -y
sudo apt-get install php libapache2-mod-php php-mcrypt php-mysql -y
sudo systemctl restart apache2

# Delete default web site and download a new one
sudo rm /var/www/html/index.html
sudo apt-get install wget -you
sudo wget https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/index.php -P /var/www/html/

#############
#  Routing  #
#############

# Set up a better routing metric on eth1 (external, 10.4.3.0/24)
sudo apt-get install ifmetric -y
sudo ifmetric eth0 100
sudo ifmetric eth1 10

# configure static routes for the vnet space to eth0
sudo route add -net 10.0.0.0/13 gw 10.4.2.1 dev eth0
# and the Internet default to eth1 (just to be sure)
sudo route add -net 0.0.0.0/0 gw 10.4.3.1 dev eth0
# route for internal LB to work properly (will break ext LB unless PBR is configured, see next lines)
# sudo route add -host 168.63.129.16 gw 10.4.2.1 dev eth0

# Get IP addresses
ipaddint=`ip a | grep 10.4.2 | awk '{print $2}' | awk -F '/' '{print $1}'`   # either 10.4.2.101 or .102
ipaddext=`ip a | grep 10.4.3 | awk '{print $2}' | awk -F '/' '{print $1}'`   # either 10.4.3.101 or .102

# Create a custom routing table for internal LB probes
#sudo sed -i '$a201 slbint' /etc/iproute2/rt_tables # an easier echo command would be denied by selinux
#sudo ip rule add from $ipaddint to 168.63.129.16 lookup slbint  # Note that this depends on the nva number!
#sudo ip route add 168.63.129.16 via 10.4.2.1 dev eth0 table slbint

# Create a custom routing table for external LB probes
#sudo sed -i '$a202 slbext' /etc/iproute2/rt_tables # an easier echo command would be denied by selinux
#sudo ip rule add from $ipaddext to 168.63.129.16 lookup slbext
#sudo ip route add 168.63.129.16 via 10.4.3.1 dev eth1 table slbext

###########################
#  Firewall config rules  #
###########################

# Deny forwarded ICMP
sudo iptables -A FORWARD -p icmp -j DROP
# Deny specific IP address (ifconfig.co, but the IP address keeps changing anyway)
#sudo iptables -A FORWARD -d 188.113.88.193 -j DROP

# Allow forwarded outgoing traffic (port 80)
# sudo iptables -A FORWARD -i eth0 -o eth0 -p tcp --dport 80 -j ACCEPT 
# sudo iptables -A FORWARD -i eth0 -o eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 

# Allow SSH traffic on eth0
sudo iptables -A FORWARD -i eth0 -p tcp --dport ssh -j ACCEPT 
sudo iptables -A FORWARD -i eth0 -p tcp --dport 80 -j ACCEPT 
sudo iptables -A FORWARD -i eth0 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 

# Allow forwarded traffic on eth1
#sudo iptables -A FORWARD -i eth1 -j ACCEPT
#sudo iptables -A FORWARD -o eth1 -j ACCEPT

# Default deny
sudo iptables -A FORWARD -j DROP


# SNAT for traffic going to the vnets
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# SNAT for traffic going to the Internet
sudo iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

