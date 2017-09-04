    Param(
        [Parameter(Mandatory = $true)]
        [String] $user,
        [Parameter(Mandatory = $true)]
        [String] $password,
        [Parameter(Mandatory = $true)]
        [String] $ResourceGroup,
        [Parameter(Mandatory = $true)]
        [String] $MachineName,
        [Parameter(Mandatory = $true)]
        [String[]] $commands
    )


$vm = Get-AzureRMVM -Name $MachineName -ResourceGroup $ResourceGroup
#$endpoint = Get-AzureEndpoint -Name "ssh" -VM $vm

Write-Output "hello world"



Get-AzureRmNetworkInterface -ResourceGroupName test3 | 
    ForEach { 
        $Interface = $_.Name; $IPs = $_ | 
            Get-AzureRmNetworkInterfaceIpConfig | Select PrivateIPAddress; 
            Write-Host $Interface $IPs.PrivateIPAddress 
    }

Get-AzureRmNetworkInterface -ResourceGroupName test3 | 
    ForEach { 
        $Interface = $_.Name; $IPs = $_ |
            Write-Host $Interface
    }


$vm = Get-AzureRmVM -ResourceGroupName "test3" -Name "abctest3-vm"

$IPConfig = Get-AzureRmNetworkInterface | Where { $_.Id -eq $vm.NetworkInterfaceIDs[0]} | 
    Get-AzureRmNetworkInterfaceIpConfig 

$ip = Get-AzureRmPublicIpAddress | where { $_.Id -eq $IPConfig.PublicIpAddress.Id } |select IpAddress


#or
Get-AzureRmResource -ResourceId $MyVM.NetworkInterfaceIDs[0] | Get-AzureRmNetworkInterface