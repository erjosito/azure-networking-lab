# Azure Networking Open Source Lab

# Table of Contents

[Objectives and initial setup](#objectives)

[Introduction to Azure Networking](#intro)

[Lab 0: Initialize Environment](#lab0)

[Lab 1: Explore Lab environment] (#lab1)

[Lab 2: Spoke-to-Spoke communication over vnet gateway] (#lab2)

[Lab 3: spoke-to-spoke communication over NVA] (#lab3)

[Lab 4: Microsegmentation with NVA] (#lab4)

[Lab 5: VPN connection to the Hub Vnet] (#lab5)

[Lab 6: NVA scalability] (#lab6)

[Lab 7: Outgoing Internet Traffic Protected by NVA] (#lab7)

[Lab 8: Incoming Internet Traffic Protected by NVA] (#lab8)

[Lab 9: Advanced HTTP-based probes] (#lab9)

[End the lab] (#end)

[Conclusion] (#conclusion)

[References] (#ref)


# Objectives and initial setup <a name="objectives"></a>

This document contains a lab guide that helps to deploy a basic environment in Azure that allows to test some of the functionality of the integration between Azure and Ansible.

Before starting with this account, make sure to fulfill all the requisites:

- --A valid Azure subscription account. If you don&#39;t have one, you can create your [free azure account](https://azure.microsoft.com/en-us/free/) (https://azure.microsoft.com/en-us/free/) today.
- --If you are using Windows 10, you can [install Bash shell on Ubuntu on Windows](http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10) ( [http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10](http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10)).
- --Azure CLI 2.0, follow these instructions to install: [https://docs.microsoft.com/en-us/cli/azure/install-azure-cli](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

The labs cover:

- Introduction to Azure networking
- Deployment of multi-vnet Hub and Spoke design
- Traffic filtering in Azure with firewalls
- Microsegmentation using firewalls
- Scaling out NVAs with load balancing and SNAT
- Advanced probes for Azure Load Balancers
- Linux custom routing

Along this lab some variables will be used, that might (and probably should) look different in your environment. This is the variables you need to decide on before starting with the lab. Notice that the VM names are prefixed by a (not so) random number, since these names will be used to create DNS entries as well, and DNS names need to be unique.

| **Description** | **Value used in this lab guide** |
| --- | --- |
| Azure resource group | vnetTest |
| Username for provisioned VMs and NVAs | lab-user |
| Password for provisioned VMs and NVAs | Microsoft123! |
| Shared key for VPN | Microsoft123 |



# Introduction to Azure Networking <a name="intro"></a>

Microsoft Azure has established as one of the leading cloud providers, and part of Azure&#39;s offering is Infrastructure as a Service (IaaS), that is, provisioning raw data center infrastructure constructs (virtual machines, networks, storage, etc), so that any application can be installed on top.

An important part of this infrastructure is the network, and Microsoft Azure offers multiple network technologies that can help to achieve the applications&#39; business objectives: from VPN gateways that offer secure network access to load balancers that enable application (and network, as we will see in this lab) scalability.

Some organizations have decided to complement Azure Network offering with Network Virtual Appliances (NVAs) from traditional network vendors. This lab will focus on the integration of these NVAs, and we will take as example an open source firewall, that will be implemented with iptables running on top of an Ubuntu VM with 2 network interfaces. This will allow to highlight some of the challenges of the integration of this sort of VMs, and how to solve them.

At the end of this guide you will find a collection of useful links, but if you don&#39;t know where to start, here is the home page for the documentation for Microsoft Azure Networking: [https://docs.microsoft.com/en-us/azure/#pivot=services&amp;panel=network](https://docs.microsoft.com/en-us/azure/#pivot=services&amp;panel=network).

If you find any issue when running through this lab or any error in this guide, please open a Github issue in this repository, and we will try to fix it. Enjoy!

# Lab 0: Initialize Environment <a name="lab0"></a>



**Step 1.** Create a new resource group, where we will place all our objects (so that you can easily delete everything after you are done). The last command also sets the default resource group to the newly created one, so that you do not need to download it.

```
az login
```

The &quot;az login&quot; command will provide you a code, that you need to introduce (over copy and paste) in the web page [http://aka.ms/devicelogin](http://aka.ms/devicelogin). After introducing the code, you will need to authenticate with credentials that are associated to a valid Azure subscription.

```
az group create --name vnetTest --location westeurope
```
```
az configure --defaults group=vnetTest
```

**Step 2.** Deploy the master template that will deploy our initial network configuration:

```
az group deployment create --name netLabDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/NetworkingLab\_master.json --resource-group vnetTest --parameters '{"adminUsername":{"value":"lab-user"}, "adminPassword":{"value":"Microsoft123!"}}'
```


**Step 3.** As preparation for one of the labs later in this guide, upgrade the deployed Vnet Gateways vnet4gw and vnet5gw from basic to standard. The following commands will kick off a conversion job that will run in the background for some minutes, but after running them, you can safely continue with the next lab in this guide:

```
az network vnet-gateway update --sku Standard -n vnet4gw
```
```
az network vnet-gateway update --sku Standard -n vnet5gw
```


# Lab 1: Explore Lab environment <a name='lab1'></a>

**Step 1.** Explore the objects created by the ARM template: vnets, subnets, VMs, interfaces, public IP addresses, etc. Save the output of these commands.

You can see some diagrams about the deployed environment here, so that you can interpret better the command outputs

![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure01.png "Overall vnet diagram")

**Figure**: Overall vnet diagram



![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure02.png "Subnet design")

**Figure**: Subnet design of every vnet

```
$ az network vnet list -o table
Location    Name           ProvisioningState    ResourceGroup
----------  -------------  -------------------  ---------------
westeurope  myVnet1        Succeeded            vnetTest
westeurope  myVnet2        Succeeded            vnetTest
westeurope  myVnet3        Succeeded            vnetTest
westeurope  myVnet4        Succeeded            vnetTest
westeurope  myVnet5        Succeeded            vnetTest
```

_Note: Some columns of the ouput above have been removed for clarity purposes._

```
$ az network vnet subnet list --vnet-name myVnet1 -o table
AddressPrefix    Name            ProvisioningState    ResourceGroup
---------------  --------------  -------------------  ---------------
10.1.0.0/24      GatewaySubnet   Succeeded            vnetTest
10.1.1.0/24      myVnet1Subnet1  Succeeded            vnetTest
10.1.2.0/24      myVnet1Subnet2  Succeeded            vnetTest
10.1.3.0/24      myVnet1Subnet3  Succeeded            vnetTest
```

```
$ az vm list -o table
Name            ResourceGroup    Location
--------------  ---------------  ----------
myVnet1vm       VNETTEST         westeurope
myVnet2vm       VNETTEST         westeurope
myVnet3vm       VNETTEST         westeurope
myVnet4vm       VNETTEST         westeurope
myVnet5vm       VNETTEST         westeurope
nva-1           VNETTEST         westeurope
nva-2           VNETTEST         westeurope
vnet1-vm2       VNETTEST         westeurope
```

```
$ az network nic list -o table
Location    Name               Primary    MacAddress         IpForwarding
----------  -----------------  ---------  -----------------  -------------
westeurope  myVnet1vmnic       True       00-0D-3A-21-24-6B
westeurope  myVnet2vmnic       True       00-0D-3A-24-E2-3A
westeurope  myVnet3vmnic       True       00-0D-3A-21-3B-CB
westeurope  myVnet4vmnic       True       00-0D-3A-23-C8-96
westeurope  myVnet5vmnic       True       00-0D-3A-23-C9-68
westeurope  nva-1-nic0         True       00-0D-3A-28-86-EA  True
westeurope  nva-1-nic1                    00-0D-3A-28-80-E5  True
westeurope  nva-2-nic0         True       00-0D-3A-28-85-0E  True
westeurope  nva-2-nic1                    00-0D-3A-28-8C-78  True
westeurope  vnet1-vm2nic       True       00-0D-3A-27-30-3D         4
```

_Note: Some columns of the ouput above have been removed for clarity purposes._

```
$ az network public-ip list -o table
Name               PublicIpAllocationMethod    ResourceGroup    IpAddress
-----------------  -------------------  ----------------------  -----------
myVnet1vmpip       Dynamic                     vnetTest       52.174.33.80
myVnet2vmpip       Dynamic                     vnetTest       40.68.103.227
myVnet3vmpip       Dynamic                     vnetTest       52.232.76.15
myVnet4vmpip       Dynamic                     vnetTest       52.166.196.212
myVnet5vmpip       Dynamic                     vnetTest       52.166.193.255
nvaPip-1           Dynamic                     vnetTest       13.81.116.28
nvaPip-2           Dynamic                     vnetTest       13.81.115.31
vnet1-vm2pip       Dynamic                     vnetTest       52.178.65.11
vnet4gwPip         Dynamic                     vnetTest       13.81.113.28
vnet5gwPip         Dynamic                     vnetTest       13.81.112.142
```

_Note: Some columns of the ouput above have been removed for clarity purposes._

```
$ az network vnet-gateway list -o table
EnableBgp    GatewayType    Location    Name     VpnType
-----------  -------------  ----------  -------  ----------
True         Vpn            westeurope  vnet4gw  RouteBased
True         Vpn            westeurope  vnet5gw  RouteBased
```

_Note: Some columns of the ouput above have been removed for clarity purposes._

# Lab 2: Spoke-to-Spoke communication over vnet gateway <a name='lab2'></a>

Spokes can speak to other spokes by redirecting traffic to a vnet gateway or an NVA in the hub vnet by means of UDRs. The following diagram illustrates what we are trying to achieve in this lab:


![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure03.png "Spoke to spoke communication")

**Figure**: Spoke-to-spoke communication over vnet gateway


**Step 1.** After verifying the public IP address assigned to the first VM in vnet1 (called &quot;myVnet1vm&quot;), connect to it using the credentials that you specified when deploying the template, and verify that you don't have connectivity to the VM in vnet2:


```
$ ssh 52.174.33.80
The authenticity of host '52.174.33.80 (52.174.33.80)' can't be established.
ECDSA key fingerprint is b5:24:f3:aa:1e:f2:1d:fa:09:0e:b4:91:fa:49:b5:2f.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '52.174.33.80' (ECDSA) to the list of known hosts.
lab-user@52.174.33.80's password:

lab-user@myVnet1vm:~$ ping 10.2.1.4
PING 10.2.1.4 (10.2.1.4) 56(84) bytes of data.
^C
--- 10.2.1.4 ping statistics ---

10 packets transmitted, 0 received, **100% packet loss** , time 8999ms
```

_Note: please note your IP address will be different to the one used in this example._

**Step 2.** Verify that the involved subnets (myVnet1-Subnet1 and myVnet2-Subnet1) do not have any routing table attached:


```
$ az network vnet subnet show --vnet-name myVnet1 -n myVnet1Subnet1 | grep routeTable
 "routeTable": null
```

**Step 3.** Create a custom route table named &quot;vnet1-subnet1&quot;, and another one called &quot;vnet2-subnet1&quot;:

```
$ az network route-table create --name vnet1-subnet1
```

```
$ az network route-table create --name vnet1-subnet1
```

**Step 4.** Now attach the custom route tables to both subnets involved in this example (Vnet1Subnet1, Vnet2Subnet2):


```
$ az network vnet subnet update -n myVnet1Subnet1 --vnet-name myVnet1 --route-table vnet1-subnet1
```

```
$ az network vnet subnet update -n myVnet2Subnet1 --vnet-name myVnet2 --route-table vnet2-subnet1
```

**Step 5.** And now you can check that the subnets are associated with the right routing tables:

```
$ az network vnet subnet show --vnet-name myVnet1 -n myVnet1Subnet1 | grep routeTable
 "routeTable": {

    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1",
```

```
$ az network vnet subnet show --vnet-name myVnet2 -n myVnet2Subnet1 | grep routeTable

 "routeTable": {

    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1",
```

**Step 6.** Now we can try to tell Azure to send traffic from subnet 1 to subnet 2 over the hub vnet. Normally you would do this by sending traffic to the vnet router. Let&#39;s see what happens if we try this with vnet1. In order to do so, we need to add a new route to our custom routing table:

```
$ az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-type vnetLocal --route-table-name vnet1-subnet1 -n vnet2
```

**Step 7.** You can verify that the route has been added to the routing table correctly:

```
$ az network route-table route list --route-table-name vnet1-subnet1 -o table
AddressPrefix    Name                  NextHopIpAddress    NextHopType    Provisioning
---------------  --------------------  ------------------  ----------------  ---------
10.2.0.0/16      vnet2                                     VnetLocal         Succeeded
```

However, if we verify the routing table that has been programmed in the interface of VMs in the subnet, you can see that the next hop is actually &quot;None&quot;! (in other words, drop the packets):

```
$ az network nic show-effective-route-table -n myVnet1vmnic
...
    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "name": " vnet2",
      "nextHopIpAddress": [],
      "nextHopType": " None",
      "source": "User",
      "state": "Active"
    },
```

**Step 8.** Now we will install in each route table routes for the other side, pointing to the private IP address of the vnet gateway in vnet 4. This private address is usually the fourth one in the subnet. In our case, 10.4.0.4. You can confirm that this address exists by trying to ping it from any VM.

```
$ az network route-table route update --address-prefix 10.2.0.0/16 --next-hop-ip-address 10.4.0.4  --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet2
```

```
$ az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address 10.4.0.4 --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet1
```

**Step 9.** We can verify what the route tables look like now, and how it has been programmed in one of the NICs associated to the subnet:

```
$ az network route-table route list --route-table-name vnet1-subnet1 -o table
AddressPrefix    Name     NextHopIpAddress    NextHopType       ProvisioningState
---------------  -------  ------------------  ----------------  -------------------
10.2.0.0/16      vnet2    10.4.0.4            VirtualAppliance  Succeeded
```

```
$ az network nic show-effective-route-table -n myVnet1vmnic
...
    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "name": "vnet2",
      "nextHopIpAddress": [
        "10.4.0.4"
      ],
      "nextHopType": "VirtualAppliance",
      "source": "User",
      "state": "Active"
    }
```

**Step 10.** And now VM1 should be able to reach VM2:

```
lab-user@myVnet1vm:~$ ping 10.2.1.4
PING 10.2.1.4 (10.2.1.4) 56(84) bytes of data.
64 bytes from 10.2.1.4: icmp_seq=4 ttl=63 time=7.59 ms
64 bytes from 10.2.1.4: icmp_seq=5 ttl=63 time=5.79 ms
64 bytes from 10.2.1.4: icmp_seq=6 ttl=63 time=4.90 ms
```

# Lab 3: spoke-to-spoke communication over NVA <a name="lab3"></a>

In some situations you would want some kind of security between the different Vnets. Although this security can be partially provided by Network Security Groups, certain organizations might require some more advanced filtering functionality such as the one that firewalls provide.

In this lab we will insert a Network Virtual Appliance in the communication flow. Typically these Network Virtual Appliance might be a next-generation firewall of vendors such as Barracuda, Checkpoint, Cisco or Palo Alto, to name a few, but in this lab we will use a Linux machine with 2 interfaces and traffic forwarding enabled. For this exercise, the firewall will be inserted as a &quot;firewall on a stick&quot;, that is one single interface will suffice.


![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure04.png "Spoke-to-spoke and NVAs")

**Figure** Spoke-to-spoke traffic going through an NVA


**Step 1.** In the Ubuntu VM acting as firewall iptables have been configured by means of a Custom Script Extension. This extension downloads a script from a public repository (the Github repository for this lab) and runs it on the VM on provisioning time. Verify that the NVAs have successfully registered the extensions with this command:

```
$ az vm extension list --vm-name nva-1 -o table
```

**Step 2.** We need to replace the route we installed in Vnet1-Subnet1 and Vnet2-Subnet1 pointing to Vnet4&#39;s vnet gateway, with another one pointing to the NVA. We will use the first NVA, with an IP address of 10.4.2.101.

```
$ az network route-table route update --next-hop-ip-address 10.4.2.101 --route-table-name vnet1-subnet1 -n vnet2
```

```
$ az network route-table route update --next-hop-ip-address 10.4.2.101 --route-table-name vnet2-subnet1 -n vnet1
```

**Step 3.** Find out the public IP address of nva-1, SSH to it and have a look at the iptables rules:

```
$ ssh lab-user@13.81.116.28
The authenticity of host &#39;13.81.116.28 (13.81.116.28)&#39; can&#39;t be established.
ECDSA key fingerprint is 17:ac:de:80:b4:48:fc:22:78:18:59:ec:f9:b6:27:ad.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added &#39;13.81.116.28&#39; (ECDSA) to the list of known hosts.
lab-user@13.81.116.28&#39;s password:

Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
```

```
lab-user@nva-1:~$ sudo iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
ACCEPT     udp  --  anywhere             anywhere             udp dpt:bootpc
Chain FORWARD (policy ACCEPT)
target     prot opt source               destination
DROP       icmp --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere
ACCEPT     all  --  anywhere             anywhere
Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
```

**Step 4.** You can verify that VM1 cannot ping VM2, but it can SSH into it:

```
lab-user@myVnet1vm:~$ ping 10.2.1.4
PING 10.2.1.4 (10.2.1.4) 56(84) bytes of data.
^C
--- 10.2.1.4 ping statistics ---

9 packets transmitted, 0 received, **100% packet loss** , time 8033ms
lab-user@myVnet1vm:~$
lab-user@myVnet1vm:~$ssh 10.2.1.4
The authenticity of host '10.2.1.4 (10.2.1.4)' can't be established.
ECDSA key fingerprint is SHA256:o+kldZQA9cY9bOXQOUUMd3keFXN2TofSGXcJ1VxKuXM.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.2.1.4' (ECDSA) to the list of known hosts.
lab-user@10.2.1.4's password:
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
lab-user@myVnet2vm:~$
```

**Step 5.** Now you can remove the rule that drops ICMP traffic in the firewall, and verify that ping is now working too. With this you have successfully verified that traffic is actually controlled by the firewall.

```
lab-user@nva-1:~$ sudo iptables -D FORWARD -p icmp -j DROP
```

**Step 6.** Now put back the rule to drop the ICMP traffic, we will need it in further labs:

```
lab-user@nva-1:~$ sudo iptables -A FORWARD -p icmp -j DROP
```

# Lab 4: Microsegmentation with NVA<a name="lab4"></a>

Some organizations wish to filter not only traffic between specific network segments, but traffic inside of a subnet as well, in order to reduce the probability of successful attacks spreading inside of an organization. This is what some in the industry know as &quot;microsegmentation&quot;.

![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure05.png "Microsegmentation")

**Figure**. Intra-subnet NVA-based filtering, also known as &quot;microsegmentation&quot;

**Step 1.** In order to be able to test the topology above, we will use the second VM in myVnet1-Subnet1. (vnet1-vm2). We need to instruct all VMs in subnet 1 to send local traffic to the NVAs as well. This can be easily done by adding an additional User-Defined Route to the corresponding routing table:

```
$ az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet1-subnet1
```

**Step 2.** You can verify similarly to the previous lab that traffic now is flowing through the firewall, by enabling and disabling the ICMP rule as described in the previous section, or by verifying that ping does not work, but SSH does.



# Lab 5: VPN connection to the Hub Vnet

This lab probably makes sense later, to wait for the completion of the vnet-gateway resize command

**Step 1.** First, we need to change the BGP Autonomous System Number (ASN) of one of the gateways, since the ARM template deploys them with the same one, but in order to set up a Vnet-to-Vnet connection they need to be different. You can check the ASN with this command:

```
$ az network vnet-gateway show -n vnet4gw | grep asn
    "asn": 65515,
```

And you can change it this way (please note that the resize operation initiated in the previous lab might not have finished yet, in which case the following command cannot be executed):

```
az network vnet-gateway update --asn 65514 -n vnet4gw
```

**Step 2.** Once both Vnet gateways have different ASNs, we can establish a VPN tunnel between them. Note that tunnels are bidirectional, so you will need to establish a tunnel from vnet4gw to vnet5gw, and another one in the opposite direction (note that it is normal for these commands to take some time to run):

```
$ az network vpn-connection create -n 4to5 --vnet-gateway1 vnet4gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet5gw
```

```
$ az network vpn-connection create -n 5to4 --vnet-gateway1 vnet5gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet4gw
```

Once you have provisioned the connections you can check their state with this command:

```
$ az network vpn-connection list -o table
```

**Step 3.** If you now try to reach a VM in myVnet5 from any of the VMs in the other Vnets, it should work without any further configuration, following the topology found in the figure below:

```
lab-user@myVnet1vm:~$ ping 10.5.1.4
PING 10.5.1.4 (10.5.1.4) 56(84) bytes of data.
64 bytes from 10.5.1.4: icmp_seq=1 ttl=62 time=10.9 ms
64 bytes from 10.5.1.4: icmp_seq=2 ttl=62 time=9.92 ms
```

![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figureVpn.png "VPN and Vnet Peering")

**Figure** : VPN connection through Vnet peering

This is so because of how the Vnet peerings were configured, more specifically the parameters AllowForwardedTraffic and UseRemoteGateways (in the spokes),  and AllowGatewayTransite (in the hub):

```
az network vnet peering list --vnet-name myVnet1 -o table
AllowForwardedTraffic    Name           PeeringState    UseRemoteGateways
-----------------------  -------------  --------------  -------------------
True                     LinkTomyVnet4  Connected       True
```

```
$ az network vnet peering list --vnet-name myVnet4 -o table
AllowGatewayTransit    Name           PeeringState
---------------------  -------------  --------------
True                   LinkTomyVnet2  Connected
True                   LinkTomyVnet1  Connected
True                   LinkTomyVnet3  Connected
```

**Step 4.** You can have a look at the effective routing table of an interface, and you will see that a route for Vnet5 has been automatically established, pointing to the vnet Gateway of the hub Vnet (to its public IP address, to be accurate):

```
$ az network nic show-effective-route-table -n myVnet1vmnic
...
   {
      "addressPrefix": [
        "10.5.0.0/16"
      ],
      "name": null,
      "nextHopIpAddress": [
        "13.81.113.28"
      ],
      "nextHopType": "VirtualNetworkGateway",
      "source": "VirtualNetworkGateway",
      "state": "Active"
    },
```

However, you might want to push this traffic through the Network Virtual Appliances too. The process that we have seen so far is valid for the GatewaySubnet of Vnet4 (where the hub VPN gateway is located), as the following ` depicts:

![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure06.png "VPN, Vnet Peering and NVA")

**Figure**. VPN traffic combined with Vnet peering and a Network Virtual Appliance

**Step 5.** For the gateway subnet in myVnet4 we will create a new routing table, add a route for vnet1-subnet1, and associate the route table to the GatewaySubnet:

```
$ az network route-table create --name vnet4-gw
{
  "etag": "W/\"c784f479-3e85-42d0-ba7b-d2c420f4d3d3\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet4-gw",
  "location": "westeurope",
  "name": "vnet4-gw",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest",
  "routes": [],
  "subnets": null,
  "tags": null,
  "type": "Microsoft.Network/routeTables"
}
```

```
$ az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet4-gw -n vnet1-subnet1
{
  "addressPrefix": "10.1.1.0/24",
  "etag": "W/\"97e76ca7-9217-4137-80fe-6c40a8488e09\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet4-gw/routes/vnet1-subnet1",
  "name": "vnet1-subnet1",
  "nextHopIpAddress": "10.4.2.101",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
```

```
$ az network route-table route list --route-table-name vnet4-gw -o table
AddressPrefix    Name           NextHopIpAddress    NextHopType
---------------  -------------  ------------------  ----------------
10.1.1.0/24      vnet1-subnet1  10.4.2.101          VirtualAppliance
```


```
$ az network vnet subnet update -n GatewaySubnet --vnet-name myVnet4 --route-table vnet4-gw
```

```
$ az network route-table route create --address-prefix 10.5.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet5
```

**Step 6.** Now you can verify that VMs in myVnet1Subnet1 can still connect over SSH to VMs in myVnet5, but not any more over ICMP (as long as the rule for dropping ICMP traffic is configured in the NVA):

```
lab-user@myVnet1vm:~$ ping 10.5.1.4
PING 10.5.1.4 (10.5.1.4) 56(84) bytes of data.
^C
--- 10.5.1.4 ping statistics ---

3 packets transmitted, 0 received, 100% packet loss, time 1999ms
lab-user@myVnet1vm:~$ ssh 10.5.1.4
The authenticity of host '10.5.1.4 (10.5.1.4)' can't be established.
ECDSA key fingerprint is SHA256:x8VGe15aAkaIRjznPaUzO94IkXHQlmh4h2g1Jq1oOdk.
Are you sure you want to continue connecting (yes/no)? zes
Please type 'yes' or 'no': yes
Warning: Permanently added '10.5.1.4' (ECDSA) to the list of known hosts.
lab-user@10.5.1.4's password:

Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
```


# Lab 6: NVA scalability<a name="lab6"></a>

If all traffic is going through a single Network Virtual Appliance, chances are that it is not going to scale. Whereas you could scale it up by resizing the VM where it lives, not all VM sizes are supported by NVA vendors. Besides, scale out provides a more linear way of achieving additional performance, potentially even increasing and decreasing the number of NVAs automatically via scale sets.

In this lab we will use two NVAs and will send the traffic over both of them by means of an Azure Load Balancer. Since return traffic must flow through the same NVA (since firewalling is a stateful operation and asymmetric routing would break it), the firewalls will source-NAT traffic to their individual addresses.


![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/ansible_arch.png "Load Balancer for NVA Scale Out")

**Figure**. Load balancer for NVA scale out

Note that no clustering function is required in the firewalls, each firewall is completely unaware of the others.

**Step 1.** First, verify that an internal load balancer has been deployed with the frontend IP address 10.4.2.100:

```
$ az network lb list -o table
Location    Name         ProvisioningState    ResourceGroup
----------  -------      -------------------  ---------------
westeurope  nva-slb-ext  Succeeded            vnetTest
westeurope  nva-slb-int  Succeeded            vnetTest
```

**Step 2.** Now get information about the object names inside of the Load Balancer. The following command can be used in order to get the most relevant attributes:

```
$ az network lb show -n nva-slb-int | grep name
      "name": "nva-slbBackend-int",
      "name": "myFrontendConfig",
        "name": null,
      "name": "mySLBConfig",
  "name": "nva-slb-int",
      "name": "myProbe",
```

**Step 3.** Now we need to add the internal interfaces of both appliances to the backend address pool of the load balancer:


```
$ az network nic ip-config address-pool add --ip-config-name**  nva-1 -nic0-ipConfig --nic-name nva-1 -nic0 --address-pool nva-slbBackend-int --lb-name nva-slb-int
```

```
$ az network nic ip-config address-pool add --ip-config-name nva-2 -nic0-ipConfig --nic-name nva-2 -nic0 --address-pool nva-slbBackend-int --lb-name nva-slb-int
```

**Step 4.** Let us verify the LB&#39;s rules. In this case, we need to remove the existing one and replace it with another, where we will enable Direct Server Return:

```
$ az network lb rule list --lb-name nva-slb-int -o table
  BackendPort    FrontendPort    LoadDistribution    Name         Protocol
-------------  --------------    ------------------  -----------  --------
           22            1022    Default             mySLBConfig  Tcp
```

```
$ az network lb rule delete --lb-name nva-slb-int -n mySLBConfig
```

```
$ az network lb rule create --backend-pool-name nva-slbBackend-int --protocol Tcp --backend-port 22 --frontend-port 22 --frontend-ip-name myFrontendConfig --lb-name nva-slb-int --name sshRule --floating-ip true --probe-name myProbe
```

**Step 5.** We must change the next-hop for the UDRs that are required for the communication. We need to point them at the virtual IP address of the load balancer (10.4.2.100). We will take the route for microsegmentation, in order to test the connection depicted in the picture above:

```
$ az network route-table route update --route-table-name vnet1-subnet1 -n vnet1-subnet1 --next-hop-ip-address 10.4.2.100
```

At this point communication between the VMs should be possible, flowing through the NVA, on the TCP ports specified by Load Balancer rules. Note that ICMP will not work, since at this point Azure Load Balancer does not balance ICMP traffic.

```
lab-user@myVnet1vm:~$ ping 10.1.1.5
PING 10.1.1.5 (10.1.1.5) 56(84) bytes of data.
^C

--- 10.1.1.5 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss , time 1006ms
lab-user@myVnet1vm:~$ ssh 10.1.1.5
lab-user@10.1.1.5's password:

Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
```

**Step 6.** Observe the source IP address that the destination machine sees:

```
lab-user@myvm:~$ who
lab-user pts/0        2017-03-23 23:41 (10.4.2.101)
```

This is expected, since firewalls are configured to source NAT the connections outgoing on that interface:

```
lab-user@nva-1:~$ sudo iptables -L -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
Chain INPUT (policy ACCEPT)
target     prot opt source               destination
Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  anywhere             anywhere
```

**Step 7.** We will simulate a failure of the NVA where the connection is going through (in this case 10.4.2.101, nva-1). First of all, verify that both ports 1138 (used by the internal load balancer of this lab scenario) and 1139 (used by the external load balancer of a lab scenario later in this guide) are open:

```
lab-user@nva-1:~$ nc -zv -w 1 127.0.0.1 1138-1139
Connection to 127.0.0.1 1138 port [tcp/\*] succeeded!
Connection to 127.0.0.1 1139 port [tcp/\*] succeeded!
```

The process answering to TCP requests on those ports is netcat, as you can see with netstat:

```
lab-user@nva-1:~$ sudo netstat -lntp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address  Foreign Address  State    PID/Program
tcp        0      0 0.0.0.0:1138   0.0.0.0:\*        LISTEN   1783/nc
tcp        0      0 0.0.0.0:1139   0.0.0.0:\*        LISTEN   1782/nc
tcp        0      0 0.0.0.0:22     0.0.0.0:\*        LISTEN   1587/sshd
tcp6       0      0 :::80          :::\*             LISTEN   11730/apache2
tcp6       0      0 :::22          :::\*             LISTEN   1587/sshd
```

**Step 8.** We will shutdown interface eth0 in the firewall where the connection was going through (the address you saw in the &quot;who&quot; command):

```
lab-user@nva-1:~$ sudo ifconfig eth0 down
```

The SSH session will become irresponsive, since the flow is broken. However, if you initiate another SSH connection to VM2 (10.1.1.5) from VM1 (10.1.1.4), you will see that you are going now through the other NVA (in this example, nva-2). Note that it takes some time (defined by the probe frequency and number, per default two times 15 seconds) until the load balancer decides to take the NVA out of rotation.

```
lab-user@myvm:~$ who
lab-user pts/0        2017-03-23 23:41 (10.4.2.101)
lab-user pts/1        2017-03-24 00:01 (10.4.2.102)
```

**Step 9.** Bring eth0 interface back up, in the NVA where you shut it down:

```
$ sudo ifconfig eth0 up
```

# Lab 7: Outgoing Internet Traffic Protected by NVA<a name="lab7"></a>

What if we want to send all traffic leaving the vnet towards the public Internet through the NVAs? Wwe need to do is make sure that Internet traffic to/from all VMs flows through the NVAs via User-Defined Routes, and that NVAs source-NAT the outgoing traffic with their public IP address, so that they get the return traffic too.

For this test we will use the VM in vnet3.

**Step 1.** Create a routing table for myVnet3Subnet1:

```
$ az network route-table create --name vnet3-subnet1
```

**Step 2.** Create a default route in that table pointing to the internal LB VIP (10.4.2.100):

```
$ az network route-table route create --address-prefix 0.0.0.0/0 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n default
```

**Step 3.** Associate the route table to the subnet myVnet3Subnet1:

```
$ az network vnet subnet update -n myVnet3Subnet1 --vnet-name myVnet3 --route-table vnet3-subnet1
```

**Step 4.** Add another default route for Vnet1Subnet1 pointing to the internal load balancer&#39;s VIP, and the reciprocal route in the custom routing table for Vnet1Subnet1, and verify that you have SSH connectivity between the VM in Vnet1 and the VM in Vnet3.


```
$ az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet1subnet1
```

```
$ az network route-table route create --address-prefix 10.3.1.0/24 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet3subnet1
```

```
lab-user@myVnet1vm:~$ ssh 10.3.1.4
The authenticity of host '10.3.1.4 (10.3.1.4)' can't be established.
ECDSA key fingerprint is SHA256:ofxGjkNl2WYq+GvlEUYNTd5WiAlV4Za2/X3BwcpX8hQ.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.3.1.4' (ECDSA) to the list of known hosts.
lab-user@10.3.1.4's password:

Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
...
lab-user@ myVnet3vm :~$
```


**Step 5.** Verify that the NVAs are source-NATting all traffic outgoing its external interface (eth1):

```
lab-user@nva-1:~$ sudo iptables -vL -t nat

Chain PREROUTING (policy ACCEPT 87329 packets, 3531K bytes)
 pkts bytes target     prot opt in     out     source         destination
Chain INPUT (policy ACCEPT 48225 packets, 1943K bytes)
 pkts bytes target     prot opt in     out     source         destination
Chain OUTPUT (policy ACCEPT 2157 packets, 137K bytes)
 pkts bytes target     prot opt in     out     source         destination
Chain POSTROUTING (policy ACCEPT 29 packets, 1740 bytes)
 pkts bytes target     prot opt in     out     source         destination
   910 61924 MASQUERADE  all  --  any    eth0   anywhere       anywhere
  1220 73886 MASQUERADE  all  --  any    eth1   anywhere       anywhere
```

**Step 6.** Now verify that you have internet access from the VM in myVnet3. Note that you don&#39;t have Internet access to the VM in myVnet3Subnet1 any more, after changing default routing for that subnet. You can connect to one of the NVAs, and from there SSH to the internal IP address of the VM (10.3.1.4). Let&#39;s add another rule to the internal load balancer to allow for port 80:

```
$ az network lb rule create --backend-pool-name nva-slbBackend-int --protocol Tcp --backend-port 80 --frontend-port 80 --frontend-ip-name myFrontendConfig --lb-name nva-slb-int --name httpRule --floating-ip true --probe-name myProbe
```

Now we can test connectivity to any web page, for example to the IP address service http://ifconfig.co:

```
lab-user@myVnet3vm:~$ curl http://ifconfig.co
52.232.81.172
```

# Lab 8: Incoming Internet Traffic Protected by NVA<a name="lab8"></a>

In this lab we will explore what needs to be done so that certain VMs can be accessed from the public Internet.

We need an external load balancer, with a public IP address, that will take traffic from the Internet, and send it to one of the Network Virtual Appliances, as next figure shows:

![Architecture Image](https://github.com/erjosito/azure-networking-lab/blob/master/figure09.png "LB sandwich")

**Figure**. LBs in front and behind the NVAs

As it can be seen in the figure, there are several issues that need to be figured out.

**Step 1.** First things first, let&#39;s have a look at the external load balancer:

```
$ az network lb list -o table
Location    Name         ProvisioningState    ResourceGroup
----------  -----------  -------------------  ---------------
westeurope   nva-slb-ext  Succeeded            vnetTest
westeurope  nva-slb-int  Succeeded            vnetTest
```

```
$ az network lb show -n nva-slb-ext | grep name
      "name": "nva-slbBackend-ext",
      "name": "myFrontendConfig",
        "name": null,
      "name": "mySLBConfig",
  "name": "nva-slb-ext",
      "name": "myProbe",
```

**Step 2.** Now you can add the external interfaces of the NVAs to the backend address pool of the external load balancer:

```
$ az network nic ip-config address-pool add --ip-config-name nva-1 -nic1-ipConfig --nic-name nva-1 -nic1 --address-pool nva-slbBackend-ext --lb-name nva-slb-ext
```

```
$ az network nic ip-config address-pool add --ip-config-name nva- -nic1-ipConfig --nic-name nva-2 -nic1 --address-pool nva-slbBackend-ext --lb-name nva-slb-ext
```

**Step 3.** Let us verify the LB&#39;s rules. In this case, we need to remove the existing one and replace it with another, where we will enable Direct Server Return:

```
$ az network lb rule list --lb-name nva-slb-ext -o table
  BackendPort    FrontendPort    LoadDistribution    Name         Protocol
-------------  --------------    ------------------  -----------  --------
           22            1022    Default             mySLBConfig  Tcp
```

```
$ az network lb rule delete --lb-name nva-slb-ext -n mySLBConfig
```

```
$ az network lb rule create --backend-pool-name nva-slbBackend-ext --protocol Tcp --backend-port 22 --frontend-port 22 --frontend-ip-name myFrontendConfig --lb-name nva-slb-ext --name sshRule --floating-ip true --probe-name myProbe
```

**Step 4.** The first problem we need to solve is routing at the NVA. VMs get a static route for 168.63.129.16 pointing to their primary interface, in this case, eth0. Verify that that is the case, since the disabling/enabling of eth0 in a previous lab might have deleted that route.

```
lab-user@nva-2:~$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref  Use Iface
0.0.0.0         10.4.3.1        0.0.0.0         UG    0      0      0 eth1
0.0.0.0         10.4.2.1        0.0.0.0         UG    100    0      0 eth0
10.0.0.0        10.4.2.1        255.248.0.0     UG    0      0      0 eth0
10.4.2.0        0.0.0.0         255.255.255.0   U     100    0      0 eth0
10.4.3.0        0.0.0.0         255.255.255.0   U     10     0      0 eth1
168.63.129.16   10.4.2.1        255.255.255.255 UGH   100    0      0 eth0
169.254.169.254 10.4.2.1        255.255.255.255 UGH   100    0      0 eth0
```


If the route to 168.63.129.16 is not there, you can add it easily:

```
$ sudo route add -host 168.63.129.16 gw 10.4.2.1 dev eth0
```

By the way, if the route to 168.63.129.16 disappeared, chances are that you need to add another static route telling the firewall where to find the 10.0.0.0/8 networks:

```
$ sudo route add -net 10.0.0.0/8 gw 10.4.2.1 dev eth0
```

Now we are sure that the NVA has a static route for the IP address where the LB probes come from (168.63.129.16) pointing to 10.4.2.1 (eth1, its internal, vnet-facing interface). So that when a probe from the internal load balancer arrives, its answer will be sent down eth0.

However, what happens when a probe arrives from the external load balancer on eth1? Since the static route is pointing down to eth0, the NVA would send the answer there. But this is not going to work, because the answer needs to be sent over the same interface.

**Step 5.** You can  verify this behavior connecting to one of the NVA VMs and capturing traffic on both ports (filtering it to the TCP ports where the probes are configured). In this case we are connecting to nva-1, and verifying the internal interface and TCP port (eth0, TCP port 1138):

```
lab-user@nva-1:~$ sudo tcpdump -i eth0 port 1138
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
22:50:49.277214 IP 168.63.129.16.50717 > 10.4.2.101.1138: Flags [SEW], seq 2412262844, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
22:50:49.277239 IP 10.4.2.101.1138 > 168.63.129.16.50717: Flags [S.], seq 3801638535, ack 2412262845, win 29200, options [mss 1460,nop,nop,sackOK,nop,wscale 7], length 0
22:50:49.277501 IP 168.63.129.16.50717 > 10.4.2.101.1138: Flags [.], ack 1, win 513, length 0
22:50:49.589219 IP 168.63.129.16.50288 > 10.4.2.101.1138: Flags [F.], seq 0, ack 1, win 64240, length 0
22:50:50.198577 IP 168.63.129.16.50288 > 10.4.2.101.1138: Flags [F.], seq 0, ack 1, win 64240, length 0
```

You can see that the 3-way handshake completes successfully on the internal interface, as the TCP flags of the capture indicate. But if we have a look at the external interface, things look different there:

```
lab-user@nva-1:~$ sudo tcpdump -i eth1 port 1139
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
22:54:15.584402 IP 168.63.129.16.56583 > 10.4.3.101.1139: Flags [SEW], seq 314423445, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
22:54:18.584140 IP 168.63.129.16.56583 > 10.4.3.101.1139: Flags [SEW], seq 314423445, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
22:54:24.584127 IP 168.63.129.16.56583 > 10.4.3.101.1139: Flags [S], seq 314423445, win 8192, options [mss 1440,nop,nop,sackOK], length 0
22:54:30.587651 IP 168.63.129.16.56995 > 10.4.3.101.1139: Flags [SEW], seq 2980654025, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
22:54:33.587444 IP 168.63.129.16.56995 > 10.4.3.101.1139: Flags [SEW], seq 2980654025, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
```

As you can see in the TCP flags, the 3-way handshake never completes, but the Load Balancer keeps sending packets with the SYN flag on, without getting a single ACK back.

**Step 6.** In order to fix routing, we are going to implement policy based routing in both NVAs. The first step is creating a custom route table at the Linux level, by modifying the file rt\_tables and adding the line &quot;201 slbext&quot;:

```
$ sudo vi /etc/iproute2/rt\_tables
```

The file now should look like something like this:

```
lab-user@nva-1:~$ more /etc/iproute2/rt\_tables
#
# reserved values
#
255     local
254     main
253     default
0       unspec
#
# local
#
#1      inr.ruhep
201 slbext
```

**Step 7.** Now we add a rule that will tell Linux when to use that routing table. That is, when it wishes to send the answer to the LB probe from the external interface (10.4.3.101 in the case of nva-1, 10.4.3.102 for nva-2).

```
$ sudo ip rule add from 10.4.3.101 to 168.63.129.16 lookup slbext
```

**Step 8.** And finally, we populate the custom routing table with a single route, pointing up to eth1:


```
$ sudo ip route add 168.63.129.16 via 10.4.3.1 dev eth1 table slbext
```


**Step 9.** Verify that the commands took effect, and that the TCP 3-way handshake is now correctly established on eth1:

```
lab-user@nva-2:~$ ip rule list
0:      from all lookup local
32765:  from 10.4.3.101 to 168.63.129.16 lookup slbext
32766:  from all lookup main
32767:  from all lookup default
```
```
lab-user@nva-2:~$ ip route show table slbext
168.63.129.16 via 10.4.3.1 dev eth0
```
```
lab-user@nva-1:~$ sudo tcpdump -i eth1 port 1139
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
23:11:45.774301 IP 168.63.129.16.54073 > 10.4.3.101.1139: Flags [**SEW**], seq 3604073494, win 8192, options [mss 1440,nop,wscale 8,nop,nop,sackOK], length 0
23:11:45.774333 IP 10.4.3.101.1139 > 168.63.129.16.54073: Flags [**S.**], seq 2611260758, ack 3604073495, win 29200, options [mss 1460,nop,nop,sackOK,nop,wscale 7], length 0
23:11:45.774488 IP 168.63.129.16.54073 > 10.4.3.101.1139: Flags [**.**], ack 1, win 513, length 0
23:11:46.086572 IP 168.63.129.16.53650 > 10.4.3.101.1139: Flags [F.], seq 0, ack 1, win 64240, length 0
23:11:46.695967 IP 168.63.129.16.53650 > 10.4.3.101.1139: Flags [F.], seq 0, ack 1, win 64240, length 0
```

**Step 10.** Don't forget to run the previous procedure (from step 6) in nva-2 too

**Step 11.** One missing piece is the NAT configuration at both firewalls: traffic will arrive from the external load balancer addressed to the VIP assigned to the load balancer, since we configured Direct Server Return (also known as floating IP). Now we need to NAT that address to the VM where we want to send this traffic to, in both firewalls:

```
lab-user@nva-1:~$ sudo iptables -t nat -A PREROUTING -p tcp -d 52.174.29.152 --dport 1022 -j DNAT --to-destination 10.3.1.4:22
```

```
lab-user@nva-2:~$ sudo iptables -t nat -A PREROUTING -p tcp -d 52.174.29.152 --dport 1022 -j DNAT --to-destination 10.3.1.4:22
```

```
lab-user@nva-2:~$ sudo iptables -vL -t nat

Chain PREROUTING (policy ACCEPT 114 packets, 6118 bytes)
 pkts bytes target     prot opt in     out     source        destination
    0     0 DNAT       tcp  --  any    any     anywhere      52.232.73.234        tcp dpt:ssh to:10.3.1.4:22
Chain INPUT (policy ACCEPT 39 packets, 1967 bytes)
 pkts bytes target     prot opt in     out     source        destination
Chain OUTPUT (policy ACCEPT 59 packets, 3831 bytes)
 pkts bytes target     prot opt in     out     source        destination
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source        destination
 1193 81052 MASQUERADE  all  --  any    eth0    anywhere      anywhere
 1574 95368 MASQUERADE  all  --  any    eth1    anywhere      anywhere
```

**Step 12.** Now we should be able to connect to the VM from the public Internet:

```
$ ssh lab-user@52.174.188.207
The authenticity of host '[52.174.188.207]:1022 ([52.174.188.207]:1022)' can't be established.
ECDSA key fingerprint is 74:1f:d0:f9:fc:6a:0c:bc:d7:ee:d7:96:90:fd:79:b0.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[52.174.188.207]:1022' (ECDSA) to the list of known hosts.
lab-user@52.174.188.207's password:
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
...

lab-user@myVnet3vm:~$
```


# Lab 9: Advanced HTTP-based probes <a name='lab9'></a>

Standard TCP probes only verify that the interface being probed answers to TCP sessions. But what if it is the other interface that has an issue? What good does it make if VMs send all traffic to a Network Virtual Appliance with a perfectly working internal interface (eth0 in our lab), but eth1 is down, and therefore that NVA has no Internet access whatsoever?

HTTP probes can be implemented for that purpose. The probes will call for an HTTP URL that will return different HTTP codes, after verifying that all connectivity for the specific NVA is OK. We will use PHP for this, and a script that pings a series of IP addresses or DNS names, both in the Vnet and the public Internet (to verify internal and external connectivity). See the file &quot;index.php&quot; in this repository for more details.

**Step 1.** We need to change the probe from TCP-based to HTTP-based, for example, in the internal LB (you can do it in the external one too):

```
$ az network lb probe update -n myProbe --lb-name nva-slb-int --protocol Http --path "/" --port 80
```

**Step 2.** Verify the logic of the &quot;/var/www/html/index.php&quot; file in each NVA VM. As you can see, it returns the HTTP code 200 only if a list of IP addresses or DNS names is reachable. You can query this from any VM:

```
lab-user@myVnet1vm:~$ curl -i 10.4.2.101
HTTP/1.1 200 OK
Date: Tue, 28 Mar 2017 00:08:47 GMT
Server: Apache/2.4.18 (Ubuntu)
Vary: Accept-Encoding
Content-Length: 236
Content-Type: text/html; charset=UTF-8
<html>
   <header>
     <title>Network Virtual Appliance</title>
   </header>
   <body>
     <h1>
       Welcome to the Open Source Azure Networking Lab
     </h1>
     <br>
     All target hosts seem to be reachable
   </body>
</html>
```

```
lab-user@nva-1:~$ more /var/www/html/index.php
<html>
   <header>
     <title>Network Virtual Appliance</title>
   </header>
   <body>
     <h1>
       Welcome to the Open Source Azure Networking Lab
     </h1>
     <br>
     <?php
       $hosts = array **("bing.com", "10.1.1.4")**;
       $allReachable = true;
       foreach ($hosts as $host) {
         $result = exec ("ping -c 1 -W 1 " . $host . " 2>&1 | grep received");
         $pos = strpos ($result, "1 received");
         if ($pos === false) {
           $allReachable = false;
           break;
         }
       }
       if ($allReachable === false) {
         // Ping did not work
         **http_response_code (299);
         print ("The target hosts do not seem to be all reachable (" . $host . ")\n");
       } else {
         // Ping did work
         http_response_code (200);
         print ("All target hosts seem to be reachable\n");
       }
     ?>
   </body>
</html>
lab-user@nva-1:~$
```

Now the probe for the internal load balancer will fail even if the internal interface is up, but for some reason the NVA cannot connect to the Internet, therefore enhancing the reliability of the solution.



# End the lab <a name='end'></a>

To end the lab, simply delete the resource group that you created in the first place ( **ansiblelab** in our example) from the Azure portal or from the Azure CLI:

```
az group delete --name vnetTest
```


# Conclusion <a name='conclusion'></a>

I hope you have had fun running through this lab, and that you learnt something that you did not know before. We ran through multiple Azure networking topics like IPSec VPN, vnet peering, hub &amp; spoke vnet topologies and advanced NVA integration, but we covered as well other non-Azure topics such as Linux custom routing or advanced probes programming with PHP.

If you have any suggestion to improve this lab, please open an issue in Github in this repository.

## References <a name='ref'></a>

Useful links:

- Azure network documentation: [https://docs.microsoft.com/en-us/azure/#pivot=services&amp;panel=network](https://docs.microsoft.com/en-us/azure/#pivot=services&amp;panel=network)
- Vnet documentation: [https://docs.microsoft.com/en-us/azure/virtual-network/](https://docs.microsoft.com/en-us/azure/virtual-network/)
- Load Balancer documentation: [https://docs.microsoft.com/en-us/azure/load-balancer/](https://docs.microsoft.com/en-us/azure/load-balancer/)
- VPN Gateway documentation: [https://docs.microsoft.com/en-us/azure/vpn-gateway/](https://docs.microsoft.com/en-us/azure/vpn-gateway/)
