<#
    .DESCRIPTION
        This runbook stops all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be stopped.

    .NOTES
        AUTHOR: Daniel Scholl
#>
workflow stop-machines {
  Param(
    [string]$ResourceGroupName
  )
  $ConnectionAssetName = 'AzureRunAsConnection'
  $Conn = Get-AutomationConnection -Name $ConnectionAssetName
  if (!$Conn) {
    throw "Could not find an Automation Connection Asset named '${ConnectionAssetName}'."
  }

  $Account = Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
  if (!$Account) {
    throw "Could not authenticate to Azure using the connection asset '${ConnectionAssetName}'."
  }

  $Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
  if (!$Machines) {
    Write-Output "No VMs were found in the Resource Group."
  } else {
    foreach -parallel ($VM in $Machines) {
      Write-Output "Stoping Server $VM.Name"
      Stop-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroupName -Force
    }
  }
}
