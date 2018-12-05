# Azure CLI lab cheat sheet (for Linux)

# Lab initialization
az group create -n vnetTest -l westeurope
az configure --defaults group=vnetTest
url='https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/NetworkingLab_master.json'
# Option 1: default (all vnets in one location)
az group deployment create -n netLabDeployment --template-uri $url -g vnetTest --parameters '{"adminPassword":{"value":"Microsoft123!"}}'
# Option 2: with Vnet 3 in a separate location
az group deployment create -n netLabDeployment --template-uri $url -g vnetTest --parameters '{"adminPassword":{"value":"Microsoft123!"}, "location2ary":{"value": "westus2"}, "location2aryVnets":{"value": [3]}}'

# Verify LB SKUs
az network lb list --query [].[name,sku.name] -o table

# Configure routing pointing to the ILB
next_hop='10.4.2.100'
az network route-table create --name vnet1-subnet1
az network vnet subnet update -n myVnet1Subnet1 --vnet-name myVnet1 --route-table vnet1-subnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet2
az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet1-subnet1

az network route-table create --name vnet2-subnet1
az network vnet subnet update -n myVnet2Subnet1 --vnet-name myVnet2 --route-table vnet2-subnet1
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet1

az network route-table create --name vnet3-subnet1 -l westus2
az network vnet subnet update -n myVnet3Subnet1 --vnet-name myVnet3 --route-table vnet3-subnet1
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet2
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet3
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet3

# Verify effective routing
az network nic show-effective-route-table -n myVnet3-vm1-nic
az network nic show-effective-route-table -n myVnet3-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'

# Configure ILB
az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int
az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int
az network lb address-pool list --lb-name linuxnva-slb-int -o table --query [].backendIpConfigurations[].id

# NSG (to bring one of the firewalls out of the ILB rotation)
az network nsg rule create --nsg-name linuxnva-1-nic0-nsg -n deny_all_in --priority 100 --access Deny --direction Inbound --protocol "*" --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*"
az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table
az network nsg rule delete -n deny_all_in --nsg-name linuxnva-1-nic0-nsg

# Configure ELB (outbound NAT)
az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic0 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic0 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
az network lb address-pool list --lb-name linuxnva-slb-ext -o table --query [].backendIpConfigurations[].id
az network nic update -n linuxnva-1-nic0 --network-security-group ""
az network nic show -n linuxnva-1-nic0 --query networkSecurityGroup
az network nic update -n linuxnva-2-nic0 --network-security-group ""
az network nic show -n linuxnva-2-nic0 --query networkSecurityGroup
az network nic update -n linuxnva-1-nic0 --network-security-group 'linuxnva-1-nic0-nsg'
az network nic update -n linuxnva-2-nic0 --network-security-group 'linuxnva-2-nic0-nsg'
az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table --include-default
az network nsg rule create --nsg-name linuxnva-1-nic0-nsg -n allow_vnet_internet --priority 110 --access Allow --direction Inbound --protocol "Tcp" --source-address-prefix "VirtualNetwork" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "80-80"

########
# VMSS #
########
vmss_url='https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json'
az group deployment create -n vmssDeployment -g vnetTest --template-uri $vmss_url --parameters '{"vmPwd":{"value":"Microsoft123!"}}'
az network lb outbound-rule create --lb-name linuxnva-vmss-slb-ext -n myoutboundnat --frontend-ip-configs myFrontendConfig --protocol All --idle-timeout 15 --outbound-ports 10000 --address-pool linuxnva-vmss-slbBackend-ext
az network route-table route update --route-table-name vnet1-subnet1 -n vnet1 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet1 -n vnet2 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2 -n vnet1 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance

# Verify LB
az network lb address-pool list --lb-name linuxnva-vmss-slb-int -o table --query [].backendIpConfigurations[].id
az network lb address-pool list --lb-name linuxnva-vmss-slb-ext -o table --query [].backendIpConfigurations[].id
az network lb rule list --lb-name linuxnva-vmss-slb-int -o table
az network lb outbound-rule list --lb-name linuxnva-vmss-slb-ext -o table

############
#    UDR   #
############

# Update to single NVA
next_hop=10.4.2.101
az network route-table route update --route-table-name vnet1-subnet1 -n vnet1-subnet1 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet1-subnet1 -n vnet2 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet1-subnet1 -n vnet3 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n default --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n vnet1 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n vnet3 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet3-subnet1 -n vnet1 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet3-subnet1 -n vnet2 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance

############
#   VPN    #
############
az network vnet-gateway create --name vnet4Gw --vnet myVnet4 --public-ip-addresses vnet4gwPip --sku VpnGw1 --asn 65504
az network vnet-gateway create --name vnet5Gw --vnet myVnet5 --public-ip-addresses vnet5gwPip --sku VpnGw1 --asn 65505

az network route-table route update --next-hop-ip-address 10.4.0.4 --route-table-name vnet1-subnet1 -n vnet2
az network route-table route update --next-hop-ip-address 10.4.0.4 --route-table-name vnet2-subnet1 -n vnet1

az network vpn-connection create -n 4to5 --vnet-gateway1 vnet4gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet5gw
az network vpn-connection create -n 5to4 --vnet-gateway1 vnet5gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet4gw

az network vnet peering update --vnet-name myVnet4 -g vnetTest --name LinkTomyVnet1 --set allowGatewayTransit=true
az network vnet peering update --vnet-name myVnet4 -g vnetTest --name LinkTomyVnet2 --set allowGatewayTransit=true
az network vnet peering update --vnet-name myVnet4 -g vnetTest --name LinkTomyVnet3 --set allowGatewayTransit=true
az network vnet peering update --vnet-name myVnet1 -g vnetTest --name LinkTomyVnet4 --set useRemoteGateways=true
az network vnet peering update --vnet-name myVnet2 -g vnetTest --name LinkTomyVnet4 --set useRemoteGateways=true
az network vnet peering update --vnet-name myVnet3 -g vnetTest --name LinkTomyVnet4 --set useRemoteGateways=true

############
# iptables #
############
sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o eth0 ! -s 10.0.0.0/255.0.0.0 -j MASQUERADE

#########
# OTHER #
#########

# Deploy standard ELB
lburl='https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/externalLB_standard.json'
az group deployment create -n elbDeploy -g vnetTest --template-uri $lburl
