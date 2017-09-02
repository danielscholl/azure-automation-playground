Function Install-PoshSsh
{
    # https://github.com/darkoperator/Posh-SSH
    # http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/

    if(-not(Get-Module -name posh-ssh))
    {
        $webclient = New-Object System.Net.WebClient
        $url = "https://github.com/darkoperator/Posh-SSH/archive/master.zip"
        Write-Host "Downloading latest version of Posh-SSH from $url" -ForegroundColor Cyan
        $file = "$($env:TEMP)\Posh-SSH.zip"
        $webclient.DownloadFile($url,$file)
        Write-Host "File saved to $file" -ForegroundColor Green
        $targetondisk = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules"
        New-Item -ItemType Directory -Force -Path $targetondisk | out-null
        $shell_app=new-object -com shell.application
        $zip_file = $shell_app.namespace($file)
        Write-Host "Uncompressing the Zip file to $($targetondisk)" -ForegroundColor Cyan
        $destination = $shell_app.namespace($targetondisk)
        $destination.Copyhere($zip_file.items(), 0x10)
        Write-Host "Renaming folder" -ForegroundColor Cyan
        Rename-Item -Path ($targetondisk+"\Posh-SSH-master") -NewName "Posh-SSH" -Force
        Write-Host "Module has been installed" -ForegroundColor Green
        Import-Module -Name posh-ssh
        #Get-Command -Module Posh-SSH
    }
}


Function Create-Vm
{
    Param(
        [Parameter(Mandatory = $true)]
        [String] $user,
        [Parameter(Mandatory = $true)]
        [String] $password,
        [Parameter(Mandatory = $true)]
        [String] $serviceName,
        [Parameter(Mandatory = $true)]
        [String] $machineName,
        [Parameter(Mandatory = $true)]
        [String] $location
    )

    <#
        $user = "webplu"
        $password = "Passw0rd!"
        $serviceName = "test-vm"
        $machineName = "test-vm-1"
        $location = "West Europe"
    #>

    $service = Get-AzureService -ServiceName $serviceName

    if (!$service) {
        Write-Host "Creating service " $serviceName
        $service = New-AzureService -ServiceName $serviceName -Location $location
    }

    Write-Host "Creating VM " $machineName

    #and image retrieved from Get-AzureVMImage | Select ImageName
    $imageName = "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-14_04_1-LTS-amd64-server-20140927-en-us-30GB"

    $vmc = New-AzureVMConfig -Name $machineName -InstanceSize "Small" -Image $imageName -AvailabilitySetName $serviceName

    $null = $vmc | Add-AzureProvisioningConfig -Linux -LinuxUser $user -Password $password
    $null = $vmc | New-AzureVM -ServiceName $serviceName -WaitForBoot

    $vm = Get-AzureVM -Name $machineName -ServiceName $serviceName

<# open some ports
    $mainRabbitPort = 5672
    $mgmtPort = 15672

    $null = Add-AzureEndpoint -VM $vm -LocalPort $mainRabbitPort -PublicPort $mainRabbitPort -Name "RabbitMQ-Main" -Protocol tcp -LBSetName "RabbitMQ-LB-MAIN" -ProbePort $mainRabbitPort -ProbeProtocol tcp -ProbeIntervalInSeconds 15
    $null = Add-AzureEndpoint -VM $vm -LocalPort $mgmtPort -PublicPort $mgmtPort -Name "RabbitMQ-MGMT" -Protocol tcp -LBSetName "RabbitMQ-LB-MGMT" -ProbePort $mgmtPort -ProbeProtocol tcp -ProbeIntervalInSeconds 15

    $null = $vm | Update-AzureVM
#>

    Write-Host $machineName " created!"
}


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
