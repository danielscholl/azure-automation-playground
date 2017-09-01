<#

    .SYNOPSIS
        Stops all the Azure VMs in a specific Azure Resource Group

    .DESCRIPTION
        This runbook stops all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be stopped.

    .REQUIREMENTS
        THis runbook requires the Azure Resource Manager PowerShell module has been imported into
        your Azure Automation instance.


    .NOTES
        AUTHOR: Daniel Scholl
#>

workflow Stop-AzureVMs {
  param(
    [string]$ResourceGroupName
 	)

  #The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
  $ConnectionAssetName = 'AzureRunAsConnection'

  $Conn = Get-AutomationConnection -Name $ConnectionAssetName
  if (!$Conn) {
    Throw "Could not find an Automation Connection Asset named '${ConnectionAssetName}'. Make sure you have created one in this Automation Account."
  }
  $Account = Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
    -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
  if (!$Account) {
    Throw "Could not authenticate to Azure using the connection asset '${ConnectionAssetName}'."
  }

  $Machines = AzureRm


  #The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
  $CredentialAssetName = 'DefaultAzureCredential'

  #Get the credential with the above name from the Automation Asset store
  $Cred = Get-AutomationPSCredential -Name $CredentialAssetName
  if (!$Cred) {
    Throw "Could not find an Automation Credential Asset named '${CredentialAssetName}'. Make sure you have created one in this Automation Account."
  }

  #Connect to your Azure Account
  $Account = Add-AzureAccount -Credential $Cred
  if (!$Account) {
    Throw "Could not authenticate to Azure using the credential asset '${CredentialAssetName}'. Make sure the user name and password are correct."
  }

  $Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName

  Start-AzureRmVM -Name 'VMName' -ResourceGroupName 'ResourceGroupName'

  if (!$Machines) {
    Write-Output "No VMs were found in your subscription."
  }
  else {

    Foreach -parallel ($VM in $Machines) {
      Stop-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -Force
    }
  }
}
