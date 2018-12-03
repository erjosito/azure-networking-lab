# Azure Networking Lab

# Table of Contents

[Objectives and initial setup](#objectives)

[Introduction to Azure Networking](#intro)

**[Part 0: First steps](#part0)**

- [Lab 0: Initialize Environment](#lab0)

- [Lab 1: Explore Lab environment](#lab1)

**[Part 1: Spoke-to-Spoke communication over NVA](#part1)**

- [Lab 2: Spoke-to-Spoke communication over NVA](#lab2)

- [Lab 3: Microsegmentation with NVA](#lab3)

**[Part 2: NVA Scalability and HA](#part2)**

- [Lab 4: NVA Scalability](#lab4)

- [Lab 5: Using the Azure LB for return traffic](#lab5)

- [Lab 6: Incoming Internet traffic protected by the NVA](#lab6)

- [Lab 7: Advanced HTTP-based probes](#lab7)

- [Lab 8: NVAs in a VMSS (work in progress)](#lab8)

**[Part 3: VPN gateway](#part3)**

- [Lab 9: Spoke-to-Spoke communication over the VPN gateway](#lab9)

- [Lab 10: VPN connection to the Hub Vnet](#lab10)

[End the lab](#end)

[Conclusion](#conclusion)

[References](#ref)


# Objectives and initial setup <a name="objectives"></a>

This document contains a lab guide that helps to deploy a basic environment in Azure that allows to test some of the functionality of the integration between Azure and Ansible.
Before starting with this account, make sure to fulfill all the requisites:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
-	If you are using Windows 10, you can install Bash shell on Ubuntu on Windows (http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10).
-	Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 

The labs cover: 
-	Introduction to Azure networking
-	Deployment of multi-vnet Hub and Spoke design
-	Traffic filtering in Azure with firewalls
-	Microsegmentation using firewalls
-	Scaling out NVAs with load balancing and SNAT
-	Advanced probes for Azure Load Balancers
-	Linux custom routing

**Important note:**
This lab has been modified to improve the user's experience. Testing with Virtual Network Gateways has been taken all the way to the end, since just the gateway deployment can take up to 45 minutes. The activities in this lab has been divided in 3 sections:

-	Section 1: Hub and Spoke networking (around 60 minutes)
-	Section 2: NVA scalability with Azure Load Balancer (around 90 minutes)
-	Section 3: using VPN gateway for spoke-to-spoke connectivity and site-to-site access (around 60 minutes, not including the time required to provision the gateways)

 
Along this lab some variables will be used, that might (and probably should) look different in your environment. This is the variables you need to decide on before starting with the lab. Notice that the VM names are prefixed by a (not so) random number, since these names will be used to create DNS entries as well, and DNS names need to be unique.

| **Description** | **Value used in this lab guide** |
| --- | --- |
| Azure resource group | vnetTest |
| Username for provisioned VMs and NVAs | lab-user |
| Password for provisioned VMs and NVAs | Microsoft123! |
| Azure region | westeuropa |


As tip, if you want to do the VPN lab, it might be beneficial to run the commands in [Lab9](#lab9) Step1 as you are doing the previous labs, so that you don’t need to wait for 45 minutes (that is more or less the time it takes to provision VPN gateways) when you arrive to [Lab9](#lab9).
 
## Introduction to Azure Networking <a name="intro"></a>

Microsoft Azure has established as one of the leading cloud providers, and part of Azure's offering is Infrastructure as a Service (IaaS), that is, provisioning raw data center infrastructure constructs (virtual machines, networks, storage, etc), so that any application can be installed on top.

An important part of this infrastructure is the network, and Microsoft Azure offers multiple network technologies that can help to achieve the applications' business objectives: from VPN gateways that offer secure network access to load balancers that enable application (and network, as we will see in this lab) scalability.

Some organizations have decided to complement Azure Network offering with Network Virtual Appliances (NVAs) from traditional network vendors. This lab will focus on the integration of these NVAs, and we will take as example an open source firewall, that will be implemented with iptables running on top of an Ubuntu VM with 2 network interfaces. This will allow to highlight some of the challenges of the integration of this sort of VMs, and how to solve them.

At the end of this guide you will find a collection of useful links, but if you don’t know where to start, here is the home page for the documentation for Microsoft Azure Networking: https://docs.microsoft.com/en-us/azure/#pivot=services&panel=network.

The second link you want to be looking at is this document, where Hub and Spoke topologies are discussed: https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke. 

If you find any issue when running through this lab or any error in this guide, please open a Github issue in this repository, and we will try to fix it. Enjoy!
 
# Part 0: First steps <a name="part0"></a>

## Lab 0: Initialize Azure Environment <a name="lab0"></a>

**Step 1.** Log into your system.

**Step 2.** If you don’t have a valid Azure subscription, you can create a free Azure subscription in https://azure.microsoft.com/en-us/free. If you have received a voucher code for Azure, go to https://www.microsoftazurepass.com/Home/HowTo for instructions on how to redeem it.  

**Step 3.** Open a terminal window. Here you have different options:

* If you are using the Azure CLI on Windows, you can press the Windows key in your keyboard, then type `cmd` and hit the Enter key. You might want to maximize the command Window so that it fills your desktop.

* If you are using the Azure CLI on the Linux subsystem for Windows, open your Linux console

* If you are using Linux or Mac, you probably do not need me to tell me how to open a Terminal window

* Alternatively you can use the Azure shell, no matter on which OS you are working. Open the URL https://shell.azure.com on a Web browser, and after authenticating with your Azure credentials you will get to an Azure Cloud Shell. In this lab we will use the Azure CLI (and not Powershell), so make sure you select the Bash shell. You can optionally use tmux, as this figure shows:  

**Figure.** Cloud shell with two tmux panels

![Cloud Shell Image](az_shell_tmux.PNG "Cloud Shell with 2 tmux panels")


**Step 4.** Create a new resource group, where we will place all our objects (so that you can easily delete everything after you are done). The last command also sets the default resource group to the newly created one, so that you do not need to download it.

You can copy the following command from this guide with Ctrl-C, and paste it into your terminal window using the Command menu (lighting bolt), and select Paste | Paste Clipboard Text

<pre lang="...">
<b>az login</b>
To sign in, use a web browser to open the page https://aka.ms/devicelogin and enter the code XXXXXXXXX to authenticate.
</pre>

The `az login` command will provide you a code, that you need to introduce (over copy and paste) in the web page http://aka.ms/devicelogin. Open an Internet browser, go to this URL, and after introducing the code, you will need to authenticate with credentials that are associated to a valid Azure subscription. After a successful login, you can enter the following two commands back in the terminal window in order to create a new resource group, and to set the default resource group accordingly.

<pre lang="...">
az group create --name vnetTest --location westeurope
</pre>

You might get an error message in the previous message if you have multiple subscriptions. If that is the case, you can select the subscription where you want to deploy the lab with the command `az account set --subscription <your subscription GUID>`. If you did not get any error message, you can safely ignore this paragraph.

<pre lang="...">
az configure --defaults group=vnetTest
</pre>

**Step 5.** Deploy the master template that will create our initial network configuration. The syntax here depends on the operating system you are using. For example, for **Windows** use this command:

<pre lang="...">
az group deployment create --name netLabDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/NetworkingLab_master.json --resource-group vnetTest --parameters "{\"adminPassword\":{\"value\":\"Microsoft123!\"}, \"location2ary\":{\"value\": \"westus2\"}, \"location2aryVnets\":{\"value\": [3]}}" 
</pre>

Or alternatively use the following command if you are using a **Linux** operative system:

<pre lang="...">
az group deployment create --name netLabDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/NetworkingLab_master.json --resource-group vnetTest --parameters '{"adminPassword":{"value":"Microsoft123!"}, "location2ary":{"value": "westus2"}, "location2aryVnets":{"value": [3]}}'
</pre>

**Note**: the previous command will deploy 5 vnets, one of them (vnet 3) in an alternate location. The goal of deploying this single vnet in a different location is to include **global vnet peering** in this lab. Should you not have access to locations where global vnet peering is available (such as West Europe and West US 2 used in the examples), you can just deploy the previous templates without the parameters `location2ary` and `location2aryVnets`, which will deploy or vnets into the same location as the resource group.


**Step 6.** Since the previous command will take a while (around 15 minutes), open another command window (see Step 3 for detailed instructions) to monitor the deployment progress. Note you might have to login in this second window too:

<pre lang="...">
<b>az group deployment list -o table</b>
Name               Timestamp                         State
-----------------  --------------------------------  ---------
Name               Timestamp                         State
-----------------  --------------------------------  ---------
myVnet5gwPip       2017-06-29T19:15:28.227920+00:00  Succeeded
myVnet4gwPip       2017-06-29T19:15:31.617920+00:00  Succeeded
myVnet5-vm1-nic    2017-06-29T19:15:38.468886+00:00  Succeeded
myVnet1VpnGw       2017-06-29T19:15:38.565418+00:00  Succeeded
myVnet5VpnGw       2017-06-29T19:15:39.056567+00:00  Succeeded
myVnet3-vm1-nic    2017-06-29T19:15:39.269138+00:00  Succeeded
myVnet4-vm1-nic    2017-06-29T19:15:39.509990+00:00  Succeeded
myVnet2VpnGw       2017-06-29T19:15:40.576390+00:00  Succeeded
myVnet2-vm1-nic    2017-06-29T19:15:41.003741+00:00  Succeeded
myVnet1-vm1-nic    2017-06-29T19:15:41.143406+00:00  Succeeded
myVnet4VpnGw       2017-06-29T19:15:42.608290+00:00  Succeeded
myVnet3VpnGw       2017-06-29T19:15:44.467581+00:00  Succeeded
myVnet3-vm         2017-06-29T19:20:21.195625+00:00  Succeeded
myVnet4-vm         2017-06-29T19:20:21.856738+00:00  Succeeded
myVnet5-vm         2017-06-29T19:20:38.720152+00:00  Succeeded
myVnet-template-3  2017-06-29T19:20:42.269630+00:00  Succeeded
myVnet-template-4  2017-06-29T19:20:42.581238+00:00  Succeeded
myVnet1-vm         2017-06-29T19:20:42.663423+00:00  Succeeded
myVnet-template-5  2017-06-29T19:20:55.790429+00:00  Succeeded
myVnet-template-1  2017-06-29T19:20:59.148149+00:00  Succeeded
myVnet2-vm         2017-06-29T19:21:11.406220+00:00  Succeeded
myVnet-template-2  2017-06-29T19:21:29.787517+00:00  Succeeded
vnets              2017-06-29T19:21:32.490251+00:00  Succeeded
vnet5Gw            2017-06-29T19:21:52.630513+00:00  Succeeded
vnet4Gw            2017-06-29T19:21:53.090784+00:00  Succeeded
linuxnva-1-nic0    2017-06-29T19:21:56.417810+00:00  Succeeded
UDRs               2017-06-29T19:21:57.487004+00:00  Succeeded
linuxnva-2-nic0    2017-06-29T19:21:58.322935+00:00  Succeeded
myVnet1-vm2-nic    2017-06-29T19:21:58.354766+00:00  Succeeded
linuxnva-2-nic1    2017-06-29T19:21:59.328610+00:00  Succeeded
linuxnva-1-nic1    2017-06-29T19:21:59.490821+00:00  Succeeded
nva-slb-int        2017-06-29T19:22:03.146781+00:00  Succeeded
hub2spoke2         2017-06-29T19:22:09.140223+00:00  Succeeded
hub2spoke3         2017-06-29T19:22:10.229240+00:00  Succeeded
hub2spoke1         2017-06-29T19:22:12.980700+00:00  Succeeded
AzureLB            2017-06-29T19:22:15.587843+00:00  Succeeded
nva-slb-ext        2017-06-29T19:22:18.507575+00:00  Succeeded
vnet1subnet1vm2    2017-06-29T19:26:53.109076+00:00  Succeeded
nva                2017-06-29T19:29:24.679832+00:00  Succeeded
netLabDeployment   2017-06-29T19:29:26.491546+00:00  Succeeded
</pre>

**Note:** You might see other resource names when using your template, since newer lab versions might have different object names

## Lab 1: Explore the Azure environment <a name="lab1"></a> 

**Step 1.** You don’t need to wait until all objects in the template have been successfully deployed (although it would be good, to make sure that everything is there). In your second terminal window, start exploring the objects created by the ARM template: vnets, subnets, VMs, interfaces, public IP addresses, etc. Save the output of these commands (copying and pasting to a text file for example).

You can see some diagrams about the deployed environment here, so that you can interpret better the command outputs.

Note that the output of these commands might be different, if the template deployment from lab 0 is not completed yet.

![Architecture Image](figure01.png "Overall vnet diagram")
 
**Figure 1.** Overall vnet diagram

![Architecture Image](figure02.png "Subnet design")

**Figure 2.** Subnet design of every vnet

<pre lang="...">
<b>az network vnet list -o table</b>
Location    Name     ProvisioningState    ResourceGroup    ResourceGuid
----------  -------  -------------------  ---------------  -------------
westeurope  myVnet1  Succeeded            vnetTest         1d20ba9a... 
westeurope  myVnet2  Succeeded            vnetTest         43ca80d0...
westus2     myVnet3  Succeeded            vnetTest         4837a481...
westeurope  myVnet4  Succeeded            vnetTest         72a82a72...
westeurope  myVnet5  Succeeded            vnetTest         96e5f9c5...      
</pre>

**Note:** Some columns of the ouput above have been removed for clarity purposes.

<pre lang="...">
<b>az network vnet subnet list --vnet-name myVnet1 -o table</b>
AddressPrefix    Name            ProvisioningState    ResourceGroup
---------------  --------------  -------------------  ---------------
10.1.0.0/24      GatewaySubnet   Succeeded            vnetTest
10.1.1.0/24      myVnet1Subnet1  Succeeded            vnetTest
10.1.2.0/24      myVnet1Subnet2  Succeeded            vnetTest
10.1.3.0/24      myVnet1Subnet3  Succeeded            vnetTest
</pre>

<pre lang="...">
<b>az vm list -o table</b>
Name         ResourceGroup    Location
-----------  ---------------  ----------
linuxnva-1   vnetTest         westeurope
linuxnva-2   vnetTest         westeurope
myVnet1-vm1  vnetTest         westeurope
myVnet1-vm2  vnetTest         westeurope
myVnet2-vm1  vnetTest         westeurope
myVnet3-vm1  vnetTest         westeurope
myVnet4-vm1  vnetTest         westeurope
myVnet5-vm1  vnetTest         westeurope
</pre>

<pre lang="...">
<b>az network nic list -o table</b>
EnableIpForwarding    Location    MacAddress         Name
--------------------  ----------  -----------------  -------
True                  westeurope  00-0D-3A-28-F8-F9  linuxnva-1-nic0  
True                  westeurope  00-0D-3A-28-F0-3A  linuxnva-1-nic1  
True                  westeurope  00-0D-3A-28-24-73  linuxnva-2-nic0  
True                  westeurope  00-0D-3A-28-2A-28  linuxnva-2-nic1
                      westeurope  00-0D-3A-2A-48-AF  myVnet1-vm1-nic
                      westeurope  00-0D-3A-28-2C-8C  myVnet1-vm2-nic
                      westeurope  00-0D-3A-2A-4A-DE  myVnet2-vm1-nic
                      westus2     00-0D-3A-2A-46-DE  myVnet3-vm1-nic
                      westeurope  00-0D-3A-2A-4F-EA  myVnet4-vm1-nic
                      westeurope  00-0D-3A-2A-47-BC  myVnet5-vm1-nic      
</pre>

**Note:** Some columns of the ouput above have been removed for clarity purposes.


<pre lang="...">
<b>az network public-ip list --query '[].[name,ipAddress]' -o table</b>
Column1              Column2
-------------------  ---------------
linuxnva-slbPip-ext  5.6.7.8
myVnet1-vm2-pip      1.2.3.4
vnet4gwPip
vnet5gwPip
</pre>

**Note:** You might have notice the --query option in the command above. The reason is that in newer CLI releases, the standard command to list public IP addresses does not show the IP addresses themselves, interestingly enough. With the --query option you can force the Azure CLI to show the information you are interested in. Furthermore, the public IP addresses in the table are obviously not the ones you will see in your environment.

As you see, we have a single public IP address allocated to myVnet1-vm2. We will use this VM as jump host for the lab.

**Step 2.** Using the public IP address from the previous step open an SSH terminal (putty on windows, an additional terminal on Mac/Linux, a new tmux panel in the cloud shell, etc) and connect to the jump host. If you did not modified the ARM templates used to provision the environment, the user is lab-user, and the password Microsoft123!

<pre lang="...">
<b>ssh lab-user@1.2.3.4</b>
The authenticity of host '1.2.3.4 (1.2.3.4)' can't be established.
ECDSA key fingerprint is SHA256:FghxuVL+BuKux27Homrsm3nYjb7o/gE/SfFoiRYl5Y4.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '1.2.3.4' (ECDSA) to the list of known hosts.
lab-user@1.2.3.4's password:
Welcome to Ubuntu 16.04.4 LTS (GNU/Linux 4.13.0-1018-azure x86_64)
... ouput omitted...
lab-user@myVnet1-vm2:~$
</pre>

**Note:** do not forget to use the actual public IP address of your environment instead of the sample value of 1.2.3.4. Make sure to use the IP address corresponding to `myVnet1-vm2-pip`, not the one assigned to linuxnva-slbPip-ext.

**Step 3.** Connect to the Azure portal (http://portal.azure.com) and locate the resource group that we have just created (called &#39;vnetTest&#39;, if you did not change it). Verify the objects that have been created and explore their properties and states.


![Architecture Image](figureRG.png "Resource Group in Azure Portal")

**Figure 4:** Azure portal with the resource group created for this lab

**Note:** you might want to open two new additional command prompt windows (or tmux panels) and launch the two commands from Lab 8, Step 1. Each of those commands (can be run in parallel) will take around 45 minutes, so you can leave them running while you proceed with Labs 2 through 7. If you are not planning to run Labs 8-9, you can safely ignore this paragraph.


# PART 1: Hub and Spoke Networking <a name="part1"></a>
 
## Lab 2: Spoke-to-Spoke Communication over an NVA <a name="lab2"></a>

In some situations you would want some kind of security between the different Vnets. Although this security can be partially provided by Network Security Groups, certain organizations might require some more advanced filtering functionality such as the one that firewalls provide.
In this lab we will insert a Network Virtual Appliance in the communication flow. Typically these Network Virtual Appliance might be a next-generation firewall of vendors such as Barracuda, Checkpoint, Cisco or Palo Alto, to name a few, but in this lab we will use a Linux machine with 2 interfaces and traffic forwarding enabled. For this exercise, the firewall will be inserted as a &#39;firewall on a stick&#39;, that is one single interface will suffice.

![Architecture Image](figure04.png "Spoke-to-spoke and NVAs")

**Figure 5.** Spoke-to-spoke traffic going through an NVA

**Step 1.** In the Ubuntu VM acting as firewall iptables have been configured by means of a Custom Script Extension. This extension downloads a script from a public repository (the Github repository for this lab) and runs it on the VM on provisioning time. Verify that the NVAs have successfully registered the extensions with this command (look for the ProvisioningState column):

<pre lang="...">
<b>az vm extension list --vm-name linuxnva-1 -o table</b>
AutoUpgradeMinorVersion    Location    Name                 ProvisioningState
-------------------------  ----------  -------------------  -----------------
True                       westeurope  installcustomscript  Succeeded        
</pre>

**Step 2.** From your jump host ssh session connect to myVnet1-vm1 using the credentials that you specified when deploying the template, and verify that you have connectivity to the second VM in vnet1.

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.1.4</b>
The authenticity of host '10.1.1.4 (10.1.1.4)' can't be established.
ECDSA key fingerprint is SHA256:y4T92R4Qd968bf1ElHUazOvXLidj0RmgDOb4wxfpe7s.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '10.1.1.4' (ECDSA) to the list of known hosts.
lab-user@10.1.1.4's password:
Welcome to Ubuntu 16.04.4 LTS (GNU/Linux 4.13.0-1018-azure x86_64)
<i>...Output omitted...</i>
lab-user@myVnet1-vm1:~$
</pre>
 
The username and password were specified at creation time (that long command that invoked the ARM template). If you did not change the parameters, the username is &#39;lab-user&#39; and the password &#39;Microsoft123!&#39; (without the quotes).

**Step 3.** Try to connect to the private IP address of the VM in vnet2 over SSH. We can use the private IP address, because now we are inside of the vnet.

<pre lang="...">
lab-user@myVnet1-vm1:~$ <b>ssh 10.2.1.4</b>
ssh: connect to host 10.2.1.4 port 22: Connection timed out
lab-user@myVnet1-vm1:~$
</pre>

**Note:** you do not need to wait for the "ssh 10.2.1.4" command to time out if you do not want to. Besides, if you are wondering why we are not testing with a simple ping, the reason is because the NVAs are preconfigured to drop ICMP traffic, as we will see in later labs.

**Step 4.** Back in the command prompt window where you are running the Azure CLI, verify that the involved subnets (myVnet1-Subnet1 and myVnet2-Subnet1) do not have any routing table attached:

<pre lang="...">
<b>az network vnet subnet show --vnet-name myVnet1 -n myVnet1Subnet1 --query routeTable</b>
</pre>

**Note:** You should get no output out of the previous command

**Step 5.** Create a custom route table named "vnet1-subnet1", and another one called "vnet2-subnet1":

<pre lang="...">
<b>az network route-table create --name vnet1-subnet1</b>
{
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1",    
  "location": "westeurope",
  "name": "vnet1-subnet1",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest",
  "routes": [],       
  "subnets": null,    
  "tags": null,       
  "type": "Microsoft.Network/routeTables"
}
</pre>

<pre lang="...">
<b>az network route-table create --name vnet2-subnet1</b>
{
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1",
  "location": "westeurope",
  "name": "vnet2-subnet1",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest",
  "routes": [],
  "subnets": null,
  "tags": null,
  "type": "Microsoft.Network/routeTables"
}
</pre>

**Step 6.** Verify that the route tables are successfully created:

<pre lang="...">
<b>az network route-table list -o table</b>
Location    Name           ProvisioningState    ResourceGroup
----------  -------------  -------------------  ---------------
westeurope  vnet1-subnet1  Succeeded            vnetTest
westeurope  vnet2-subnet1  Succeeded            vnetTest
</pre>

**Step 7.** Now attach custom route tables to both subnets involved in this example (Vnet1Subnet1, Vnet2Subnet2):

<pre lang="...">
<b>az network vnet subnet update -n myVnet1Subnet1 --vnet-name myVnet1 --route-table vnet1-subnet1</b>
<i>Output omitted</i>
</pre>

<pre lang="...">
<b>az network vnet subnet update -n myVnet2Subnet1 --vnet-name myVnet2 --route-table vnet2-subnet1</b>
<i>Output omitted</i>
</pre>

**Step 8.** And now you can check that the subnets are associated with the right routing tables:

<pre lang="...">
<b>az network vnet subnet show --vnet-name myVnet1 -n myVnet1Subnet1 --query routeTable</b>
{
  "disableBgpRoutePropagation": null,
  "etag": null,
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1",
  "location": null,
  "name": null,
  "provisioningState": null,
  "resourceGroup": "vnetTest",
  "routes": null,
  "subnets": null,
  "tags": null,
  "type": null
}
</pre>

<pre lang="...">
<b>az network vnet subnet show --vnet-name myVnet2 -n myVnet2Subnet1 --query routeTable</b>
{
  "disableBgpRoutePropagation": null,
  "etag": null,
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1",
  "location": null,
  "name": null,
  "provisioningState": null,
  "resourceGroup": "vnetTest",
  "routes": null,
  "subnets": null,
  "tags": null,
  "type": null
}</pre>

**Step 9.** Now we can tell Azure to send traffic from subnet 1 to subnet 2 over the hub vnet. Normally you would do this by sending traffic to the vnet router (that is, the L3 functionality inherent to every Azure vnet). Let’s see what happens if we try this with vnet1. In order to do so, we need to add a new route to our custom routing table with a next hop of type ´VnetLocal´:

<pre lang="...">
<b>az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-type vnetLocal --route-table-name vnet1-subnet1 -n vnet2</b>
{
  "addressPrefix": "10.2.0.0/16",
  "etag": "W/\"b18dd5db-4ff4-4de0-b69b-2de5c7f21985\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet2",
  "name": "vnet2",
  "nextHopIpAddress": null,
  "nextHopType": "VnetLocal",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

**Step 10.** You can verify that the route has been added to the routing table correctly:

<pre lang="...">
<b>az network route-table route list --route-table-name vnet1-subnet1 -o table</b>
AddressPrefix    Name                NextHopIpAddress    NextHopType      Provisioning
---------------  ------------------  ------------------  ---------------  ------------
10.2.0.0/16      vnet2                                   VnetLocal        Succeeded
</pre>

However, if we verify the routing table that has been programmed in the interface of VMs in the subnet, you can see that the next hop is actually “None”! (in other words, drop the packets):

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet1-vm1-nic</b>
<i>...Output omitted...</i>
    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "name": "vnet2",
      "nextHopIpAddress": [],
      "nextHopType": "None",
      "source": "User",
      "state": "Active"
    },
</pre>

**Note:** the previous command takes some seconds to run, since it accesses the routing entries programmed into the NIC itself. If you cannot find the route with the addressPrefix 10.2.0.0/16 (at the bottom of the output), please wait a few seconds and issue the command again, sometimes it takes some time (around 1 minute) to program the NICs in Azure.

The fact that the routes have not been properly programmed essentially means that we need a different method to send spoke-to-spoke traffic, and the native vnet router just will not cut it. For this purpose, we will use the Network Virtual Appliance (our virtual Linux-based firewall) as next-hop. In other words, you need an additional routing device (in this case the NVA, it could be the VPN gateway) other than the standard vNet routing functionality.

**Step 11.** Now we will install in each route table routes for the other side, but this time pointing to the private IP address of the Network Virtual Appliance in vnet 4. 

<pre lang="...">
<b>az network route-table route update --address-prefix 10.2.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet2</b>
{
  "addressPrefix": "10.2.0.0/16",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet2",
  "name": "vnet2",
  "nextHopIpAddress": "10.4.2.101",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
} 
</pre>

<pre lang="...">
<b>az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet1</b>
{
  "addressPrefix": "10.1.0.0/16",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1/routes/vnet1",
  "name": "vnet1",
  "nextHopIpAddress": "10.4.2.101",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
} 
</pre>

**Step 12.** We can verify what the route tables look like now, and how it has been programmed in one of the NICs associated to the subnet:

<pre lang="...">
<b>az network route-table route list --route-table-name vnet1-subnet1 -o table</b>
AddressPrefix    Name     NextHopIpAddress    NextHopType       ProvisioningState
---------------  -------  ------------------  ----------------  -------------------
10.2.0.0/16      vnet2    10.4.2.101          VirtualAppliance  Succeeded
</pre>

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet1-vm1-nic</b>
<i>...Output omitted...</i>
    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "name": "vnet2",
      "nextHopIpAddress": [
        "10.4.2.101"
      ],
      "nextHopType": "VirtualAppliance",
      "source": "User",
      "state": "Active"
    }
<i>...Output omitted...</i>
</pre>

**Note:** the previous command takes some seconds to run, since it accesses the routing programmed into the NIC. If you cannot find the route with the addressPrefix 10.2.0.0/16 (at the bottom of the output), please wait a few seconds and issue the command again, sometimes it takes some time to program the NICs in Azure

**Step 13.** And now VM1 should be able to connect to VM2 over SSH (it is normal if you are asked to confirm the identity of the VM). Note that Ping between Vnets does not work, because as we will see later, the firewall is dropping ICMP traffic:

<pre lang="...">
lab-user@myVnet1vm:~$ <b>ssh 10.2.1.4</b>
<i>...output omitted</i>
lab-user@myVnet2-vm1:~$
</pre>

**Step 14.** Does this work over global vnet peering? This is what we are going to test in this step. As you may have noticed already, Vnet3 is in a different location than the rest of the vnets, US West 2 (if you didn't change the commands to deploy the lab).

<pre lang="...">
<b>az network vnet list --query [].[name,location] -o tsv</b>
myVnet1 westeurope
myVnet2 westeurope
myVnet4 westeurope
myVnet5 westeurope
myVnet3 <b>westus2</b>
</pre>

Vnet peering is still configured and it should be in a Connected state:

<pre lang="...">
<b>az network vnet peering list -o table --vnet-name myVnet4</b>
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    Name           PeeringState    ProvisioningState    ResourceGroup    UseRemoteGateways
-----------------------  ---------------------  ---------------------------  -------------  --------------  -------------------  ---------------  -------------------
False                    False                  True                         LinkTomyVnet3  <b>Connected</b>       Succeeded            vnetTest         False
False                    False                  True                         LinkTomyVnet2  Connected       Succeeded            vnetTest         False
False                    False                  True                         LinkTomyVnet1  Connected       Succeeded            vnetTest         False
<b>az network vnet peering list -o table --vnet-name myVnet3</b>
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    Name           PeeringState    ProvisioningState    ResourceGroup    UseRemoteGateways
-----------------------  ---------------------  ---------------------------  -------------  --------------  -------------------  ---------------  -------------------
True                     False                  True                         LinkTomyVnet4  <b>Connected</b>       Succeeded            vnetTest         False
</pre>

So we can just configure the routes between Vnet3 and the rest of the spokes, exactly as explained above for Vnets in the same region. The following commands will create a new route-table for subnet1 in Vnet3 (note that it needs to be in the same region as the vnet), and route traffic to the rest of the spokes (Vnets 2 and 3) over the NVA:

<pre lang="...">
az network route-table create --name vnet3-subnet1 -l westus2
az network vnet subnet update -n myVnet3Subnet1 --vnet-name myVnet3 --route-table vnet3-subnet1
az network route-table route create --address-prefix 10.1.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet1
az network route-table route create --address-prefix 10.2.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet3-subnet1 -n vnet2
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet3
az network route-table route create --address-prefix 10.3.0.0/16 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n vnet3
</pre>

If the previous commands worked, you should be able to see now the new routes in the interface associated to the VM in Vnet3

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet3-vm1-nic</b>
<i>...Output omitted...</i>
    {
      "addressPrefix": [
        "10.1.0.0/16"
      ],
      "disableBgpRoutePropagation": false,
      "name": "vnet1",
      "nextHopIpAddress": [
        <b>"10.4.2.101"</b>
      ],
      "nextHopType": "None",
      "source": "User",
      "state": "Active"
    },    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "disableBgpRoutePropagation": false,
      "name": "vnet2",
      "nextHopIpAddress": [
        <b>"10.4.2.101"</b>
      ],
      "nextHopType": "None",
      "source": "User",
      "state": "Active"
    },
<i>...Output omitted...</i>
</pre>

And now you should be able to connect from the jump host (VM2 in Vnet1) to the VM in Vnet3:

<pre lang="...">
<b>lab-user@myVnet1-vm2:~$ ssh 10.3.1.4</b>
<i>...Output omitted...</i>
lab-user@10.3.1.4's password:
Welcome to Ubuntu 16.04.5 LTS (GNU/Linux 4.15.0-1021-azure x86_64)
<i>...Output omitted...</i>
lab-user@<b>myVnet3</b>-vm1:~$
</pre>

### What we have learnt

With peered vnets it is not enough to send traffic to the vnet in order to get spoke-to-spoke communication, but you need to steer it to an NVA (or to a VPN/ER Gateway, as we will see in a later lab) via User-Defined Routes (UDR).

UDRs can be used steer traffic between subnets through a firewall. The UDRs should point to the IP address of a firewall interface in a different subnet. This firewall could be even in a peered vnet, as we demonstrated in this lab, where the firewall was located in the hub vnet.

You can verify the routes installed in the routing table, as well as the routes programmed in the NICs of your VMs. Note that discrepancies between the routing table and the programmed routes can be extremely useful when troubleshooting routing problems.

You can use these concepts both in locally peered vnets (in the same region) as well as with globally peered vnets (in differnt regions). Note that this is the case because we are routing to an IP associated to a VM (our first NVA in this example). As later labs will show, when routing to an IP associated to a Load Balancer global peering will not work. That essentially dictates the HA method for NVAs to use today if using a hub & spoke global topologies. 


## Lab 3: Microsegmentation with an NVA

Some organizations wish to filter not only traffic between specific network segments, but traffic inside of a subnet as well, in order to reduce the probability of successful attacks spreading inside of an organization. This is what some in the industry know as &#39;microsegmentation&#39;.

![Architecture Image](figure05.png "Microsegmentation")

**Figure 6.** Intra-subnet NVA-based filtering, also known as “microsegmentation”

**Step 1.** In order to be able to test the topology above, we will our jump host, which happens to be the second VM in myVnet1-Subnet1 (vnet1-vm2). We need to instruct all VMs in this subnet to send local traffic to the NVAs as well. First, let us verify that both VMs can reach each other. Exit the session from Vnet2-vm1 and Vnet1-vm1 to come back to Vnet1-vm2, and verify that you can reach its neighbor VM in 10.1.1.4:

<pre lang="...">
lab-user@myVnet2-vm1:~$ <b>exit</b>
logout
Connection to 10.2.1.4 closed.
lab-user@myVnet1-vm1:~$ <b>exit</b>
logout
Connection to 10.1.1.4 closed.
lab-user@myVnet1-vm2:~$ <b>ping 10.1.1.4</b>
PING 10.1.1.4 (10.1.1.4) 56(84) bytes of data.
64 bytes from 10.1.1.4: icmp_seq=1 ttl=64 time=0.612 ms
64 bytes from 10.1.1.4: icmp_seq=2 ttl=64 time=3.62 ms
64 bytes from 10.1.1.4: icmp_seq=3 ttl=64 time=2.71 ms
64 bytes from 10.1.1.4: icmp_seq=4 ttl=64 time=0.748 ms
^C
--- 10.1.1.4 ping statistics ---
4 packets transmitted, 4 received, <b>0% packet loss</b>, time 3002ms
rtt min/avg/max/mdev = 0.612/1.924/3.628/1.287 ms
lab-user@myVnet1-vm2:~$
</pre>

**Step 2.** We want to be able to control traffic flowing between the two VMs, even if they are in the same subnet. For that purpose, we want to send this traffic to our NVA (firewall). This can be easily done by adding an additional User-Defined Route to the corresponding routing table. Go back to your Azure CLI command prompt, and type this command:

<pre lang="...">
<b>az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.101 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet1-subnet1</b>
{
  "addressPrefix": "10.1.1.0/24",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet1-subnet1",
  "name": "vnet1-subnet1",
  "nextHopIpAddress": "10.4.2.101",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

**Step 3.** If you go back to the terminal with the SSH connection to the  jump host and restart the ping, you will notice that after some seconds (the time it takes Azure to program the routes you just configured in the NICs of the VMs) ping will stop working, because traffic is going through the firewalls now, configured to drop ICMP packets.

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.1.1.4</b>
PING 10.1.1.4 (10.1.1.4) 56(84) bytes of data.
64 bytes from 10.1.1.4: icmp_seq=1 ttl=64 time=2.22 ms
64 bytes from 10.1.1.4: icmp_seq=2 ttl=64 time=0.847 ms
...
64 bytes from 10.1.1.4: icmp_seq=30 ttl=64 time=0.762 ms
64 bytes from 10.1.1.4: icmp_seq=31 ttl=64 time=0.689 ms
64 bytes from 10.1.1.4: icmp_seq=32 ttl=64 time=3.00 ms
^C
--- 10.1.1.4 ping statistics ---
98 packets transmitted, 32 received, 67% packet loss, time 97132ms
rtt min/avg/max/mdev = 0.620/1.160/4.284/0.766 ms
lab-user@myVnet1-vm1:~$
</pre>

**Step 4.** To verify that routing is still correct, you can now try SSH instead of ping. The fact that SSH works, but ping does not, demonstrates that the traffic now goes through the NVA (configured to allow SSH, but to drop ICMP packets).

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.1.4</b>
<i>Output omitted</i>
lab-user@myVnet1-vm1:~$
</pre>


### What we have learnt

UDRs can be used not only to steer traffic between subnets through a firewall, but to steer traffic even between hosts inside of one subnet through a firewall too. This is due to the fact that Azure routing is not performed at the subnet level, as in traditional networks, but at the NIC level. This enables a very high degree of granularity

As a side remark, in order for these microsegmentation designs to work, the firewall needs to be in a separate subnet from the VMs themselves, otherwise the UDR will provoke a routing loop.


# PART 2: NVA High Availability <a name="part2"></a>

 
## Lab 4: NVA scalability <a name="lab4"></a>

If all traffic is going through a single Network Virtual Appliance, chances are that it is not going to scale. Whereas you could scale it up by resizing the VM where it lives, not all VM sizes are supported by NVA vendors. Besides, scale out provides a more linear way of achieving additional performance, potentially even increasing and decreasing the number of NVAs automatically via scale sets.
In this lab we will use two NVAs and will send the traffic over both of them by means of an Azure Load Balancer. Since return traffic must flow through the same NVA (since firewalling is a stateful operation and asymmetric routing would break it), the firewalls will source-NAT traffic to their individual addresses.

![Architecture Image](figure08.png "Load Balancer for NVA Scale Out")

**Figure 7.** Load balancer for NVA scale out 

Note that no clustering function is required in the firewalls, each firewall is completely unaware of the others.

A different model that we are not going to explore in this lab is based on UDR (User-Defined Route) automatic modification. The concept is simple: if you have the setup from Lab 3, you have UDRs pointing to an NVA. If that NVA went down, you could have an automatic mechanism to change the UDRs so that they point to a second NVA. After the Azure Load Balancer supports the HA Ports feature, what we will explore later in this lab, most NVA vendors have moved away from the UDR-based HA model, that is why we will not explore it in this lab. However, not all Azure regions have standard Load Balancers (required for the HA Ports feature) at the time of this writing, so the UDR-based model might still be relevant in some situations.

**Step 1.** First, go to your Windows command window to verify that both an internal and an external load balancer have been deployed. In this lab we will only use the internal load balancer:

<pre lang="...">
<b>az network lb list -o table</b>
Location    Name              ProvisioningState    ResourceGroup
----------  -------           -------------------  ---------------
westeurope  linuxnva-slb-ext  Succeeded            vnetTest
westeurope  linuxnva-slb-int  Succeeded            vnetTest        
</pre>

**Step 2.** We will need the name of the backend farm of the load balancer for later steps:

<pre lang="...">
<b>az network lb show -n linuxnva-slb-int --query backendAddressPools[].name -o tsv</b>
linuxnva-slbBackend-int
</pre>

**Step 3.** Now that we now the backend pool where we want to add our NVAs, we can use this command to do so. Note that although intuitively you might think that this process is performed at the LB level, it is actually a NIC operation. In other words, you do not add the NIC to the LB backend pool, but the backend pool to the NIC: 

<pre lang="...">
<b>az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int</b>
<i>Output omitted</i>
</pre>

And a similar command for our second Linux-based NVA appliance:

<pre lang="...">
<b>az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic0 --address-pool linuxnva-slbBackend-int --lb-name linuxnva-slb-int</b>
<i>Output omitted</i>
</pre>

**Note:** the previous commands will require some minutes to run

You can verify that the pool has been successfully added to both NICs with this command:

<pre lang="...">
<b>az network lb address-pool list --lb-name linuxnva-slb-int -o table --query [].backendIpConfigurations[].id</b>
Result
---------------------------------------------------
/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/networkInterfaces/linuxnva-1-nic0/ipConfigurations/linuxnva-1-nic0-ipconfig0
/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/networkInterfaces/linuxnva-2-nic0/ipConfigurations/linuxnva-2-nic0-ipconfig0
</pre>


**Step 4.** Let us verify the LB's rules. As you can see, there is a load balancing rule for ALL TCP/UDP (Protocol is `All`) ports, so it will forward all TCP/UDP traffic to the backends:

<pre lang="...">
<b>az network lb rule list --lb-name linuxnva-slb-int -o table</b>
  BackendPort    FrontendPort    LoadDistribution    Name         Protocol
-------------  --------------    ------------------  -----------  --------
            0               0    Default             HARule            All       
</pre>

**Note:** HA ports work only on standard Load Balancers. In order to verify which SKU the load balancers have, you can use issue this command:

<pre lang="...">
<b>az network lb list --query [].[name,sku.name] -o table</b>
Column1           Column2
----------------  ---------
linuxnva-slb-ext  Standard
linuxnva-slb-int  Standard
</pre>


**Step 5.** Verify with the following command the fronted IP address that the load balancer has been preconfigured with (with the ARM template in the very first lab):

<pre lang="...">
<b>az network lb frontend-ip list --lb-name linuxnva-slb-int -o table</b>
Name              PrivateIpAddress    PrivateIpAllocationMethod 
----------------  ------------------  -------------------------
myFrontendConfig  10.4.2.100          Static                   
</pre>

**Note:** some columns have been removed from the previous output for simplicity

**Step 6.** We must change the next-hop for the UDRs that are required for the communication. We need to point them at the virtual IP address of the load balancer (10.4.2.100). Remember that we configured that route to point to 10.4.2.101, the IP address of one of the firewalls. We will take the route for microsegmentation, in order to test the connection depicted in the picture above:

<pre lang="...">
<b>az network route-table route update --route-table-name vnet1-subnet1 -n vnet1-subnet1 --next-hop-ip-address 10.4.2.100</b>
<i>Output omitted</i>
</pre>

At this point communication between the VMs should be possible, flowing through the NVA. Note that ICMP will still not work, but in this case, this is due to the fact that at this point in time, the Azure Load Balancer is not able to balance ICMP traffic, just TCP or UDP traffic (as configured by the load balancing rules, that require a TCP or a UDP port), so Pings do not even reach the NVAs.
If you go back to the Putty window, you can verify that ping to the neighbor VM in the same subnet still does not work, but SSH does.

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.1.1.4</b>
PING 10.1.1.4 (10.1.1.4) 56(84) bytes of data.
^C
--- 10.1.1.4 ping statistics ---
4 packets transmitted, 0 received, <b>100% packet loss</b>, time 1006ms
</pre>

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.1.4</b>
lab-user@10.1.1.4's password:
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
lab-user@myVnet1-vm1:~$
</pre>

**Step 7.** Observe the source IP address that the destination machine sees. This is due to the source NAT that firewalls do, in order to make sure that return traffic from myVnet1-vm2 goes through the NVA as well:

<pre lang="...">
lab-user@ myVnet1-vm2:~$ who
lab-user pts/0        2017-03-23 23:41 (<b>10.4.2.101</b>)
</pre>

**Note:** if you see multiple SSH sessions, you might want to kill them, so that you only have one. You can get the process IDs of the SSH sessions with the command ps -ef | grep sshd, and you can kill a specific process ID with the command kill -9 process_id_to_be_killed. Obviously, if you happen to kill the session over which you are currently connected, you will have to reconnect again.

**Step 8.** This is expected, since firewalls are configured to source NAT the connections outgoing on that interface. Now open another SSH window/panel, and connect from the jump host to the NVA. If in the `who` command you saw the IP address 10.4.2.101. Remember that the username is still &#39;lab-user&#39;, the password &#39;Microsoft123!&#39; (without the quotes). After connecting to the firewall, you can display the NAT configuration with the following command:

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.4.2.101</b>
lab-user@10.4.2.101's password:
<i>...Output omitted...</i>
lab-user@linuxnva-1:~$
lab-user@linuxnva-1:~$ <b>sudo iptables -L -t nat</b>
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
<b>MASQUERADE </b> all  --  anywhere             anywhere
<b>MASQUERADE </b> all  --  anywhere             anywhere
</pre>

**Note:** the Linux machines that we use as firewalls in this lab have the Linux package "iptables" installed to work as firewall. A tutorial of iptables is out of the scope of this lab guide. Suffice to say here that the word "MASQUERADE" means to translate the source IP address of packets and replace it with its own interface address. In other words, source-NAT. There are two MASQUERADE entries, one per each interface of the NVA. You can see to which interface the entries refer to with the command `sudo iptables -vL -t nat`

**Step 9.** We will simulate a failure of the NVA where the connection is going through (in this case 10.4.2.101, linuxnva-1). First of all, verify that both ports 1138 (used by the internal load balancer of this lab scenario) and 1139 (that could be used by the external load balancer) are open:

<pre lang="...">
lab-user@linuxnva-1:~$ <b>nc -zv -w 1 127.0.0.1 1138-1139</b>
Connection to 127.0.0.1 1138 port [tcp/*] succeeded!
Connection to 127.0.0.1 1139 port [tcp/*] succeeded!
</pre>

**Note:** in this example we use the Linux command nc (aka netcat) to open TCP connections to those two ports
The process answering to TCP requests on those ports is netcat (represented by &#39;nc&#39;), as you can see with netstat:

<pre lang="...">
lab-user@linuxnva-1:~$ <b>sudo netstat -lntp</b>
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address  Foreign Address  State    PID/Program
tcp        0      0 0.0.0.0:<b>1138</b>   0.0.0.0:*        LISTEN   1783/<b>nc</b>
tcp        0      0 0.0.0.0:<b>1139</b>   0.0.0.0:*        LISTEN   1782/<b>nc</b>
tcp        0      0 0.0.0.0:22     0.0.0.0:*        LISTEN   1587/sshd
tcp6       0      0 :::80          :::*             LISTEN   11730/apache2
tcp6       0      0 :::22          :::*             LISTEN   1587/sshd
</pre>

Verify that the internal load balancer is actually using a TCP probe on port 1138:

<pre lang="...">
<b>az network lb probe list --lb-name linuxnva-slb-int -o table</b>
 IntervalInSeconds  Name       NumberOfProbes    Port  Protocol    ProvisioningState    ResourceGroup
-------------------  -------  ----------------  ------  ----------  -------------------  ---------------
                 15  myProbe                 2    <b>1138  Tcp</b>         Succeeded            vnetTest
</pre>

**Step 10.** Now we want to take out the firewall out of the load balancer rotation. There are many ways to do that, but in this lab we will do it with NSGs, for multiple reasons. First, because it does not imply shutting down interfaces or virtual machines, since we control the NSG from outside of the VM. And second, because we can :)

If you go back to the your Azure CLI terminal, you can see that there are some NSGs defined in the resource group:

<pre lang="...">
<b>az network nsg list -o table</b>
Location    Name                 ProvisioningState    ResourceGroup    ResourceGuid
----------  -------------------  -------------------  ---------------  ------------------------------------
westeurope  linuxnva-1-nic0-nsg  Succeeded            vnetTest         e506ae9b-156d-4dd0-977b-2678691031d4
westeurope  linuxnva-2-nic0-nsg  Succeeded            vnetTest         14217c8a-c19e-4151-a79c-a6ca623b9ef2
</pre>

If you examine one of them, you will see that only the default rules are there. We can do it with linuxnva-1-nic0-nsg, for example (the other should be identical):

<pre lang="...">
<b>az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table</b>
Name         RscGroup  Prio  SourcePort  SourceAddress  SourceASG  Access  Prot  Direction  DestPort  DestAddres  DestASG
-----------  --------  ----  ----------  -------------  ---------  ------  ----  ---------  --------  ----------  -------
</pre>

**Note:** the previous output has been formated for presentation reasons

Now we can add a new rule that will prevent ALL traffic from entering the VM, including the Load Balancer probes. This effectively will have as consequence that all traffic will go through the other NVA:

<pre lang="...">
<b>az network nsg rule create --nsg-name linuxnva-1-nic0-nsg -n deny_all_in --priority 100 --access Deny --direction Inbound --protocol "*" --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*"</b>
<i>Output omitted</i>
</pre>

Now the rules in your NSG should look like this:

<pre lang="...">
<b>az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table</b>
Name         RscGroup  Prio  SourcePort  SourceAddress  SourceASG  Access  Prot  Direction  DestPort  DestAddres  DestASG
-----------  --------  ----  ----------  -------------  ---------  ------  ----  ---------  --------  ----------  -------
deny_all_in  vnetTest  100   *           *              None       Deny    *     Inbound    *         *           None
</pre>

If you now initiate another SSH connection to myVnet1-vm1 from the jump host, you will see that you are going now through the other NVA (in this example, nva-2). Note that it takes some time (defined by the probe frequency and number, per default two times 15 seconds) until the load balancer decides to take the NVA out of rotation.

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.1.4</b>
lab-user@10.1.1.5's password:
...
lab-user@myVnet1-vm2:~$
lab-user@myVnet1-vm2:~$ <b>who</b>
lab-user pts/0        2017-06-29 21:21 (10.4.2.101)
lab-user pts/1        2017-06-29 21:39 (<b>10.4.2.102</b>)
lab-user@myVnet1-vm2:~$
</pre>

**Note:** you might still see the previous connection going through 10.4.2.101, as in the previous example

**Step 11.** Let us confirm that the load balancer farm now only contains one NVA, following the process described in https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-standard-diagnostics. In the Azure Portal, navigate to the internal load balancer in the Resource Group vnetTest, and under Metrics (preview at the time of this writing) select Health Probe Status. You should be able to see something like the figure below, where only half of the probes are successful.

![LB Monitoring](lb_monitoring.PNG "Load Balancer Monitoring in Azure Portal")

**Screenshot.** Load balancer probe monitoring in Azure Portal 

**Note:** The oscillations around 50% are because of the skew in the intervals of the probes for the NVAs: in some monitoring intervals there are more probes for nva-1, in others more probes for nva-2. Play with the filtering mechanism of the graph using the Backend IP Address as filtering dimension (as in the figure above) to verify that 0% of the probes to nva-1 are successful, but 100% of the probes to nva-2 are successful.

**Step 12.** To be completely sure of our setup, let us bring the second firewall out of rotation too:

<pre lang="...">
<b>az network nsg rule create --nsg-name linuxnva-2-nic0-nsg -n deny_all_in --priority 100 --access Deny --direction Inbound --protocol "*" --source-address-prefixes "*" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "*"</b>
<i>Output omitted</i>
<b>az network nsg rule list --nsg-name linuxnva-2-nic0-nsg -o table</b>
Name         RscGroup  Prio  SourcePort  SourceAddress  SourceASG  Access  Prot  Direction  DestPort  DestAddres  DestASG
-----------  --------  ----  ----------  -------------  ---------  ------  ----  ---------  --------  ----------  -------
deny_all_in  vnetTest  100   *           *              None       Deny    *     Inbound    *         *           None
</pre>

If you had any SSH sessions opened from the jump host to any other VM, they are now broken and will have to timeout. You may want to start another SSH connection to your jump host in that case. If you try to SSH to vm1 (or to anything else going through the firewalls), it should fail (note that it takes a couple of seconds to program the NSGs into the NICs, wait like 30 seconds before trying the following command).

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.4.4</b>
ssh: connect to host 10.1.4.4 port 22: Connection timed out
</pre>

**Step 12.** In order to repair our lab, we just need to remove the NSG rules, to allow the Azure Load Balancer to discover the firewalls again:

<pre lang="...">
az network nsg rule delete -n deny_all_in --nsg-name linuxnva-1-nic0-nsg
az network nsg rule delete -n deny_all_in --nsg-name linuxnva-2-nic0-nsg
</pre>

After some seconds SSH should be working just fine once more. You can verify that the probe health is back to 100% in the Azure Portal.

**Step 13.** Let us try something more. If you remember, our Vnet3 is in a different Azure region, and hence using global peering to communicate with the spoke. In a previous exercise in this lab we had configured routing to/from Vnet3 to go through one of the NVAs. Let us change the routes between the spokes and try to send that traffic over the ILB:

<pre lang="...">
az network route-table route update --route-table-name vnet1-subnet1 -n vnet3 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet2-subnet1 -n vnet3 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet3-subnet1 -n vnet1 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance
az network route-table route update --route-table-name vnet3-subnet1 -n vnet2 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance
</pre>

After a couple of seconds, check the effective route table on the NIC belonging to the VM in Vnet3:

<pre lang="...">
 <b>az network nic show-effective-route-table -n myVnet3-vm1-nic</b>
 <i>...output omitted...</i>
    {
      "addressPrefix": [
        "10.1.0.0/16"
      ],
      "disableBgpRoutePropagation": false,
      "name": "vnet1",
      "nextHopIpAddress": [
        <b>"10.4.2.100"</b>
      ],
      "nextHopType": "<b>None</b>",
      "source": "User",
      "state": "Active"
    },    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "disableBgpRoutePropagation": false,
      "name": "vnet2",
      "nextHopIpAddress": [
        <b>"10.4.2.100"</b>
      ],
      "nextHopType": "<b>None</b>",
      "source": "User",
      "state": "Active"
    },
<i>...output omitted...</i>
</pre>

However, connectivity will not work:

<pre lang="...">
lab-user@myVnet1-vm2:~$ ssh 10.3.1.4
ssh: connect to host 10.3.1.4 port 22: <b>Connection timed out</b>
lab-user@myVnet1-vm2:~$
</pre>

This is due to the fact that at the time of this writing, you cannot have a load balancer frontend IP address as destination of an UDR over a global vnet peering, as documented [here](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview#requirements-and-constraints). Note that in the constraints listed in that doc, it is also mentioned that Allow Gateway Transit or Use Remote Gateways are not possible either.


### What we have learnt

NVAs can be load balanced with the help of an Azure Load Balancer. UDRs configured in each subnet will essentially point not to the IP address of an NVA, but to a virtual IP address configured in the LB.

The HA Ports feature of the Azure **standard** load balancer allows configuring Layer3 load balancing rules, that is, rules that will forward all UDP/TCP ports to the NVA. This is today the way most modern HA designs work, superseeding designs based on automatic UDR modification.

Another problem that needs to be solved is return traffic. With stateful network devices such as firewalls you need to prevent asymmetric routing. In other words, source-to-destination traffic needs to go through the same firewall as destination-to-source traffic (for any given TCP or UDP flow). This can be achieved by source-NATting the traffic at the NVAs, so that the destination will always send the return traffic the right way.

Lastly, we have verified that this construct works for local peerings, but globally peered vnets will not be able to access the ILB IP address because of current limitations in Azure at the time of this writing.

## Lab 5: Using the Azure LB for return traffic <a name="lab5"></a>

As we saw in the previous lab, the NVAs was source-natting (masquerading, in iptables parlour) traffic so that return traffic would always go through the same firewall that inspected the first packet. However, in some situations source-NATting is not desirable, so this lab will have a look at a variation of the previous setup without source NAT.

**Step 1.** If you go to the terminal window with your jump host, you can connect to the NVAs and disable source NAT (masquerade). Note that there are two masquerade entries, one for each interface in the NVA. The following example shows the process in nva-1, **please repeat the process for nva-2 (10.4.2.102)**. 

<pre lang="">
lab-user@myVnet1-vm2:~$ <b>ssh 10.4.2.101</b>
lab-user@10.4.2.101's password:
<i>...Output omitted...</i>
lab-user@linuxnva-1:~$ 
lab-user@linuxnva-1:~$ <b>sudo iptables -vL -t nat</b>
Chain PREROUTING (policy ACCEPT 7655 packets, 547K bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain INPUT (policy ACCEPT 204 packets, 10628 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 8524 packets, 523K bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
10517  731K MASQUERADE  all  --  any    eth0    anywhere             anywhere
 5419  325K MASQUERADE  all  --  any    eth1    anywhere             anywhere
lab-user@linuxnva-1:~$ 
lab-user@linuxnva-1:~$ <b>sudo iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE</b>
lab-user@linuxnva-1:~$ <b>sudo iptables -t nat -A POSTROUTING -o eth0 ! -d 10.0.0.0/255.0.0.0 -j MASQUERADE</b>
lab-user@linuxnva-1:~$ 
lab-user@linuxnva-1:~$ <b>sudo iptables -vL -t nat</b>
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 3 packets, 180 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain POSTROUTING (policy ACCEPT 3 packets, 180 bytes)
 pkts bytes target     prot opt in     out     source               destination
 5419  325K MASQUERADE  all  --  any    eth1    anywhere             anywhere
  405  325K MASQUERADE  all  --  any    eth0    anywhere             <b>!10.0.0.0/8</b>
</pre>

**Step 2:** Now you can go back to the jump host, connect to vm1, and verify that the source IP address has not been source-natted:

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.1.1.4</b>
lab-user@10.1.1.4's password:
<i>...Output omitted...</i>
lab-user@myVnet1-vm1:~$
lab-user@myVnet1-vm1:~$ who
lab-user pts/0        2018-07-12 11:56 (<b>10.1.1.5</b>)
</pre>

**Step 3:** Why is this working? Because the load balancing algorith in the Azure LB distributes the load equally for the traffic in both directions. In other words, if traffic from VM1 to VM2 is load balanced to NVA1, return traffic from VM2 to VM1 will be load balanced to NVA1 as well. This is the case for the default load balancing algorithm, that leverages protocol, source/destination IPs and source/destination ports. This load balancing mode is often called 5-tuple hash.

There are other load balancing algorithms, as you can see in https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-distribution-mode, such as IP Source affinity. This is actually not only based in the source IP address, but in the destination IP address too. You can change the load balancing algorithm like this:

<pre lang="...">
<b>az network lb rule show --lb-name linuxnva-slb-int -n HARule --query loadDistribution</b>
"Default"
<b>az network lb rule update --lb-name linuxnva-slb-int -n HARule --load-distribution SourceIP</b>
<i>Output omitted</i>
<b>az network lb rule show --lb-name linuxnva-slb-int -n HARule --query loadDistribution</b>
"SourceIP"
</pre>

You can bring the load balancing algorithm back to the default:

<pre lang="...">
<b>az network lb rule update --lb-name linuxnva-slb-int -n HARule --load-distribution Default</b>
<i>Output omitted</i>
<b>az network lb rule show --lb-name linuxnva-slb-int -n HARule --query loadDistribution</b>
"Default"
</pre>


Now you can test SSH connections, they should still work. Why?

### What we have learnt

Using an Azure LB for the return traffic is a viable possibility as well, since the hash-based load balancing algorithms are symmetric, meaning that for a pair of source and destination combinations it will send traffic to the same NVA.

Note that this schema is the standard mechanism to deploy active/active clusters of NVAs.


## Lab 6: Outgoing Internet traffic protected by an NVA <a name="lab6"></a>

What if we want to send all traffic leaving the vnet towards the public Internet through the NVAs? We need to make sure that Internet traffic to/from all VMs flows through the NVAs via User-Defined Routes, that NVAs source-NAT the outgoing traffic with their public IP address, and that NVAs have Internet connectivity.

You might be asking yourself whether this last point is relevant, since after all, all VMs in Azure have per default connectivity to the Internet. However, when associating a standard ILB to the NVAs we actually removed this connectivity, according to the note in https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#defaultsnat. As explained in that document, you have two alternatives in order to restore Internet connectivity:
1. Configure a public IP address for every NVA: although possible, this is often undesirable, since that would expose our NVAs to the Internet. However, this design allows to use different NICs in the NVA for internal and external connectivity. See more about this scenario [here](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#ilpip).
2. Attach an ELB to the NVAs with outbound NAT rules. This scenario is described [here](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#lb), and it is what we will use in our lab.

This figure demonstrates the concept that we will implement:

![ELB and ILB](figure_nva_elb.png "ILB and ELB together")

**Step 1.** For this test we will use VM2 in vnet2. We will insert a default route to send Internet traffic through the NVAs. First, connect from the jump host to VM2, and verify that you have Internet connectivity. You could just send a curl request to the web service `ifconfig.co`, that returns your public IP address as seen by the Web server:

<pre lang="">
lab-user@myVnet1vm2:~$ <b>ssh 10.2.1.4</b>
lab-user@10.2.1.4's password:
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
...
lab-user@myVnet3-vm1:~$ <b>curl ifconfig.co</b>
1.1.1.1
</pre>

**Note:** in your own environment you will see a public IP address other than 1.1.1.1. This IP address is not any one of the existing public IP address in our vnet (as you can see with the command `az network public-ip list --query [].[name,ipAddress] -o tsv`). This IP address is the one that the virtual network uses to source-NAT VMs without their own public IP address or external load balancer, and is unique for each vnet.

**Step 2.** Now we can redirect traffic to our NVAs, by adding an additional entry to the routing table for Vnet2-Subnet1:

<pre lang="">
<b>az network route-table route create --address-prefix 0.0.0.0/0 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet2-subnet1 -n default</b>
{
  "addressPrefix": "0.0.0.0/0",
  "etag": "W/\"13f07168-d40f-473d-9cd1-1d67464fcaf2\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet3-subnet1/routes/default",
  "name": "default",
  "nextHopIpAddress": "10.4.2.100",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

At this point, your the routing table for Vnet2-Subnet1 should look like this:

<pre lang="">
<b>az network route-table route list --route-table-name vnet2-subnet1 -o table</b>
AddressPrefix    Name     NextHopIpAddress    NextHopType       ProvisioningState    ResourceGroup
---------------  -------  ------------------  ----------------  -------------------  ---------------
10.1.0.0/16      vnet1    10.4.2.100          VirtualAppliance  Succeeded            vnetTest
0.0.0.0/0        default  10.4.2.100          VirtualAppliance  Succeeded            vnetTest
</pre>

And if we check the effective routes in the NIC for our VM in Vnet2, you should see that our custom route to the NVA has overridden the system route to the Internet:

<pre lang="">
<b>az network nic show-effective-route-table -n myVnet2-vm1-nic</b>
<i>...Output omitted...</i>
  {
      "addressPrefix": [
        "0.0.0.0/0"
      ],
      "disableBgpRoutePropagation": false,
      "name": null,
      "nextHopIpAddress": [],
      "nextHopType": "Internet",
      "source": "Default",
      "state": <b>"Invalid"</b>
    },
<i>...Output omitted...</i>
    {
      "addressPrefix": [
        <b>"0.0.0.0/0"</b>
      ],
      "disableBgpRoutePropagation": false,
      "name": "default",
      "nextHopIpAddress": [
        "10.4.2.100"
      ],
      "nextHopType": "VirtualAppliance",
      "source": "User",
      "state": <b>"Active"</b>
    }
</pre>

**Step 3.** However, Internet access will not work yet. The NVAs need connectivity to the Internet, but attaching them to a standard ILB (Internal Load Balancer) removes that connectivity. In order to grant them Internet connectivity again, we have two options: assign public IP addresses to the NVAs, or configure a standard External Load Balancer with an outbound NAT rule. Let us check that we already have an outbound NAT rule in our external Load Balancer, as well as a Frontend IP address and a backend configuration:

<pre lang="">
<b>az network lb outbound-rule list --lb-name linuxnva-slb-ext -o table</b>
AllocatedOutboundPorts    EnableTcpReset    IdleTimeoutInMinutes    Name    Protocol    ProvisioningState    ResourceGroup
------------------------  ----------------  ----------------------  ------  ----------  -------------------  ---------------
10000                     False             15                      myrule  All         Succeeded            vnetTest
</pre>

<pre lang="">
<b>az network lb address-pool list --lb-name linuxnva-slb-ext -o table</b>
Name                     ProvisioningState    ResourceGroup
-----------------------  -------------------  ---------------
<b>linuxnva-slbBackend-ext</b>  Succeeded            vnetTest
<b>az network lb frontend-ip list --lb-name linuxnva-slb-ext -o table</b>
Name              PrivateIpAllocationMethod    ProvisioningState    ResourceGroup
----------------  ---------------------------  -------------------  ---------------
myFrontendConfig  Dynamic                      Succeeded            vnetTest
</pre>

**Step 4.** Alright, we already have an ELB with an outbound rule, we just need to add the NICs of our NVAs to it.

First, let us try to add the second interface of the first NVA. As you see, this is not supported in Azure:

<pre lang="">
<b>az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic1-ipConfig --nic-name linuxnva-1-nic1 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext</b>
LB /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/loadBalancers/linuxnva-slb-ext referred to by nic /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/networkInterfaces/linuxnva-1-nic1 has outbound rules. Nic /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/networkInterfaces/linuxnva-1-nic1 is being used in a configuration that requires load balancing or public ip on secondary ipconfigs or secondary nics, or that makes use of an Any Port Protocol rule. Such a configuration is not permitted.
</pre>

Let us therefore use the same internal interface (nic0, mapped to eth0) that we have been using so far, and add the NIC from both NVAs:

<pre lang="">
az network nic ip-config address-pool add --ip-config-name linuxnva-1-nic0-ipConfig --nic-name linuxnva-1-nic0 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
az network nic ip-config address-pool add --ip-config-name linuxnva-2-nic0-ipConfig --nic-name linuxnva-2-nic0 --address-pool linuxnva-slbBackend-ext --lb-name linuxnva-slb-ext
</pre>

**Step 5.** There is one last step to be done. If you inspect the default rules of the NSG attached to the nic0 interface of the NVAs, you will find out that no traffic addressed to the Internet will be allowed:

<pre lang="">
<b>az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table --include-default</b>
Name                           Priority  SrcPortRanges  SrcAddressPrefixes   Access    Protocol    Direction    DstPortRanges   DestinationAddressPrefixes
-----------------------------  --------  -------------  ------------------   ------    --------    ---------    -------------   --------------------------
<b>AllowVnetInBound               65000     *              VirtualNetwork       Allow     *           Inbound      *               VirtualNetwork</b>
AllowAzureLoadBalancerInBound  65001     *              AzureLoadBalancer    Allow     *           Inbound      *               *
DenyAllInBound                 65500     *              *                    Deny      *           Inbound      *               *
AllowVnetOutBound              65000     *              VirtualNetwork       Allow     *           Outbound     *               VirtualNetwork
AllowInternetOutBound          65001     *              *                    Allow     *           Outbound     *               Internet
DenyAllOutBound                65500     *              *                    Deny      *           Outbound     *               *
</pre>

**Note**: the previous output has been formated for readability

We therefore need to add a new rule to permit incoming traffic which is sourced by the Vnet address space (including the peered Vnets), but addressed to the Internet:

<pre lang="">
az network nsg rule create --nsg-name linuxnva-1-nic0-nsg -n allow_vnet_internet --priority 110 --access Allow --direction Inbound --protocol "Tcp" --source-address-prefix "VirtualNetwork" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "80-80"
</pre>

<pre lang="">
<b>az network nsg rule list --nsg-name linuxnva-1-nic0-nsg -o table --include-default</b>
Name                           Priority  SrcPortRanges  SrcAddressPrefixes   Access    Protocol    Direction    DstPortRanges   DestinationAddressPrefixes
-----------------------------  --------  -------------  ------------------   ------    --------    ---------    -------------   --------------------------
<b>allow_vnet_internet            110       *              VirtualNetwork       Allow     Tcp         Inbound      80-80           *</b>
AllowVnetInBound               65000     *              VirtualNetwork       Allow     *           Inbound      *               VirtualNetwork
AllowAzureLoadBalancerInBound  65001     *              AzureLoadBalancer    Allow     *           Inbound      *               *
DenyAllInBound                 65500     *              *                    Deny      *           Inbound      *               *
AllowVnetOutBound              65000     *              VirtualNetwork       Allow     *           Outbound     *               VirtualNetwork
AllowInternetOutBound          65001     *              *                    Allow     *           Outbound     *               Internet
DenyAllOutBound                65500     *              *                    Deny      *           Outbound     *               *
</pre>


**Step 6.** We are finally done! If you test our curl command from VM2:

<pre lang="">
lab-user@myVnet2-vm1:~$ <b>curl ifconfig.co</b>
5.6.7.8
</pre>

**Note:** Observe that the public IP address that VM3 gets back from the ifconfig.co service is the public IP addresses assigned to the external Load Balancer. You can get the public IP addresses in your resource group with this command:

<pre lang="">
<b>az network public-ip list --query [].[name,ipAddress] -o tsv</b>
linuxnva-slbPip-ext  5.6.7.8
myVnet1-vm2-pip      1.2.3.4
vnet4gwPip
vnet5gwPip 
</pre>

**Note:** in the previous output you would see your own IP addresses, which will obviously defer from the ones shown in the example above.

### What we have learnt

Essentially the mechanism for redirecting traffic going from Azure VMs to the public Internet through an NVA is very similar to the problems we have seen previously in this lab. You need to configure UDRs pointing to the NVA (or to an internal load balancer that sends traffic to the NVA). 

Source NAT at the firewall will guarantee that the return traffic (destination-to-source) is sent to the same NVA that processed the initial packets (source-to-destination).

Your NSGs should allow traffic to get into the firewall and to get out from the firewall to the Internet.

Lastly, either an outbound NAT rule or public IP addresses will be required in the NVAs, since otherwise Internet access is not possible while associated to the internal load balancer. The public IP address would have had to be standard (not basic) to coexist with the internal load balancer (standard too, to support the HA port feature). However, in this lab we opted for the outbound NAT rule in an external Load Balancer, since this is a more scalable and secure way (it is not exposing your NVAs to the Internet).


 
## Lab 7: Advanced HTTP-based probes (optional)  <a name="lab7"></a>

Standard TCP probes only verify that the interface being probed answers to TCP sessions. But what if it is the other interface that has an issue? What good does it make if VMs send all traffic to a Network Virtual Appliance with a perfectly working internal interface (eth0 in our lab), but eth1 is down, and therefore that NVA has no Internet access whatsoever?

HTTP probes can be implemented for that purpose. The probes will call for an HTTP URL that will return different HTTP codes, after verifying that all connectivity for the specific NVA is OK. We will use PHP for this, and a script that pings a series of IP addresses or DNS names, both in the Vnet and the public Internet (to verify internal and external connectivity). See the file `index.php` in this repository for more details.

**Step 1.**	We need to change the probe from TCP-based to HTTP-based. From your command prompt with Azure CLI:

<pre lang="...">
<b>az network lb probe show -n myProbe --lb-name linuxnva-slb-int --query [protocol,port]</b>
[
  "Tcp",
  1138
]
<b>az network lb probe update -n myProbe --lb-name linuxnva-slb-int --protocol Http --path "/" --port 80</b>
{
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/loadBalancers/linuxnva-slb-int/probes/myProbe",
  "intervalInSeconds": 15,
  "loadBalancingRules": [
    {
      "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/loadBalancers/linuxnva-slb-int/loadBalancingRules/sshRule",
      "resourceGroup": "vnetTest"
    },
    {
      "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/loadBalancers/linuxnva-slb-int/loadBalancingRules/httpRule",
      "resourceGroup": "vnetTest"
    }
  ],
  "name": "myProbe",
  "numberOfProbes": 2,
  "port": 80,
  "protocol": "Http",
  "provisioningState": "<b>Succeeded</b>",
  "requestPath": "/",
  "resourceGroup": "vnetTest"
}
<b>az network lb probe show -n myProbe --lb-name linuxnva-slb-int --query [protocol,port]</b>
[
  "Http",
  80
]
</pre>

**Step 2.**	Verify the content that NVAs return to the probe. You can query this from any VM, for example, from our jump host Vnet1-vm2:

```
lab-user@myVnet1-vm2:~$ curl -i 10.4.2.101
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

**Step 3.**	Verify the logic of the `/var/www/html/index.php` file in each NVA VM. Connect to one of the NVAs from the jump host, and have a look at the file `/var/www/html/index.php`. As you can see, it returns the HTTP code 200 only if a list of IP addresses or DNS names is reachable. For example, if the firewall has lost internet connectivity for some reason, or connectivity to its management server, you might want to failover to the other one:

```
lab-user@myVnet1-vm2:~$ ssh 10.4.2.101
lab-user@10.4.2.101's password:
lab-user@linuxnva-1:~$
lab-user@linuxnva-1:~$ more /var/www/html/index.php
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
       $hosts = array ("bing.com", "10.1.1.4");
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
         http_response_code (299);
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

Now the probe for the internal load balancer will fail even if the internal interface is up, but for whatever reason the NVA cannot connect to the Internet, therefore enhancing the overall reliability of the solution. Advanced probes are a very powerful tool that can be used to recognize multiple problems: is a specific daemon (iptables?) running correctly, is a necessary service reachable (DNS, authentication, logging), etc.

### What we have learnt

Advanced HTTP probes can be used to verify additional information, so that firewalls are taken out of rotation whenever complex failure scenarios occur, such as the failure of an upstream interface, or a certain process not being running in the system (for example if the firewall daemon is not running).


## Lab 8: NVAs in a VMSS cluster (work in progress!) <a name="lab8"></a>

You might be wondering how to scale the NVA cluster beyond 2 appliances. Using the LB schema from previous labs, you can do it easily. But how to scale out (and back in) the NVA cluster automatically, whenever the load requires it? In this lab we are going to explore placing the NVAs in Azure Virtual Machine Scale Sets (VMSS), so that autoscaling can be accomplished.

In this lab we will deploy a VMSS containing Linux appliances as the ones we saw in the previous labs.

**Step 1.** The first thing we are going to do is to deploy a VMSS and an additional Load Balancer to our lab. You can use the ARM template in this Github repository to do so, where all values are predetermined and you only need to supply the password for the VMs:

<pre lang="...">
<b>az group deployment create --name vmssDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json --parameters '{"vmPwd":{"value":"Microsoft123!"}}'</b>
<i>Output omitted</i>
</pre>

Alternatively, if you are using the Azure CLI in a Windows OS, you can use this syntax:

<pre lang="...">
<b>az group deployment create --name vmssDeployment --template-uri https://raw.githubusercontent.com/erjosito/azure-networking-lab/master/nvaLinux_1nic_noVnet_ScaleSet.json --parameters "{\"vmPwd\":{\"value\":\"Microsoft123!\"}}"</b>
<i>Output omitted</i>
</pre>

**Step 2.** Let us have a look at the scale set that has been created:

<pre lang="...">
<b>az vmss list -o table</b>
Name       ResourceGroup    Location    Zones      Capacity  Overprovision    UpgradePolicy
---------- ---------------  ----------  -------  ----------  ---------------  ---------------
nva-vmss   vnetTest         westeurope                    2  True             Manual
</pre>


<pre lang="...">
<b>az vmss list-instances -n nva-vmss -o table</b>
  InstanceId  LatestModelApplied    Location    Name                    ProvisioningState    ResourceGroup    VmId
------------  --------------------  ----------  ----------------------  -------------------  ---------------  ------------------------------------
           1  True                  westeurope  nva-vmss_1  Succeeded            VNETTEST         178e1865-9cbe-422f-9fda-624f2852dd00
           3  True                  westeurope  nva-vmss_3  Succeeded            VNETTEST         c2c239b2-ae11-456e-958a-ff26b5b05858
</pre>

**Step 3.** Let us focus now on the new load balancer. Make sure that there is an address pool associated to the internal load balancer, and that the VMs in our scale set are associated with it:


<pre lang="...">
<b>az network lb list -o table</b>
Location    Name                   ProvisioningState    ResourceGroup    ResourceGuid
----------  ---------------------  -------------------  ---------------  ------------------------------------
westeurope  linuxnva-slb-ext       Succeeded            vnetTest         3aebcb33-7c72-428c-af7f-ef88ed1c9512
westeurope  linuxnva-slb-int       Succeeded            vnetTest         adc84d37-caa1-48ec-beef-e951b565e38a
westeurope  <b>linuxnva-vmss-slb-ext</b>  Succeeded            vnetTest         d81bd9d7-8d4a-455b-9f1e-fcb081de07aa
westeurope  <b>linuxnva-vmss-slb-int</b>  Succeeded            vnetTest         c5984c45-970b-4bec-ab94-7193f884e89b</pre>

<pre lang="...">
<b>az network lb address-pool list --lb-name linuxnva-vmss-slb-int -o table</b>
Name                          ProvisioningState    ResourceGroup
----------------------------  -------------------  ---------------
linuxnva-vmss-slbBackend-int  Succeeded            vnetTest
</pre>

<pre lang="...">
<b>az network lb address-pool show --lb-name linuxnva-vmss-slb-int --name linuxnva-vmss-slbBackend-int --query backendIpConfigurations[].id</b>
[
  "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Compute/virtualMachineScaleSets/nva-vmss/virtualMachines/0/networkInterfaces/nic0/ipConfigurations/ipconfig0",
  "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Compute/virtualMachineScaleSets/nva-vmss/virtualMachines/1/networkInterfaces/nic0/ipConfigurations/ipconfig0"
]
</pre>

**Step 4.** A very important piece of information that we need about the load balancer is its virtual IP address, since this is going to be the next-hop for our routes:

<pre lang="...">
<b>az network lb frontend-ip list --lb-name linuxnva-vmss-slb-int -o table</b>
Name              PrivateIpAddress    PrivateIpAllocationMethod    ProvisioningState    ResourceGroup
----------------  ------------------  ---------------------------  -------------------  ---------------
myFrontendConfig  <b>10.4.2.200</b>          Static                       Succeeded            vnetTest
</pre>


**Step 5.** Let us have a look at the rules configured. As you can see, the ARM template preconfigured a load balancing rule including all the ports (that is what the value of 0 means for the BackendPort and Frontendport).

<pre lang="...">
<b>az network lb rule list --lb-name linuxnva-vmss-slb-int -o table</b>
BackendPort    DisableOutboundSnat    EnableFloatingIp    EnableTcpReset    FrontendPort    IdleTimeoutInMinutes    LoadDistribution    Name    Protocol
-------------  ---------------------  ------------------  ----------------  --------------  ----------------------  ------------------  ------  ----------
<b>0</b>              False                  True                False             <b>0</b>               4                       Default             HARule  All
</pre>

**Step 6.** Now let us update the routes in Vnet1 and Vnet2 so that they point to the VMSS VIP. The next hop for both will be the virtual IP address of the load balancer, that we verified in Step 7.

<pre lang="...">
<b>az network route-table route update --route-table-name vnet1-subnet1 -n vnet2 --next-hop-ip-address 10.4.2.200</b>
{
  "addressPrefix": "10.2.0.0/16",
  "etag": "W/\"dabc15c9-3a7e-4e8b-bc7f-c8bba239bb6e\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet2",
  "name": "vnet2",
  "nextHopIpAddress": "10.4.2.100",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

<pre lang="...">
<b>az network route-table route update --route-table-name vnet2-subnet1 -n vnet1 --next-hop-ip-address 10.4.2.200</b>
{
  "addressPrefix": "10.1.0.0/16",
  "etag": "W/\"f7a2d8ed-4588-496f-9e25-3bafbb3ba7ee\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1/routes/vnet1",
  "name": "vnet1",
  "nextHopIpAddress": "10.4.2.100",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

<pre lang="...">
<b>az network route-table route update --route-table-name vnet2-subnet1 -n default --next-hop-ip-address 10.4.2.200</b>
{
  "addressPrefix": "0.0.0.0/0",
  "etag": "W/\"92fa8f12-326e-439b-b591-0bbb723b7617\"",
  "id": "/subscriptions/e7da9914-9b05-4891-893c-546cb7b0422e/resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1/routes/default",
  "name": "default",
  "nextHopIpAddress": "10.4.2.200",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest",
  "type": "Microsoft.Network/routeTables/routes"
}
</pre>

**Step 7.** At this point connectivity between the VMs in vnet1 and vnet2 should flow through the VMSS. Try to connect from our jump host (in vnet1) to the VM in vnet2, 10.2.1.4. The SSH traffic should be intercepted by the UDRs and sent over to the LB. The LB would then load balance it over the NVAs in the VMSS, that would source NAT it (to make sure to attract the return traffic) and send it forward to the VM in myVnet2.

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ssh 10.2.1.4</b>
ssh: connect to host 10.2.1.4 port 22: Connection timed out
lab-user@myVnet1-vm1:~$ who
lab-user pts/0        2018-12-03 13:11 (<b>10.4.2.5</b>)
</pre> 

You can see that the access is coming from the IP address 10.4.2.5. This IP address belongs to one of the instances of the VMSS. The following commands show how you can verify the private IP address of each instance in your VMSS:

<pre lang="...">
<b>az vmss list-instances -n nva-vmss -o table</b>
InstanceId    LatestModelApplied    Location    Name        ProvisioningState    ResourceGroup    VmId
------------  --------------------  ----------  ----------  -------------------  ---------------  ------------------------------------
1             True                  westeurope  nva-vmss_1  Succeeded            VNETTEST         4a4c53b0-1095-4d60-9d29-16cf7e71d655
3             True                  westeurope  nva-vmss_3  Succeeded            VNETTEST         ffff976e-025e-43b4-a686-d32398f4cbea
<b>az vmss nic list-vm-nics --vmss-name nva-vmss --instance-id 1 --query [].ipConfigurations[].privateIpAddress -o tsv</b>
<b>10.4.2.5</b>
<b>az vmss nic list-vm-nics --vmss-name nva-vmss --instance-id 3 --query [].ipConfigurations[].privateIpAddress -o tsv</b>
10.4.2.7
</pre> 

**Step 8.** Let us now investigate Internet access through the NVAs in the VMSS. You may have noticed that we updated the default route in Vnet2-subnet1 to point to the VMSS Internal Load Balancer. For that to work, as previous labs showed, we need an external load balancer associated to the VMSS instances and with an outbound NAT rule. Let us look at it:

<pre lang="...">
<b>az network lb frontend-ip list --lb-name linuxnva-vmss-slb-ext --query [].[name,publicIpAddress.id] -o tsv</b>
myFrontendConfig        /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/publicIPAddresses/<b>linuxnva-vmss-slbPip-ext</b>
</pre> 

<pre lang="...">
az network public-ip show -n linuxnva-vmss-slbPip-ext --query ipAddress -o tsv
52.236.159.117
</pre>

Let us do one more check, and verify that there are 2 instances associated to the backend address pool of the ELB:

<pre lang="...">
<b>az network lb address-pool list --lb-name linuxnva-vmss-slb-ext -o tsv --query [].backendIpConfigurations[].id</b>
/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Compute/virtualMachineScaleSets/nva-vmss/virtualMachines/1/networkInterfaces/nic
0/ipConfigurations/ipconfig0
/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Compute/virtualMachineScaleSets/nva-vmss/virtualMachines/3/networkInterfaces/nic
0/ipConfigurations/ipconfig0
</pre>

Now we are sure that outbound Internet access should work from our VM in Vnet2. If you try you should see that it is coming to the Internet to the IP address assigned to the frontend configuration of the load balancer

<pre lang="...">
lab-user@myVnet2-vm1:~$ curl ifconfig.co
<b>52.236.159.117</b>
</pre> 

### What we have learnt

In previous labs we saw that NVAs can be clustered in a farm behind a load balancer. This lab has taken this concept a step further, converting that farm into a Virtual Machine Scale Set, that has the properties of autoscaling up and down.

The VMSS configuration is using the same design as we already saw in a previous lab with NVA VMs: an ILB providing the endpoint for UDRs, and an external load balancer that provides Internet connectivity to the NVAs.


## Optional activity: Azure Firewall

Now you understand the main concepts behind High Availability for Network Virtual Appliances. Azure Firewall is a managed NVA offering not too different from the previous design shown in the VMSS lab. The main difference lies in the fact that Microsoft is managing the different moving parts, especially the load balancers, which makes it a lot easier to deploy and maintain.

As optional activity you can deploy an Azure Firewall in myVnet4 following the tutorial in the documentation, that you can find here: https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal.


# Part 3: VPN to external site <a name="part3"></a>

 
## Lab 9: Spoke-to-Spoke communication over VPN gateway (optional) <a name="lab9"></a>

**Important Note:** provisioning of the VPN gateways will take up to 45 minutes to complete

In this lab we will simulate the connection to an on-premises data center, that in our case will be simulated by vnet5. We will create a BGP-based VPN connection between our Hub vnet in Azure (vnet4), and the on-premises DC (simulated with vnet5).
For this lab you will need to have set up virtual network gateways in vnets 4 and 5. You can verify whether gateways exist in those vnets with these commands:

**Step 1.**	No gateway exists in either Vnet, you can create them with these commands. It is recommended to run these commands in separate terminals (or tmux panels) so that they run in parallel, since they take a long time to complete (up to 45 minutes):

<pre lang="...">
<b>az network vnet-gateway create --name vnet4Gw --vnet myVnet4 --public-ip-addresses vnet4gwPip --sku VpnGw1 --asn 65504</b>
<i>...Output omitted...</i>
</pre>

<pre lang="...">
<b>az network vnet-gateway create --name vnet5Gw --vnet myVnet5 --public-ip-addresses vnet5gwPip --sku VpnGw1 --asn 65505</b>
<i>...Output omitted...</i>
</pre>

So far we have configured spoke-to-spoke communication over a cluster of NVAs, but we can leverage VPN gateways for that purpose too. The following diagram illustrates what we are trying to achieve in this lab:

![Architecture Image](figure03.png "Spoke to spoke communication")

**Figure 9.** Spoke-to-spoke communication over vnet gateway

**Step 2.**	We need to replace the route we installed in Vnet1-Subnet1 and Vnet2-Subnet1 pointing to Vnet4’s NVA, with another one pointing to the VPN gateway. You will not be able to find out on the GUI or the CLI the IP address assigned to the VPN gateway, but you can guess it. Since the first 3 addresses in every subnet are reserved for the vnet router, the gateways (Virtual Network Gateways are deployed in pairs, even if you typically only see one) should have got the IP addresses 10.4.0.4 and 10.4.0.5 (remember that we allocated the prefix 10.4.0.0 to the Gateway Subnet in myVnet4). You can verify it pinging this IP addresses from any VM in any spoke. For example, from our jump host myVnet1-vm2:

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.4.0.4</b>
PING 10.4.0.4 (10.4.0.4) 56(84) bytes of data.
64 bytes from 10.4.0.4: icmp_seq=1 ttl=128 time=2.27 ms
64 bytes from 10.4.0.4: icmp_seq=2 ttl=128 time=0.794 ms
64 bytes from 10.4.0.4: icmp_seq=3 ttl=128 time=1.16 ms
64 bytes from 10.4.0.4: icmp_seq=4 ttl=128 time=0.937 ms
^C
--- 10.4.0.4 ping statistics ---
4 packets transmitted, 4 received, <b>0% packet loss</b>, time 3001ms
rtt min/avg/max/mdev = 0.794/1.291/2.271/0.582 ms
lab-user@myVnet1-vm1:~$  
</pre>

**Step 3.**	Modify the routes in vnets 1 and 2 with these commands, back in your Azure CLI command prompt. Note that we specify a next-hop type of VirtualAppliance, even if it is actually an Azure VPN Gateway:

<pre lang="...">
<b>az network route-table route update --next-hop-ip-address 10.4.0.4 --route-table-name vnet1-subnet1 -n vnet2</b>
{
  "addressPrefix": "10.2.0.0/16",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet2",
  "name": "vnet2",
  "nextHopIpAddress": "10.4.0.4",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

<pre lang="...">
<b>az network route-table route update --next-hop-ip-address 10.4.0.4 --route-table-name vnet2-subnet1 -n vnet1</b>
{
  "addressPrefix": "10.1.0.0/16",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet2-subnet1/routes/vnet1",
  "name": "vnet1",
  "nextHopIpAddress": "10.4.0.4",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

**Step 3.**	Now you can verify what the route tables look like in an interface from a VM in the vnets and the NICs, and how it has been programmed in the NICs. We will do it with myVnet1, optionally you can verify myVnet2 and a NIC in myVnet2 too:

<pre lang="...">
<b>az network route-table route list --route-table-name vnet1-subnet1 -o table</b>
AddressPrefix    Name          NextHopIpAddress    NextHopType       ProvisioningState
---------------  -------       ------------------  ----------------  -----------------
10.2.0.0/16      vnet2         10.4.0.4            VirtualAppliance  Succeeded
10.1.1.0/24      vnet1-subnet1 10.4.2.100          VirtualAppliance  Succeeded       
10.3.1.0/24      vnet3subnet1  10.4.2.100          VirtualAppliance  Succeeded      
</pre>

**Note:** some columns have been removed from the output above for clarity purposes.

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet1-vm1-nic</b>
<i>...Output omitted...</i>
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
</pre>

**Note:** the command above will take some seconds to execute, since it needs to access to low-level routing tables programmed in the VM's NIC

**Step 4.**	After a couple of seconds our jump host should still be able to reach other VMs. Not over the NVA, but over the VPN gateway. Note that ping now is working, since the VPN gateway is not filtering out ICMP traffic, as our iptables-based NVA did:

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.2.1.4</b>
PING 10.2.1.4 (10.2.1.4) 56(84) bytes of data.
64 bytes from 10.2.1.4: icmp_seq=4 ttl=63 time=7.59 ms
64 bytes from 10.2.1.4: icmp_seq=5 ttl=63 time=5.79 ms
64 bytes from 10.2.1.4: icmp_seq=6 ttl=63 time=4.90 ms
</pre>

If you want to find out whether the VPN gateways are doing any NAT, you can just SSH to the VM in Vnet2 and see the address you are coming from. As you might expect, the VPN gateways are not performing any NAT at all.

<pre lang="...">
lab-user@myVnet2-vm1:~$ ssh 10.2.1.4
Password:
<i>...Output omitted...</i>
lab-user@myVnet2-vm1:~$ who
lab-user pts/0        2018-12-03 20:59 (<b>10.1.1.5</b>)
</pre>

**Optional:** find out and execute the commands to change the next hop for other routes in other routing tables.

### What we have learnt

VPN gateways can also be used for spoke-to-spoke communications, instead of NVAs. You need to &#39;guess&#39; the IP address that a VPN gateway will receive, and you can use that IP address in UDRs as next hop.


 
## Lab 10: VPN connection to the Hub Vnet (optional) <a name="lab10"></a>


**Step 1.**	Make sure that the VPN gateways have different Autonomous System Numbers (ASN) configured. You can check the ASN with this command, back in your Azure CLI command prompt:

<pre lang="...">
<b>az network vnet-gateway list --query [].[name,bgpSettings.asn] -o table</b>
Column1      Column2
---------  ---------
vnet4Gw        65504
vnet5Gw        65505
</pre>


**Step 2.**	Now we can establish a VPN tunnel between them. Note that tunnels are unidirectional, so you will need to establish a tunnel from vnet4gw to vnet5gw, and another one in the opposite direction (note that it is normal for these commands to take some time to run):

<pre lang="...">
<b>az network vpn-connection create -n 4to5 --vnet-gateway1 vnet4gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet5gw</b>
{
  "connectionStatus": "Unknown",
  "connectionType": "Vnet2Vnet",
  "egressBytesTransferred": 0,
  "enableBgp": true,
  "ingressBytesTransferred": 0,
  "provisioningState": "<b>Succeeded</b>",
  "resourceGuid": "...",
  "routingWeight": 10,
  "sharedKey": "Microsoft123",
  "virtualNetworkGateway1": {
    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworkGateways/vnet4Gw",
    "resourceGroup": "vnetTest"
  },
  "virtualNetworkGateway2": {
    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworkGateways/vnet5gw",
    "resourceGroup": "vnetTest"
  }
}
</pre>

<pre lang="...">
<b>az network vpn-connection create -n 5to4 --vnet-gateway1 vnet5gw --enable-bgp --shared-key Microsoft123 --vnet-gateway2 vnet4gw</b>
{
  "connectionStatus": "Unknown",
  "connectionType": "Vnet2Vnet",
  "egressBytesTransferred": 0,
  "enableBgp": true,
  "ingressBytesTransferred": 0,
  "provisioningState": "<b>Succeeded</b>",
  "resourceGuid": "...",
  "routingWeight": 10,
  "sharedKey": "Microsoft123",
  "virtualNetworkGateway1": {
    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworkGateways/vnet5Gw",
    "resourceGroup": "vnetTest"
  },
  "virtualNetworkGateway2": {
    "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworkGateways/vnet4gw",
    "resourceGroup": "vnetTest"
  }
}
</pre>

Once you have provisioned the connections you can get information about them with this command. Wait until the Provisioning State for both connections transitions from `Updating` to `Succeeded`:

<pre lang="...">
<b>az network vpn-connection list -o table</b>
ConnectionType    EnableBgp    Name    ProvisioningState    RoutingWeight
----------------  -----------  ------  -------------------  ---------------
Vnet2Vnet         True         4to5    Succeeded            10
Vnet2Vnet         True         5to4    Succeeded            10
</pre>

**Note:** The previous output has been reformatted for readability reasons


**Step 3.**	After the tunnels are provisioned, the connection process starts. Get the connection status of the tunnels, and wait until they are connected:

<pre lang="...">
<b>az network vpn-connection show --name 4to5 --query connectionStatus</b>
"Connecting"
</pre>

Wait some seconds, and reissue the command until you get a "Connected" status, as the following ouputs show:

<pre lang="...">
<b>az network vpn-connection show --name 4to5 --query connectionStatus</b>
"Connected",
</pre>

<pre lang="...">
<b>az network vpn-connection show --name 5to4 --query connectionStatus</b>
"Connected",
</pre>


**Step 4.**	Modify the vnet peerings to use the gateways we created in the previous lab. The &#39;useRemoteGateways&#39; property of the network peering will allow the vnet to use any VPN or ExpressRoute gateway in the destination vnet. Note that this option cannot be set if the destination vnet does not have any VPN or ExpressRoute gateway configured (which is the reason why the initial ARM template did not configure it, since we did not have our VPN gateways yet). 

We will start with the hub. Not because we want, but because we must: if you try to set the spoke peering to UseRemoteGateways before the hub peering has AllowGatewayTransit you will get this error:

```
Peering /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworks/myVnet1/virtualNetworkPeerings/LinkTomyVnet4 
cannot have UseRemoteGateways flag set to true, because corresponding remote peering /subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/virtualNetworks/myVnet4/virtualNetworkPeerings/LinkTomyVnet1 has 
AllowGatewayTransit flag set to false.
```

Let us then look at the hub peerings:

<pre lang="...">
<b>az network vnet peering list --vnet-name myVnet4 -o table</b>
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    Name           PeeringState    UseRemoteGateways
-----------------------  ---------------------  ---------------------------  -------------  --------------  -------------------
False                    False                  True                         LinkTomyVnet3  Connected       False
False                    False                  True                         LinkTomyVnet2  Connected       False
False                    False                  True                         LinkTomyVnet1  Connected       False
</pre>

Before enabling AllowGatewayTransit let us verify the routing tables at the remote site (Vnet5) and one of the spokes (Vnet1). We will use the json tool `jq` (Json Query) to make the output of the show-effective-route-table command more compact. If you dont want to install it on your machine (for example with `apt get install jq`, just issue the commands without any output formatting):

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet5-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.5.0.0/16"]         []                      VnetLocal
["10.4.0.254/32"]       ["13.94.129.120"]       VirtualNetworkGateway
["10.4.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
["0.0.0.0/0"]           []                      Internet
["10.0.0.0/8"]          []                      None
["100.64.0.0/10"]       []                      None
["172.16.0.0/12"]       []                      None
["192.168.0.0/16"]      []                      None
</pre>

In case you are wondering what the 10.4.0.254/32 route is, that is the IP address that the gateways are using to establish the BGP adjacencies. Kind of a loopback interface in a router, if you will.

<pre lang="...">
az network nic show-effective-route-table -n myVnet1-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'
["10.1.0.0/16"]      []              VnetLocal
["10.4.0.0/16"]      []              VNetPeering
["0.0.0.0/0"]        []              Internet
["10.0.0.0/8"]       []              None
["100.64.0.0/10"]    []              None
["172.16.0.0/12"]    []              None
["192.168.0.0/16"]   []              None
["10.2.0.0/16"]      ["10.4.0.4"]    VirtualAppliance
["10.3.0.0/16"]      ["10.4.2.100"]  VirtualAppliance
</pre>

Let us now update the peerings with the AllowGatewayTransit setting:

<pre lang="...">
<b>az network vnet peering update --vnet-name myVnet4 --name LinkTomyVnet1 --set allowGatewayTransit=true</b>
<i>...output omitted...</i>
<b>az network vnet peering update --vnet-name myVnet4 --name LinkTomyVnet2 --set allowGatewayTransit=true</b>
<i>...output omitted...</i>
<b>az network vnet peering update --vnet-name myVnet4 --name LinkTomyVnet3 --set allowGatewayTransit=true</b>
<b>AllowGatewayTransit and UseRemoteGateways options are currently supported only when both peered virtual networks are in the same region.</b>
</pre>

As expected, we could not activate the opion AllowGatewayTransit for Vnet3, since it is using global peering. Interestingly enough, if you check the routing tables again, nothing has changed:

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet5-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.5.0.0/16"]         []                      VnetLocal
["10.4.0.254/32"]       ["13.94.129.120"]       VirtualNetworkGateway
["10.4.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
["0.0.0.0/0"]           []                      Internet
["10.0.0.0/8"]          []                      None
["100.64.0.0/10"]       []                      None
["172.16.0.0/12"]       []                      None
["192.168.0.0/16"]      []                      None
</pre>

<pre lang="...">
az network nic show-effective-route-table -n myVnet1-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'
["10.1.0.0/16"]      []              VnetLocal
["10.4.0.0/16"]      []              VNetPeering
["0.0.0.0/0"]        []              Internet
["10.0.0.0/8"]       []              None
["100.64.0.0/10"]    []              None
["172.16.0.0/12"]    []              None
["192.168.0.0/16"]   []              None
["10.2.0.0/16"]      ["10.4.0.4"]    VirtualAppliance
["10.3.0.0/16"]      ["10.4.2.100"]  VirtualAppliance
</pre>



**Step 5.** Let us begin with the spokes. First of all, here is what they look like now. Let us take Vnet1 as example:

<pre lang="...">
<b>az network vnet peering list --vnet-name myVnet1 -o table</b>
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    Name           PeeringState    UseRemoteGateways
-----------------------  ---------------------  ---------------------------  -------------  --------------  -------------------
True                     False                  True                         LinkTomyVnet4  Connected       False
</pre>

As you can see, UseRemoteGateways is false. Let us enable UseRemoteGateways in Vnet1, and see what happens:

<pre lang="...">
<b>az network vnet peering update --vnet-name myVnet1 --name LinkTomyVnet4 --set useRemoteGateways=true</b>
<i>...output omitted...</i>
</pre>


<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet1-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.1.0.0/16"]         []              VnetLocal
["10.4.0.0/16"]         []              VNetPeering
<b>["10.5.0.254/32"]</b>       ["13.81.249.188"]       VirtualNetworkGateway
<b>["10.5.0.0/16"]</b>         ["13.81.249.188"]       VirtualNetworkGateway
["0.0.0.0/0"]           []              Internet
["10.0.0.0/8"]          []              None
["100.64.0.0/10"]       []              None
["172.16.0.0/12"]       []              None
["192.168.0.0/16"]      []              None
["10.2.0.0/16"]         ["10.4.0.4"]    VirtualAppliance
["10.3.0.0/16"]         ["10.4.2.100"]  VirtualAppliance
<b>az network nic show-effective-route-table -n myVnet5-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.5.0.0/16"]         []      VnetLocal
["10.4.0.254/32"]       ["13.94.129.120"]       VirtualNetworkGateway
["10.4.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
<b>["10.1.0.0/16"]</b>         ["13.94.129.120"]       VirtualNetworkGateway
["0.0.0.0/0"]           []      Internet
["10.0.0.0/8"]          []      None
["100.64.0.0/10"]       []      None
["172.16.0.0/12"]       []      None
["192.168.0.0/16"]      []      None
</pre>

Note how Vnet1 has learnt from Vnet5, and Vnet5 from Vnet1. As expected, Vnet5 still does not know anything from Vnet2, nor Vnet2 from Vnet5:

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet2-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.2.0.0/16"] []              VnetLocal
["10.4.0.0/16"] []              VNetPeering
["0.0.0.0/0"]   []              Internet
["10.1.0.0/16"] ["10.4.0.4"]    VirtualAppliance
["0.0.0.0/0"]   ["10.4.2.200"]  VirtualAppliance
["10.3.0.0/16"] ["10.4.2.100"]  VirtualAppliance
</pre>

Let us do the peering for Vnet2 now, and check how routing changes:

<pre lang="...">
<b>az network vnet peering update --vnet-name myVnet2 --name LinkTomyVnet4 --set useRemoteGateways=true</b>
<i>...output omitted...</i>
</pre>

And see how Vnet5 has now learnt from Vnet2 and vice versa:

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet5-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.5.0.0/16"]         []      VnetLocal
["10.4.0.254/32"]       ["13.94.129.120"]       VirtualNetworkGateway
["10.4.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
["10.1.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
<b>["10.2.0.0/16"]</b>         ["13.94.129.120"]       VirtualNetworkGateway
["0.0.0.0/0"]           []      Internet
["10.0.0.0/8"]          []      None
["100.64.0.0/10"]       []      None
["172.16.0.0/12"]       []      None
["192.168.0.0/16"]      []      None
<b>az network nic show-effective-route-table -n myVnet2-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.2.0.0/16"] []      VnetLocal
["10.4.0.0/16"] []      VNetPeering
<b>["10.5.0.254/32"]</b>       ["13.81.249.188"]       VirtualNetworkGateway
<b>["10.5.0.0/16"]</b> ["13.81.249.188"]       VirtualNetworkGateway
["0.0.0.0/0"]   []      Internet
["10.1.0.0/16"] ["10.4.0.4"]    VirtualAppliance
["0.0.0.0/0"]   ["10.4.2.200"]  VirtualAppliance
["10.3.0.0/16"] ["10.4.2.100"]  VirtualAppliance
</pre>

Lastly, we can try with Vnet3, but you know what is going to happen.

<pre lang="...">
<b>az network vnet peering update --vnet-name myVnet3 --name LinkTomyVnet4 --set useRemoteGateways=true</b>
AllowGatewayTransit and UseRemoteGateways options are currently supported only when both peered virtual networks are in the same region.
</pre>

**Step 6.**	If you now try to reach a VM in myVnet5 from any of the VMs in the other Vnets, it should work without any further configuration, following the topology found in the figure below. For example, from our jump host myVnet1-vm2 we will ping 10.5.1.4, which should be the private IP address from myVnet5-vm1:

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.5.1.4</b>
PING 10.5.1.4 (10.5.1.4) 56(84) bytes of data.
64 bytes from 10.5.1.4: icmp_seq=1 ttl=62 time=10.9 ms
64 bytes from 10.5.1.4: icmp_seq=2 ttl=62 time=9.92 ms
</pre>

![Architecture Image](figureVpn.png "VPN and Vnet Peering")

**Figure 10:** VPN connection through Vnet peering

This is the case because of how the Vnet peerings were configured, more specifically the parameters AllowForwardedTraffic and UseRemoteGateways (in the spokes), and AllowGatewayTransit (in the hub). You can read more about these attributes here: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering. Back in your Azure CLI command prompt, you can issue this command to check the state and configuration of your vnet peerings:

However, you might want to push this traffic through the Network Virtual Appliances too. For example, if you wish to firewall the traffic that leaves your hub and spoke environment. The process that we have seen in previous labs with UDR manipulation is valid for the GatewaySubnet of Vnet4 as well (where the hub VPN gateway is located), as the following figure depicts:

![Architecture Image](figure06.png "VPN, Vnet Peering and NVA")

**Figure 11.** VPN traffic combined with Vnet peering and a Network Virtual Appliance

**Step 7.**	For the gateway subnet in myVnet4 we will create a new routing table, add a route for vnet1-subnet1, and associate the route table to the GatewaySubnet:

<pre lang="...">
<b>az network route-table create --name vnet4-gw</b>
{
  "etag": "W/\"...\"",
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
</pre>

<pre lang="...">
<b>az network route-table route create --address-prefix 10.1.1.0/24 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet4-gw -n vnet1-subnet1</b>
{
  "addressPrefix": "10.1.1.0/24",
  "etag": "W/\"...\"",
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet4-gw/routes/vnet1-subnet1",
  "name": "vnet1-subnet1",
  "nextHopIpAddress": "10.4.2.101",
  "nextHopType": "VirtualAppliance",
  "provisioningState": "Succeeded",
  "resourceGroup": "vnetTest"
}
</pre>

<pre lang="...">
<b>az network route-table route list --route-table-name vnet4-gw -o table</b>
AddressPrefix    Name           NextHopIpAddress    NextHopType       
---------------  -------------  ------------------  ----------------  
10.1.1.0/24      vnet1-subnet1  10.4.2.100          VirtualAppliance 
</pre>

**Note:** if you have not completed the setup of the NVA load balancer in previous labs, you can use the IP address of one of the firewalls. That is, instead of 10.4.2.100 you could use 10.4.2.101 as gateway.

And now we associate the new routing table to the gateway subnet:

<pre lang="...">
<b>az network vnet subnet update -n GatewaySubnet --vnet-name myVnet4 --route-table vnet4-gw</b>
<i>Output omitted</i>
</pre>

**Step 8.**	We need to add an additional route to the spoke vnets, to let them know that they can reach the remote site (in our lab simulated by myVnet5, with an IP prefix of 10.5.0.0/16) over the NVA. Here we do it for myVnet1, you can do it for the other spoke Vnets too optionally (myVnet2 and myVnet3):

<pre lang="...">
<b>az network route-table route create --address-prefix 10.5.0.0/16 --next-hop-ip-address 10.4.2.100 --next-hop-type VirtualAppliance --route-table-name vnet1-subnet1 -n vnet5</b>
{
  "addressPrefix": "10.5.0.0/16",
  "etag": "W/\"...\"",                                                                                                   
  "id": "/subscriptions/.../resourceGroups/vnetTest/providers/Microsoft.Network/routeTables/vnet1-subnet1/routes/vnet5", 
  "name": "vnet5",             
  "nextHopIpAddress": "10.4.2.100",
  "nextHopType": "VirtualAppliance",
  "provisioningState": <b>"Succeeded"</b>,
  "resourceGroup": "vnetTest"  
}
</pre>


**Step 9.**	After some seconds you can verify that VMs in myVnet1Subnet1 can still connect over SSH to VMs in myVnet5, but not any more over ICMP (since we have a rule for dropping ICMP traffic in the NVA):

<pre lang="...">
lab-user@myVnet1-vm2:~$ <b>ping 10.5.1.4</b>
PING 10.5.1.4 (10.5.1.4) 56(84) bytes of data.
^C
--- 10.5.1.4 ping statistics ---
3 packets transmitted, 0 received, 100% packet loss, time 1999ms

lab-user@myVnet1-vm2:~$ <b>ssh 10.5.1.4</b>
...
Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 4.4.0-47-generic x86_64)
</pre>

### What we have learnt

Vnet peerings allow for sharing VPN gateways in the hub to provide connectivity to the spokes through the peering option &#39;Use Remote Gateways&#39;.

You can use NVAs to secure the traffic going between the local Vnets and the remote site (at the other side of the Site-To-Site tunnel), manipulating the routing in the subnet gateway with UDRs. This configuration works as well in Hub-And-Spoke Vnet configurations.


# End the lab

To end the lab, simply delete the resource group that you created in the first place (vnetTest in our example) from the Azure portal or from the Azure CLI: 

```
az group delete --name vnetTest
```


 
# Conclusion

I hope you have had fun running through this lab, and that you learnt something that you did not know before. We ran through multiple Azure networking topics like IPSec VPN, vnet peering, global vnet peering, NSGs, Load Balancing, outbound NAT rules, Hub & Spoke vnet topologies and advanced NVA HA concepts, but we covered as well other non-Azure topics such as basic iptables or advanced probes programming with PHP.

If you have any suggestion to improve this lab, please open an issue in Github in this repository.




# References <a name="ref"></a>

Useful links:
- Azure network documentation: https://docs.microsoft.com/en-us/azure/#pivot=services&panel=network
- Hub and Spoke network topology in Azure: [https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- Olivier Martin blog's on Azure networking:
  -	Part 1: [https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud/](https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud/)
  -	Part 2: [https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud-part-2/](https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud-part-2/)
  -	Part 3: [https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud-part-3/](https://azure.microsoft.com/en-us/blog/networking-to-and-within-the-azure-cloud-part-3/)
-	Vnet documentation: [https://docs.microsoft.com/en-us/azure/virtual-network/](https://docs.microsoft.com/en-us/azure/virtual-network/)
-	Load Balancer documentation: [https://docs.microsoft.com/en-us/azure/load-balancer/](https://docs.microsoft.com/en-us/azure/load-balancer/)
-	VPN Gateway documentation: [https://docs.microsoft.com/en-us/azure/vpn-gateway/](https://docs.microsoft.com/en-us/azure/vpn-gateway/)

 


