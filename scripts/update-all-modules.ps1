param(
    [Parameter(Mandatory=$true)]
    [String] $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [String] $AutomationAccountName,

    [Parameter(Mandatory=$false)]
    [String] $AzCredential = 'AzureRunAsConnection',

    [Parameter(Mandatory=$false)]
    [string] $subscriptionName = 'MSDN-CCIT'

)

# try {
 
#     'Logging in to Azure...'
#     $cred = Get-AutomationPSCredential -Name $AzCredential
#     Add-AzureRmAccount -Credential $cred
# }
# catch {
#     if(!$cred) {
#         throw "Connection $AzCredential not found."
#     }
#     else {
#         throw $_.Exception
#     }
# }
set-azurermContext -SubscriptionName $subscriptionName

$Modules = Get-AzureRmAutomationModule `
    -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AutomationAccountName

$AzureRMProfileModule = Get-AzureRmAutomationModule `
    -ResourceGroupName $ResourceGroupName `
    -AutomationAccountName $AutomationAccountName `
    -Name 'AzureRM.Profile'

# Force AzureRM.Profile to be evaluated first since some other modules depend on it 
# being there / up to date to import successfully
$Modules = @($AzureRMProfileModule) + $Modules

foreach($Module in $Modules) {

    $Module = $Modules = Get-AzureRmAutomationModule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $Module.Name
    
    $ModuleName = $Module.Name
    $ModuleVersionInAutomation = $Module.Version

    Write-Output "Checking if module '$ModuleName' is up to date in your automation account"

    $Url = "https://www.powershellgallery.com/api/v2/Search?`$filter=IsLatestVersion&searchTerm=%27$ModuleName%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40" 
    Write-output $Url
    $SearchResult = Invoke-RestMethod -Method Get -Uri $Url -UseBasicParsing

    if(!$SearchResult) {
        Write-Error "Could not find module '$ModuleName' in PowerShell Gallery."
    }
    # elseif($SearchResult.Length -and $SearchResult.Length -gt 1) {
    #     Write-Error "Module name '$ModuleName' returned multiple results. Please specify an exact module name."
    # }
    else {
        $PackageDetails = Invoke-RestMethod -Method Get -UseBasicParsing -Uri $SearchResult.id 
        $LatestModuleVersionOnPSGallery = $PackageDetails.entry.properties.version

        # if($ModuleVersionInAutomation -ne $LatestModuleVersionOnPSGallery) {
        #     Write-Output "Module '$ModuleName' is not up to date. Latest version on PS Gallery is '$LatestModuleVersionOnPSGallery' but this automation account has version '$ModuleVersionInAutomation'"
        #     Write-Output "Importing latest version of '$ModuleName' into your automation account"

        #     $ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"

        #     # Find the actual blob storage location of the module
        #     do {
        #         $ActualUrl = $ModuleContentUrl
        #         $ModuleContentUrl = (Invoke-WebRequest -Uri $ModuleContentUrl -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location 
        #     } while($ModuleContentUrl -ne $Null)

        #     $Module = New-AzureRmAutomationModule `
        #         -ResourceGroupName $ResourceGroupName `
        #         -AutomationAccountName $AutomationAccountName `
        #         -Name $ModuleName `
        #         -ContentLink $ActualUrl
                
        #     while($Module.ProvisioningState -ne 'Succeeded' -and $Module.ProvisioningState -ne 'Failed') {
        #         Start-Sleep -Seconds 10
            
        #         $Module = Get-AzureRmAutomationModule `
        #             -ResourceGroupName $ResourceGroupName `
        #             -AutomationAccountName $AutomationAccountName `
        #             -Name $ModuleName

        #         Write-Output 'Polling for import completion...'
        #     }

        #     if($Module.ProvisioningState -eq 'Succeeded') {
        #         Write-Output "Successfully imported latest version of $ModuleName"
        #     }
        #     else {
        #         Write-Error "Failed to import latest version of $ModuleName"
        #     }   
        # }
        # else {
        #     Write-Output "Module '$ModuleName' is up to date."
        # }
   }
}