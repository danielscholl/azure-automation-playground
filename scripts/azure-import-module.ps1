# Requires that authentication to Azure is already established before running

param(
  [Parameter(Mandatory=$true)]
  [String] $ResourceGroupName,

  [Parameter(Mandatory=$true)]
  [String] $AutomationAccountName,

  [Parameter(Mandatory=$true)]
  [String] $ModuleName,

  # if not specified latest version will be imported
  [Parameter(Mandatory=$false)]
  [String] $ModuleVersion
)

$Url = "https://www.powershellgallery.com/api/v2/Search()?`$filter=IsLatestVersion&searchTerm=%27$ModuleName $ModuleVersion%27&targetFramework=%27%27&includePrerelease=false&`$skip=0&`$top=40"
$SearchResult = Invoke-RestMethod -Method Get -Uri $Url

if(!$SearchResult) {
  Write-Error "Could not find module '$ModuleName' on PowerShell Gallery."
}
elseif($SearchResult.C -and $SearchResult.Length -gt 1) {
  Write-Error "Module name '$ModuleName' returned multiple results. Please specify an exact module name."
}
else {
  $PackageDetails = Invoke-RestMethod -Method Get -Uri $SearchResult.id

  if(!$ModuleVersion) {
      $ModuleVersion = $PackageDetails.entry.properties.version
  }

  $ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"

  # Test if the module/version combination exists
  try {
      Invoke-RestMethod $ModuleContentUrl -ErrorAction Stop | Out-Null
      $Stop = $False
  }
  catch {
      Write-Error "Module with name '$ModuleName' of version '$ModuleVersion' does not exist. Are you sure the version specified is correct?"
      $Stop = $True
  }

  if(!$Stop) {

      # Find the actual blob storage location of the module
      do {
          $ActualUrl = $ModuleContentUrl
          $ModuleContentUrl = (Invoke-WebRequest -Uri $ModuleContentUrl -MaximumRedirection 0 -ErrorAction Ignore).Headers.Location
      } while($ModuleContentUrl -ne $Null)

      $ActualUrl
      # New-AzureRmAutomationModule `
      #     -ResourceGroupName $ResourceGroupName `
      #     -AutomationAccountName $AutomationAccountName `
      #     -Name $ModuleName `
      #     -ContentLink $ActualUrl
  }
}
