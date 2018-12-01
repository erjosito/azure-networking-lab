# Azure CLI lab cheat sheet (for Linux)

# Lab initialization
az group create -n vnetTest -l westeurope
az configure --defaults group=vnetTest
url=https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/NetworkingLab_master.json
# Option 1: default
az group deployment create -n netLabDeployment --template-uri $url -g vnetTest --parameters '{"adminPassword":{"value":"Microsoft123!"}}'
# Option 2: with Vnet 3 in a separate location
az group deployment create -n netLabDeployment --template-uri $url -g vnetTest --parameters '{"adminPassword":{"value":"Microsoft123!"}, "location2ary":{"value": "westus2"}, "location2aryVnets":{"value": [3]}}'


# Verify LB SKUs
az network lb list --query [].[name,sku.name] -o table

# Configure routing pointing to the LB
az network route-table create --name vnet1-subnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet2
az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet1-subnet1
az network vnet subnet update -n myVnet1Subnet1 --vnet-name myVnet1 --route-table vnet1-subnet1

az network route-table create --name vnet2-subnet1
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet1
az network vnet subnet update -n myVnet2Subnet1 --vnet-name myVnet2 --route-table vnet2-subnet1

# Configure ILB
az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int
az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int
az network lb rule delete --lb-name linuxnva-slb-int -n ssh
az network lb rule create --backend-pool-name linuxnva-slbBackend-int --protocol all --backend-port 0 --frontend-port 0 --frontend-ip-name myFrontendConfig --lb-name linuxnva-slb-int --name HARule --floating-ip true --probe-name myProbe

# Configure ELB (outbound NAT)
# az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic1 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
# az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic1 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
# az network lb outbound-rule create --lb-name linuxnva-slb-ext -n myoutboundnat --frontend-ip-configs myFrontendConfig --protocol All --idle-timeout 15 --outbound-ports 10000 --address-pool inuxnva-slbBackend-ext

# VMSS
az group deployment create -n vmssDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json --parameters '{"vmPwd":{"value":"Microsoft123!"}}'
az network lb outbound-rule create --lb-name linuxnva-vmss-slb-ext -n myoutboundnat --frontend-ip-configs myFrontendConfig --protocol All --idle-timeout 15 --outbound-ports 10000 --address-pool linuxnva-vmss-slbBackend-ext

