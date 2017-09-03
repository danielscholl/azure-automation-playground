param (
  [Parameter(Mandatory = $true)]
  [String]
  $VMName,

  [Parameter(Mandatory = $true)]
  [String]
  $ResourceGroup,

  [Parameter(Mandatory = $true)]
  [String]
  $VMLocation
)

# Set Error Preference
$ErrorActionPreference = "Stop"

# Get Variables and Credentials
$VariableName = 'AzureSubscriptionID'
$SubscriptionID = Get-AutomationVariable -Name $VariableName
if (!$SubscriptionID) {
  throw "Could not find an Variable Asset named '${VariableName}'."
}

$VariableName = 'OMSWorkspaceID'
$OMSID = Get-AutomationVariable -Name $VariableName
if (!$OMSID) {
  throw "Could not find an Variable Asset named '${VariableName}'."
}

$VariableName = 'OMSWorkspacePrimaryKey'
$OMSKey = Get-AutomationVariable -Name $VariableName
if (!$OMSKey) {
  throw "Could not find an Variable Asset named '${VariableName}'."
}

$ConnectionName = 'AzureRunAsConnection'
$Conn = Get-AutomationConnection -Name $ConnectionName
if (!$Conn) {
  throw "Could not find an Connection Asset named '${ConnectionName}'."
}


Try {
    # Authenticate
  Add-AzureRMAccount -ServicePrincipal `
    -Tenant $Conn.TenantID `
    -ApplicationId $Conn.ApplicationID `
    -CertificateThumbprint $Conn.CertificateThumbprint
}
Catch {
  $ErrorMessage = 'Login to Azure failed.'
  $ErrorMessage += " `n"
  $ErrorMessage += 'Error: '
  $ErrorMessage += $_
  Write-Error `
    -Message $ErrorMessage `
    -ErrorAction Stop
}


# Set Variables
[string]$Settings = '{"workspaceId":"' + $OMSID + '"}';
[string]$ProtectedSettings = '{"workspaceKey":"' + $OMSKey + '"}';

# Start extension installation
Write-Output -InputObject 'OMS Extension Installation Started.'

Try {
    # $ExtenstionStatus = Set-AzureRmVMExtension `
    #     -ResourceGroupName $ResourceGroup `
    #     -VMName $VMName `
    #     -Name 'OMSExtension' `
    #     -Publisher 'Microsoft.EnterpriseCloud.Monitoring' `
    #     -TypeHandlerVersion '1.0' `
    #     -ExtensionType 'MicrosoftMonitoringAgent' `
    #     -Location $VMLocation `
    #     -SettingString $Settings `
    #     -ProtectedSettingString $ProtectedSettings `
    #     -ErrorAction Stop

  $vm = Get-AzureRmVM -Name $VMName `
    -ResourceGroupName $ResourceGroup `
    -ErrorAction Stop

  $ExtenstionStatus = Set-AzureVMExtension -VM $vm `
    -Publisher 'Microsoft.EnterpriseCloud.Monitoring' `
    -ExtensionName 'OmsAgentForLinux' `
    -Version '1.*' `
    -PublicConfiguration "{'workspaceId': '$OMSID'}" `
    -PrivateConfiguration "{'workspaceKey': '$OMSKey' }" `
    -ErrorAction Stop |
  Update-AzureVM -Verbose
}
Catch {
  $ErrorMessage = 'Failed to install OMS extension on Azure V2 VM.'
  $ErrorMessage += " `n"
  $ErrorMessage += 'Error: '
  $ErrorMessage += $_
  Write-Error `
    -Message $ErrorMessage `
    -ErrorAction Stop
}

# Output results
If ($ExtenstionStatus.IsSuccessStatusCode -eq 'True') {
  Write-Output -InputObject 'OMS Extension was installed successfully.'
}
Else {
  Write-Output -InputObject 'OMS Extension was not installed.'

  Write-Error `
    -Message $ExtenstionStatus.StatusCode  `
    -ErrorAction Stop
}
