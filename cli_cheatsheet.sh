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
az network route-table route create --address-prefix 0.0.0.0/0 --next-hop-ip-address $next_hop --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n default

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

# Additional tests (not in the lab guide)
# Delete/Recreate outbound NAT rule in the ELB
# You can use this to attach an ELB to a second NIC of an NVA
az network lb outbound-rule delete -g vnetTest --lb-name linuxnva-slb-ext -n myrule
az network lb rule create -g vnetTest --lb-name linxnva-slb-ext -n mylbrule --frontend-ip-name myFrontendConfig --backend-pool-name linuxnva-slbBackend-ext --protocol All --frontend-port 0 --backend-port 0
# Create PIP/frontend/LB-rule in the external LB, and allow Internet SSH
az network public-ip create -g vnetTest -n linuxnva-slbPip-ext2 --sku Standard --allocation-method Static
az network lb frontend-ip create -g vnetTest -n myFrontendConfig2 --lb-name linuxnva-slb-ext --public-ip-addres linuxnva-slbPip-ext2
az network lb rule create -g vnetTest --lb-name linuxnva-slb-ext -n mylbrule --frontend-ip-name myFrontendConfig2 --backend-pool-name linuxnva-slbBackend-ext --protocol Tcp --frontend-port 1022 --backend-port 22
az network nsg rule create --nsg-name linuxnva-1-nic0-nsg -n allow_ssh_in --priority 120 --access Allow --direction Inbound --protocol "Tcp" --source-address-prefix Internet --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "22-22"
az network nsg rule create --nsg-name linuxnva-2-nic0-nsg -n allow_ssh_in --priority 120 --access Allow --direction Inbound --protocol "Tcp" --source-address-prefix Internet --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "22-22"

# Remove LB from IP Config
lbname=linuxnva-slb-int
nic=linuxnva-1-nic0
az network nic ip-config address-pool remove -g vnetTest --ip-config-name "$nic-ipConfig" --nic-name $nic --address-pool linuxnva-slbBackend-int --lb-name $lbname
az network lb address-pool list --lb-name $lbname -o table --query [].backendIpConfigurations[].id

########
# VMSS #
########
vmss_url='https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json'
az group deployment create -n vmssDeployment -g vnetTest --template-uri $vmss_url --parameters '{"vmPwd":{"value":"Microsoft123!"}}'
az network lb outbound-rule create --lb-name linuxnva-vmss-slb-ext -n myoutboundnat --frontend-ip-configs myFrontendConfig --protocol All --idle-timeout 15 --outbound-ports 10000 --address-pool linuxnva-vmss-slbBackend-ext
az network route-table route update --route-table-name vnet1-subnet1 -n vnet1 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet1-subnet1 -n vnet2 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n vnet1 --next-hop-ip-address 10.4.2.200 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n default --next-hop-ip-address 10.4.2.200

# VMSS instances
az vmss list-instances -n nva-vmss -o table
az vmss nic list-vm-nics --vmss-name nva-vmss --instance-id 0 --query [].ipConfigurations[].privateIpAddress -o tsv
az vmss nic list-vm-nics --vmss-name nva-vmss --instance-id 3 --query [].ipConfigurations[].privateIpAddress -o tsv

# Verify ILB
az network lb frontend-ip list --lb-name linuxnva-vmss-slb-int -o table # Next-hop of UDRs
az network lb rule list --lb-name linuxnva-vmss-slb-int -o table  # HA-Ports rule
az network lb address-pool list --lb-name linuxnva-vmss-slb-int -o table --query [].backendIpConfigurations[].id # At least 2 NVAs

# Verify ELB
az network lb frontend-ip list --lb-name linuxnva-vmss-slb-ext -o table # For egress SNAT, for LB rule
az network lb address-pool list --lb-name linuxnva-vmss-slb-ext -o table --query [].backendIpConfigurations[].id # At least 2 NVAs
az network lb outbound-rule list --lb-name linuxnva-vmss-slb-ext -o table # Not in the README.md
az network lb rule list --lb-name linuxnva-vmss-slb-ext -o table # For inbound traffic
az network lb probe create --lb-name linuxnva-vmss-slb-ext -n myProbe --protocol tcp --port 1138 
az network lb rule create --lb-name linuxnva-vmss-slb-ext -n sshLbRule --disable-outbound-snat true --floating-ip false --frontend-ip-name myFrontendConfig --probe myProbe --backend-pool-name linuxnva-vmss-slbBackend-ext --protocol tcp --frontend-port 22 --backend-port 1022
# Modify LB rule
az network lb rule update --lb-name linuxnva-vmss-slb-ext -n sshLbRule --floating-ip true

# NSG on VMSS (none assigned)
az vmss show -n nva-vmss --query virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup
# Create one NSG and assign it to the VMSS
az network nsg create -n nva-vmss-nsg 
az network nsg rule create --nsg-name nva-vmss-nsg -n HTTP --priority 500 --source-address-prefixes '*' --destination-port-ranges 80 --destination-address-prefixes '*' --access Allow --protocol Tcp --description "Allow Port 80"
az network nsg rule create --nsg-name nva-vmss-nsg -n SSH --priority 520 --source-address-prefixes '*' --destination-port-ranges 22 --destination-address-prefixes '*' --access Allow --protocol Tcp --description "Allow Port 22"
az network nsg rule create --nsg-name nva-vmss-nsg -n SSH1022 --priority 540 --source-address-prefixes '*' --destination-port-ranges 1022 --destination-address-prefixes '*' --access Allow --protocol Tcp --description "Allow Port 22"
nsgid=$(az network nsg show -n nva-vmss-nsg -o tsv --query id)
az vmss update -n nva-vmss --set virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].networkSecurityGroup="{ \"id\": \"$nsgid\" }"
az vmss update-instances --name nva-vmss --instance-ids "*"

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
# DNAT:
sudo iptables -t nat -A PREROUTING -p tcp --dport 1022 -j DNAT --to-destination 10.1.1.5:22
sudo iptables -t nat -A PREROUTING -d 51.105.174.182 -p tcp --dport 1022 -j DNAT --to-destination 10.1.1.5:22 # Specifying the dst IP not strictly required

#########
# OTHER #
#########

# Deploy standard ELB
lburl='https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/externalLB_standard.json'
az group deployment create -n elbDeploy -g vnetTest --template-uri $lburl

############
# Clean up #
############
az group delete -n vnetTest -y --no-wait
