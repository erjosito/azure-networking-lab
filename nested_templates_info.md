# ARM Template schema

This project uses a relatively complex schema of nested templates, here you can find a summary of the templates used. Note that not necessarily all templates are used, since in some cases they are only triggered if certain parameter conditions are met:

* NetworkingLab_master
  * multiVnetLab
    * vnet3Subnets
      * vpnGw
      * pipDynamic
      * linuxVM
        * nic_noNSG_noSLB_PIP_dynamic
  * linuxVM
    * nic_noNSG_noSLB_PIP_dynamic
  * vnetPeeringHubNSpoke
  * nvaLinux_2nic_noVnet
    * nic_noNSG_noSLB_noPIP_static
    * nic_noNSG_noSLB_PIP_static
    * slb
      * internalLB
      * externalLB
      * internalLB_standard
  * vpnGw