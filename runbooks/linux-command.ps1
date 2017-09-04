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

Get Virtual Machine
$vm = Get-AzureRmVm -Name $MachineName -ResourceGroup $ResourceGroup
if (!$vm) {
    throw "Could not find a Machine named '${vm}'."
}

# Get Network Interface
$nic = Get-AzureRmNetworkInterface | where { $_.Id -eq $vm.NetworkProfile.NetworkInterfaces[0].Id }
if (!$nic) {
    throw "Could not find a Network Interface."
}

# Get Public IP Address
$publicIp = Get-AzureRmPublicIpAddress | where { $_.Id -eq $nic.IpConfigurations.PublicIpAddress.Id }
if (!$publicIp) {
    throw "Could not find a Public IP for '${nic}.Name'."
}



# Get Automation Account Name
$automation = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup
if (!$automation) {
    throw "Could not find an Automation Account named '${automation}'."
}

# Get Machine Credentials
$credentialName = 'SSHCred'
$sshCredentials = Get-AzureRmAutomationCredential -Name $credentialName `
    -ResourceGroup $ResourceGroup `
    -AutomationAccountName $automation.AutomationAccountName
if (!$sshCredentials) {
    throw "Could not find an Credential Asset named '${credentialName}'."
}

# $user = 'myUser'
# $password = 'myPassword'
# $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force


# $sshCredentials = New-Object System.Management.Automation.PSCredential ($user, $secpasswd)
$sshSession = New-SSHSession -ComputerName $publicIp.IpAddress -Port 22 -ConnectionTimeout 30 -Credential $sshCredentials -AcceptKey -Force

$status = Invoke-SSHCommand -SSHSession $sshSession -Command 'pwd'
Write-Output $status.Output


