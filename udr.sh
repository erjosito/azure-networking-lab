# Variables
inetIp=188.113.88.193
defGw=10.4.2.100
rg=vnetTest

# Set default resource group
az configure --defaults group=$rg

# Create route tables
az network route-table create --name vnet1-subnet1
az network route-table create --name vnet2-subnet1
az network route-table create --name vnet3-subnet1
az network route-table create --name vnet4-gw

# Create routes in vnet1
az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n subnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet2
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet3
az network route-table route create --address-prefix 10.5.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet5
az network route-table route create --address-prefix $inetIp/32 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n ifconfig

# Create routes in vnet2
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet1
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet3
az network route-table route create --address-prefix 10.5.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet5
az network route-table route create --address-prefix $inetIp/32 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n ifconfig

# Create routes in vnet3
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet2
az network route-table route create --address-prefix 10.5.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet5
az network route-table route create --address-prefix $inetIp/32 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n ifconfig

# Create routes in vnet4
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet4-gw -n vnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet4-gw -n vnet2
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address $defGw --next-hop-type VirtualAppliance --route-table-name vnet4-gw -n vnet3

# Associate route tables to subnets
az network vnet subnet update -n myVnet1Subnet1 --vnet-name myVnet1 --route-table vnet1-subnet1
az network vnet subnet update -n myVnet2Subnet1 --vnet-name myVnet2 --route-table vnet2-subnet1
az network vnet subnet update -n myVnet3Subnet1 --vnet-name myVnet3 --route-table vnet3-subnet1
az network vnet subnet update -n GatewaySubnet --vnet-name myVnet4 --route-table vnet4-gw
