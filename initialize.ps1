<# Copyright (c) 2017, cloudcodeit.com
.Synopsis
   Installs a Virtual Machine to an isolated Resource Group with an automation account
.DESCRIPTION
   This script will install a virtual machine, Storage, Network
   into its own resource group. It will setup an Azure Automation account.
.EXAMPLE
   ./initialize.ps1 <your_unique_string> <your_group> <your_vmname> <your_location>
#>

#Requires -RunAsAdministrator

param([string]$Prefix = $(throw "Unique Parameter required."),
  [string]$ResourceGroup = "automate-demo",
  [string]$_name = "vm",
  [string]$Location = "southcentralus")


## SET OS TYPE  LINUX/WINDOWS
$OS = "LINUX" 

If ($OS -eq "LINUX") {
  $Publisher = "Canonical"
  $Offer = "UbuntuServer"
  $SKU = "16.04-LTS"
  $Version = "latest"
  $PORT_NAME = "SSH"
  $PORT = 22
}
else {
  #MicrosoftWindowsServer:WindowsServer:2012-R2-Datacenter:4.127.20170510
  $Publisher = "MicrosoftWindowsServer"
  $Offer = "WindowsServer"
  $SKU = "2012-R2-Datacenter"
  $Version = "4.127.20170510"
  $PORT_NAME = "RDP"
  $PORT = 3389
}

## SETUP VARIABLES
$CommonName = $Prefix.ToLower() + $ResourceGroup.ToLower()
$SubscriptionInfo = Get-AzureRmSubscription
$TenantID = $SubscriptionInfo | Select TenantId -First 1
$SubscriptionID = $SubscriptionInfo | Select SubscriptionId -First 1


## Storage
$StorageName = $CommonName.Replace("-","")
if ($StorageName.Length > 23) { $StorageName = $StorageName.Substring(0,24) }
$DiagnosticsName = $CommonName.Replace("-","")
if ($DiagnosticsName.Length > 19) { $DiagnosticsName = $DiagnosticsName.Substring(0,20) }
$DiagnosticsName = $DiagnosticsName + "diag"
$StorageType = "Standard_LRS"

## Compute
$AVSetName = $CommonName + "AVset"
$VMName = $CommonName + "-" + $_name
$VMSize = "Standard_A1"
$OSDiskName = $VMName + "-OSDisk"

## Network Security Group
$NetworkSecurityGroupName = $VMName + "-nsg"

## Network
$InterfaceName = $VMName + "-nic"
$PublicIPName = $VMName + "-ip"
$SubnetName = "Subnet"
$VNetName = $CommonName + "VNet"
$VNetAddressPrefix = "10.0.0.0/16"
$VNetSubnetAddressPrefix = "10.0.0.0/24"

## Automation
$AutomationName = $CommonName + "-automate"
$RunBook = $AutomationName + "-rb"

$SSHValue = [IO.File]::ReadAllText(".\.ssh\id_rsa")


# Login to Azure
Login-AzureRmAccount



# Resource Group
#########################
$ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroup `
    -Location $Location



# Storage
#########################
$StorageAccount = New-AzureRmStorageAccount -Name $StorageName `
    -ResourceGroup $ResourceGroup `
    -Type $StorageType `
    -Location $Location

$DiagnosticsAccount = New-AzureRmStorageAccount -Name $DiagnosticsName `
    -ResourceGroup $ResourceGroup  `
    -Type $StorageType `
    -Location $Location



# Network Security Group
#########################
$Rules = @()
$Rules += New-AzureRmNetworkSecurityRuleConfig -Name $PORT_NAME `
    -Description "Allow Inbound Connection." `
    -Access Allow `
    -Direction Inbound `
    -Priority 100 `
    -Protocol Tcp `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange $PORT

$NSG = New-AzureRmNetworkSecurityGroup -Name $NetworkSecurityGroupName `
    -ResourceGroup $ResourceGroup `
    -Location $Location `
    -SecurityRules $Rules



# Network
#########################
$Pip = New-AzureRmPublicIpAddress -Name $PublicIPName `
    -ResourceGroup $ResourceGroup `
    -Location $Location `
    -AllocationMethod Dynamic

$SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName `
    -AddressPrefix $VNetSubnetAddressPrefix

$VNet = New-AzureRmVirtualNetwork -Name $VNetName `
    -ResourceGroup $ResourceGroup `
    -Location $Location `
    -AddressPrefix $VNetAddressPrefix `
    -Subnet $SubnetConfig

$Interface = New-AzureRmNetworkInterface -Name $InterfaceName `
    -ResourceGroup $ResourceGroup `
    -Location $Location `
    -SubnetId $VNet.Subnets[0].Id `
    -PublicIpAddressId $Pip.Id



# Compute
#########################
$AVSet = New-AzureRmAvailabilitySet -Name $AVSetName `
    -ResourceGroup $ResourceGroup `
    -Location $Location

# Credential Collection
$Credential = Get-Credential

## Setup local VM Configuration
$VirtualMachine = New-AzureRmVMConfig -VMName $VMName `
    -VMSize $VMSize `
    -AvailabilitySetId $AVSet.Id

