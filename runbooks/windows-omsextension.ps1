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

#region Azure Authentication
  $connectionName = "AzureRunAsConnection"
  try {
    # Get the connetion  "AzureRunAsConnection"
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
  
    "Logging in to Azure..."
    Add-AzureRmAccount `
      -ServicePrincipal `
      -TenantId $servicePrincipalConnection.TenantId `
      -ApplicationId $servicePrincipalConnection.ApplicationId `
      -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
  }
  catch {
    if (!$servicePrincipalConnection) {
      $ErrorMessage = "Connection $connectionName not found."
      throw $ErrorMessage
    } else {
      Write-Error -Message $_.Exception
      throw $_.Exception
    }
  }
#endregion

  
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
  
  
  
  
  # Set Variables
  [string]$Settings = '{"workspaceId":"' + $OMSID + '"}';
  [string]$ProtectedSettings = '{"workspaceKey":"' + $OMSKey + '"}';
  
  # Start extension installation
  Write-Output -InputObject 'OMS Extension Installation Started.'
  
  Try {
      $ExtenstionStatus = Set-AzureRmVMExtension `
          -ResourceGroupName $ResourceGroup `
          -VMName $VMName `
          -Name 'OMSExtension' `
          -Publisher 'Microsoft.EnterpriseCloud.Monitoring' `
          -TypeHandlerVersion '1.0' `
          -ExtensionType 'MicrosoftMonitoringAgent' `
          -Location $VMLocation `
          -SettingString $Settings `
          -ProtectedSettingString $ProtectedSettings `
          -ErrorAction Stop
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