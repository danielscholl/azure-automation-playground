
Function Invoke-VirtualMachineSSH
{
  Param(
    [Parameter(Mandatory = $true)]
    [String] $user,
    [Parameter(Mandatory = $true)]
    [securestring] $secpasswd,
    [Parameter(Mandatory = $true)]
    [String] $ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String] $MachineName,
    [Parameter(Mandatory = $true)]
    [String[]] $commands
  )


  $vm = Get-AzureRMVM -Name $MachineName -ResourceGroup $ResourceGroup
  $ipconfig = Get-AzureRmNetworkInterface | Where-Object { $_.Id -eq $vm.NetworkInterfaceIDs[0]} | Get-AzureRmNetworkInterfaceIpConfig
  $publicIp = Get-AzureRmPublicIpAddress | Where-Object { $_.Id -eq $ipconfig.PublicIpAddress.Id } |Select-Object IpAddress

  # remove ssh trusted hosts
  Get-SSHTrustedHost | Remove-SSHTrustedHost

  $sshCredentials = New-Object System.Management.Automation.PSCredential ($User, $secpasswd)
  $sshSession = New-SSHSession -ComputerName $publicIp.IpAddress -Port 22 -Credential $sshCredentials -AcceptKey

  foreach ($command in $commands) {
    $status = Invoke-SSHCommand -SSHSession $sshSession -Command $command
    if ($status.ExitStatus -ne 0) {
        break
    } else {
        Write-Host $status.Output
    }
  }

  $null = Remove-SSHSession -SSHSession $sshSession

  if ($status.ExitStatus -ne 0) {
    throw $status.Output
  }
}