If ($OS -eq "LINUX") {
  $VirtualMachine = Set-AzureRmVMOperatingSystem -Linux `
    -VM $VirtualMachine `
    -ComputerName $VMName `
    -Credential $Credential
}
else {
  $VirtualMachine = Set-AzureRmVMOperatingSystem -Windows `
    -VM $VirtualMachine `
    -ComputerName $VMName `
    -Credential $Credential
}

$VirtualMachine = Add-AzureRmVMNetworkInterface `
    -VM $VirtualMachine `
    -Id $Interface.Id

$OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"

$VirtualMachine = Set-AzureRmVMOSDisk `
    -VM $VirtualMachine `
    -Name $OSDiskName `
    -VhdUri $OSDiskUri `
    -CreateOption FromImage

$VirtualMachine = Set-AzureRmVMSourceImage `
    -VM $VirtualMachine `
    -PublisherName $Publisher `
    -Offer $Offer `
    -Skus $SKU `
    -Version $Version


## Create the VM
New-AzureRmVM -ResourceGroup $ResourceGroup `
    -Location $Location `
    -VM $VirtualMachine


# Automation
#########################
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
$CertPlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
$CurrentDate = Get-Date
$EndDate = $CurrentDate.AddMonths(12)
$KeyId = (New-Guid).Guid
$AssetConnection = "AzureRunAsConnection"

$CertDir = (Get-Location).Path + "\.certs"
if(!(Test-Path -Path $CertDir )){
    New-Item -ItemType directory -Path $CertDir
}
$CertPath = Join-Path $CertDir ($AutomationName + ".pfx")


# Create Automation Account
New-AzureRmAutomationAccount -Name $AutomationName `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -Plan Free `
    -Verbose


# Create Self Signed Certificate
$Cert = New-SelfSignedCertificate -DnsName $AutomationName `
    -CertStoreLocation cert:\LocalMachine\My `
    -KeyExportPolicy Exportable `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider"

$CertPassword = ConvertTo-SecureString $CertPlainPassword -AsPlainText -Force
Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $CertPath -Password $CertPassword -Force | Write-Verbose

$PFXCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @($CertPath, $CertPlainPassword)
$KeyValue = [System.Convert]::ToBase64String($PFXCert.GetRawCertData())
$KeyCredential = New-Object  Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADKeyCredential
$KeyCredential.StartDate = $CurrentDate
$KeyCredential.EndDate= $EndDate
$KeyCredential.KeyId = $KeyId
$KeyCredential.CertValue = $KeyValue


# Create Service Principals and assign Role
$Application = New-AzureRmADApplication -DisplayName $AutomationName `
    -HomePage ("http://" + $AutomationName) `
    -IdentifierUris ("http://" + $KeyId) `
    -KeyCredentials $keyCredential

New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId | Write-Verbose
Get-AzureRmADServicePrincipal | Where {$_.ApplicationId -eq $Application.ApplicationId} | Write-Verbose

$NewRole = $null
$Retries = 0;
While ($NewRole -eq $null -and $Retries -le 2)
{
  # Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
  Sleep 5
  New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId | Write-Verbose
  Sleep 5
  $NewRole = Get-AzureRMRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
  $Retries++;
}


# Create the Automation Certificate
New-AzureRmAutomationCertificate -Name AzureRunAsCertificate `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Path $CertPath `
    -Password $CertPassword `
    -Exportable | write-verbose


# Create a Automation Connection
# Remove-AzureRmAutomationConnection -Name $AssetConnection `
#     -ResourceGroupName $ResourceGroup `
#     -AutomationAccountName $AutomationName `
#     -Force -ErrorAction SilentlyContinue

$ConnectionFieldValues = @{
    "ApplicationId" = $Application.ApplicationId; 
    "TenantId" = $TenantID.TenantId; 
    "CertificateThumbprint" = $Cert.Thumbprint; 
    "SubscriptionId" = $SubscriptionID.SubscriptionId
   }

New-AzureRmAutomationConnection -Name $AssetConnection `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -ConnectionTypeName AzureServicePrincipal `
    -ConnectionFieldValues $ConnectionFieldValues


# Create an Automation Runbook
New-AzureRmAutomationRunbook -Name $RunBook `
    -Description 'My First Runbook' `
    -Type PowerShell `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName

# Import a Runbook
$Script='.\runbooks\linux-command.ps1'
Import-AzureRmAutomationRunbook -Name $RunBook `
    -Path $Script `
    -Type PowerShell `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Force


# Create a new Variable
$VariableName='SSHKey'
New-AzureRmAutomationVariable -Name $VariableName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Encrypted $true `
    -Description 'SSH Key' `
    -Value $SSHValue

# Create a new Variable
$VariableName='SubScriptionId'
New-AzureRmAutomationVariable -Name $VariableName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Encrypted $true `
    -Description 'SubScriptionId' `
    -Value (Get-AzureRmSubscription).SubscriptionId

# Create a new Variable
$VariableName='TenantId'
New-AzureRmAutomationVariable -Name $VariableName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Encrypted $true `
    -Description 'SubScriptionId' `
    -Value (Get-AzureRmSubscription).TenantId


# Create a new Credential
$credentialName='SSHCred'
New-AzureRmAutomationCredential -Name $CredentialName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Description 'Credentials for logging into vm' `
    -Value $Credential