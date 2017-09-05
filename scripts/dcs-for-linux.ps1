
$ResourceGroup = 'automate-demo3'
$location = 'southcentralus'
$storageAccount = 'aaautomatedemo3'
$vmName = 'vm'
$containerName = 'linux-dsc'


$DSCFile=".\dsc\localhost.mof"
$blob="localhost.mof"



#region                Prepare IaaS Storage
############################################################

$Key = (Get-AzureRmStorageAccountKey -Name $storageAccount `
          -ResourceGroupName $ResourceGroup).Value[0]

$Context = New-AzureStorageContext `
  -StorageAccountName $storageAccount `
  -StorageAccountKey $Key

$storageContainer = Get-AzureStorageContainer -Name $containerName `
    -Context $Context

if(!$storageContainer) {
    New-AzureStorageContainer -Name $containerName `
        -Context $Context `
        -Permission Off
}

#endregion ################################################




#region                Create DSC File
############################################################
Configuration ExampleConfiguration{

    Import-DscResource -Module nx

    Node  "localhost"{
    nxFile ExampleFile {

        DestinationPath = "/tmp/example"
        Contents = "hello world `n"
        Ensure = "Present"
        Type = "File"
    }

    }
}

ExampleConfiguration -OutputPath: ".\dsc"

#endregion ################################################





#region                 Upload DSC File
################################################

# Upload DSC File (Blob)
Set-AzureStorageBlobContent `
    -Context $Context `
    -Container $containerName `
    -File $DSCFile `
    -Force



# Create an Adhoc SAS Token (Blob)
$url = New-AzureStorageBlobSASToken -Context $Context `
  -Container $containerName `
  -Blob $blob `
  -Permission r `
  -StartTime (Get-Date) `
  -ExpiryTime (Get-Date).AddHours(1) `
  -FullUri


#endregion ################################################







#region           Execute DSC Extension
################################################

$publicConfig = "{
  'Mode': 'Push',
  'FileUri': '${url}'
}"


$privateConfig = "{ 
    'StorageAccountName':  '${storageAccount}',
    'StorageAccountKey': '${key}'
}"


$extensionName = 'DSCForLinux'
$publisher = 'Microsoft.OSTCExtensions'
$version = '2.0'
Set-AzureRmVMExtension -Name $extensionName `
    -Publisher $publisher `
    -ExtensionType $extensionName `
    -TypeHandlerVersion $version `
    -ResourceGroupName $ResourceGroup `
    -VMName $vmName `
    -Location $location ` 
    -SettingString $publicConfig `
    -ProtectedSettingString $privateConfig


#endregion ################################################


