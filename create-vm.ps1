# Variables for common values
$virtualNetworkAddr = "192.168.0.0/16"
$subnetAddr = "192.168.1.0/24"
$resourceGroup = "myResourceGroupPowerShell"
$vnetName = "MYvNET"
$subnetName = "mySubnet"
$location = "japanwest"
$vmName = "myVMPowerShell"
$publisherName = "RedHat"
$offer = "RHEL"
$skus = "7-RAW"
$version = "latest"
$vmsize = "Standard_F2"
$loginUser = "azureuser"
$sshPublicKey = "<sshPublicKey>"
$servicePrincipalId = "<servicePrincipalId>"
$servicePrincipalPassword = ConvertTo-SecureString "<servicePrincipalPassword>" -asplaintext -force
$servicePrincipalCred = New-Object System.Management.Automation.PSCredential($servicePrincipalId, $servicePrincipalPassword)
$tenantId = "<tenantId>"
$subscriptionId = "<subscriptionId>"
$diskName = "OsDiskRHEL"
$storageAccountType = "StandardLRS"
$createOption = "FromImage"
$caching = "ReadWrite"

Login-AzureRmAccount -ServicePrincipal -Credential $servicePrincipalCred -SubscriptionId $subscriptionId -Tenant $tenantId 
#Connect-AzureRmAccount -ServicePrincipal -Credential $servicePrincipalCred -SubscriptionId $subscriptionId -Tenant $tenantId
# Definer user name and blank password
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($loginUser, $securePassword)

# Create a resource group
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddr

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name $vnetName -AddressPrefix $virtualNetworkAddr -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name "mypublicdns$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleSSH  -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
  -DestinationPortRange 22 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name myNetworkSecurityGroup -SecurityRules $nsgRuleSSH

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name myNic -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id `
  -EnableAcceleratedNetworking

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmsize | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication | `
Set-AzureRmVMSourceImage -PublisherName $publisherName -Offer $offer -Skus $skus -Version $version | `
Set-AzureRmVMOSDisk -Linux -Name $diskName -StorageAccountType $storageAccountType -DiskSizeInGB 512 -CreateOption $createOption -Caching $caching | `
Add-AzureRmVMNetworkInterface -Id $nic.Id
# Configure SSH Keys
Add-AzureRmVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/$loginUser/.ssh/authorized_keys"

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig