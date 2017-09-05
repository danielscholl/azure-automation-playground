Param(
    [Parameter(Mandatory = $true)]
    [String] $ResourceGroup,
    [Parameter(Mandatory = $true)]
    [String] $MachineName,
    [Parameter(Mandatory = $true)]
    [String] $StorageAccount
)

#Publish the configuration script into user storage
Publish-AzureRmVMDscConfiguration -ConfigurationPath ..\dsc\iisinstall.ps1 `
    -ResourceGroupName $ResourceGroup `
    -StorageAccountName $StorageAccount `
    -force

Set-AzureRmVmDscExtension -Version 2.21 `
    -ResourceGroupName $ResourceGroup `
    -VMName $MachineName `
    -ArchiveStorageAccountName $StorageAccount `
    -ArchiveBlobName iisinstall.ps1.zip `
    -AutoUpdate:$true `
    -ConfigurationName "IISInstall"