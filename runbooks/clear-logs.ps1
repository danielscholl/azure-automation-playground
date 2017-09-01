<#
    .DESCRIPTION
        Playing with Azure Automation Runbook using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Daniel Scholl
        LASTEDIT: 
#>


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Get all ARM resources from all resource groups
$ResourceGroup = 'vm-docker-swarm-azure'
$Machines = Get-AzureRmVm -ResourceGroupName $ResourceGroup

#Specify the command to execute
$PublicConfiguration = '{"commandToExecute": " python -c \"print "hello,azure!"\""}' 
$ExtensionName = 'CustomScriptForLinux'  
$Publisher = 'Microsoft.OSTCExtensions'  
$Version = '1.*'

foreach ($vm in $Machines)
{
    $name = $vm.Name

    # Get Status and if not started start it.
    $status = (Get-AzureRmVM -Name $name -ResourceGroupName $ResourceGroup -Status).Statuses[1].Code
    Write-Output ($vm.Name + "status: " + $status)

    if($status -eq 'PowerState/Running') {

        'Execute Script Extension'
        Set-AzureRmVMCustomScriptExtension -Name $ExtensionName `
            -VMName $vm.Name `
            -P
        Set-AzureVMExtension -ExtensionName $ExtensionName `
            -VM  $vm `
            -Publisher $Publisher `
            -Version $Version `
            -PublicConfiguration $PublicConfiguration  | Update-AzureVM

        
    } else {
        'We are not running'
    }

    
    #Start-AzureRmVM -Name $name -ResourceGroupName $ResourceGroup
    #Stop-AzureRmVM -Name $name -ResourceGroupName $ResourceGroup

}

