<#
    .DESCRIPTION
        This runbook allows commands to be exectued on a linux server.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be started.

    .NOTES
        AUTHOR: Daniel Scholl
#>
Param(
    [Parameter(Mandatory = $true)]
    [String] $ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String] $MachineName
)

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
    Write-Error -Message $ErrorMessage `
        -ErrorAction Stop
}

# Get Machine Credential
$automation = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup
$credential = Get-AzureRmAutomationCredential -Name SSHCred `
    -ResourceGroup $ResourceGroup `
    -AutomationAccountName $automation.AutomationAccountName `

# Get IP address of Machine    
$vm = Get-AzureRMVM -Name $MachineName -ResourceGroup $ResourceGroup
$ipconfig = Get-AzureRmNetworkInterface | Where-Object { $_.Id -eq $vm.NetworkInterfaceIDs[0]} | Get-AzureRmNetworkInterfaceIpConfig
$publicIp = Get-AzureRmPublicIpAddress | Where-Object { $_.Id -eq $ipconfig.PublicIpAddress.Id } |Select-Object IpAddress


# Write-Host $vm