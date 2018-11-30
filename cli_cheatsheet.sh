# Azure CLI lab cheat sheet (for Linux)

# Lab initialization
az group create -n vnetTest -l westeurope


# VMSS
az group deployment create --name vmssDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json --parameters '{"vmPwd":{"value":"Microsoft123!"}}'
