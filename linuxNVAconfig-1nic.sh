# These actions will be run at provisioning time
# Most of these commands are ephemeral, so you will probably have to rerun them if you reboot the VM

# Enable IP forwarding
sudo -i sysctl -w net.ipv4.ip_forward=1

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


###########################
#  Firewall config rules  #
###########################

# Allow incoming and outgoing traffic (TCP)
sudo iptables -A INPUT -p tcp -j ACCEPT
sudo iptables -A OUTPUT -p tcp -j ACCEPT
# Deny forwarded ICMP
sudo iptables -A FORWARD -p icmp -j DROP
# Allow forwarded traffic
sudo iptables -A FORWARD -j ACCEPT
# SNAT for all traffic
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
