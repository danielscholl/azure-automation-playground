﻿<# Copyright (c) 2017, cloudcodeit.com
.Synopsis
   Installs a Run As Account as defined by Azure Documentation
   https://docs.microsoft.com/en-us/azure/automation/automation-update-account-powershell

.DESCRIPTION
    This script will create a RunAsAccount using a self signed certifcate.  Once created the user must upload the certifcate as follows

    Please upload the .cer fromat of %USERPROFILE%\AppData\Local\Temp\<your_cert>.cer to the Management store by following the steps below.
        1. Log in to the Microsoft Azure Management portal (https://manage.windowsazure.com) and select Settings -> Management Certificates.
        2. Click upload and upload the .cer 

.EXAMPLE
    .\New-RunAsAccount.ps1 -ResourceGroup <ResourceGroupName> `
        -AutomationAccountName <NameofAutomationAccount> `
        -SubscriptionId <SubscriptionId> `
        -ApplicationDisplayName <DisplayNameofAADApplication> `
        -SelfSignedCertPlainPassword <StrongPassword> `
        -CreateClassicRunAsAccount $false
#>


#Requires -RunAsAdministrator
  Param (
 [Parameter(Mandatory=$true)]
 [String] $ResourceGroup,

 [Parameter(Mandatory=$true)]
 [String] $AutomationAccountName,

 [Parameter(Mandatory=$true)]
 [String] $ApplicationDisplayName,

 [Parameter(Mandatory=$true)]
 [String] $SubscriptionId,

 [Parameter(Mandatory=$true)]
 [Boolean] $CreateClassicRunAsAccount,

 [Parameter(Mandatory=$true)]
 [String] $SelfSignedCertPlainPassword,

 [Parameter(Mandatory=$false)]
 [String] $EnterpriseCertPathForRunAsAccount,

 [Parameter(Mandatory=$false)]
 [String] $EnterpriseCertPlainPasswordForRunAsAccount,

 [Parameter(Mandatory=$false)]
 [String] $EnterpriseCertPathForClassicRunAsAccount,

 [Parameter(Mandatory=$false)]
 [String] $EnterpriseCertPlainPasswordForClassicRunAsAccount,

 [Parameter(Mandatory=$false)]
 [ValidateSet("AzureCloud","AzureUSGovernment")]
 [string]$EnvironmentName="AzureCloud",

 [Parameter(Mandatory=$false)]
 [int] $SelfSignedCertNoOfMonthsUntilExpired = 12
 )

 function CreateSelfSignedCertificate([string] $keyVaultName, [string] $certificateName, [string] $selfSignedCertPlainPassword,
                               [string] $certPath, [string] $certPathCer, [string] $selfSignedCertNoOfMonthsUntilExpired ) {
 $Cert = New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation cert:\LocalMachine\My `
    -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
    -NotAfter (Get-Date).AddMonths($selfSignedCertNoOfMonthsUntilExpired)

 $CertPassword = ConvertTo-SecureString $selfSignedCertPlainPassword -AsPlainText -Force
 Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPath -Password $CertPassword -Force | Write-Verbose
 Export-Certificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $certPathCer -Type CERT | Write-Verbose
 }

 function CreateServicePrincipal([System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert, [string] $applicationDisplayName) {  
 $CurrentDate = Get-Date
 $keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
 $KeyId = (New-Guid).Guid

 $KeyCredential = New-Object  Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADKeyCredential
 $KeyCredential.StartDate = $CurrentDate
 $KeyCredential.EndDate= [DateTime]$PfxCert.GetExpirationDateString()
 $KeyCredential.EndDate = $KeyCredential.EndDate.AddDays(-1)
 $KeyCredential.KeyId = $KeyId
 $KeyCredential.CertValue  = $keyValue

 # Use key credentials and create an Azure AD application
 $Application = New-AzureRmADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $KeyId) -KeyCredentials $KeyCredential
 $ServicePrincipal = New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId
 $GetServicePrincipal = Get-AzureRmADServicePrincipal -ObjectId $ServicePrincipal.Id

 # Sleep here for a few seconds to allow the service principal application to become active (ordinarily takes a few seconds)
 Sleep -s 15
 $NewRole = New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
 $Retries = 0;
 While ($NewRole -eq $null -and $Retries -le 6)
 {
    Sleep -s 10
    New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
    $NewRole = Get-AzureRMRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
    $Retries++;
 }
    return $Application.ApplicationId.ToString();
 }

 function CreateAutomationCertificateAsset ([string] $resourceGroup, [string] $automationAccountName, [string] $certifcateAssetName,[string] $certPath, [string] $certPlainPassword, [Boolean] $Exportable) {
 $CertPassword = ConvertTo-SecureString $certPlainPassword -AsPlainText -Force   
 Remove-AzureRmAutomationCertificate -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
 New-AzureRmAutomationCertificate -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Path $certPath -Name $certifcateAssetName -Password $CertPassword -Exportable:$Exportable  | write-verbose
 }

 function CreateAutomationConnectionAsset ([string] $resourceGroup, [string] $automationAccountName, [string] $connectionAssetName, [string] $connectionTypeName, [System.Collections.Hashtable] $connectionFieldValues ) {
 Remove-AzureRmAutomationConnection -ResourceGroupName $resourceGroup -AutomationAccountName $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
 New-AzureRmAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
 }

 Import-Module AzureRM.Profile
 Import-Module AzureRM.Resources

 $AzureRMProfileVersion= (Get-Module AzureRM.Profile).Version
 if (!(($AzureRMProfileVersion.Major -ge 2 -and $AzureRMProfileVersion.Minor -ge 1) -or ($AzureRMProfileVersion.Major -gt 2)))
 {
    Write-Error -Message "Please install the latest Azure PowerShell and retry. Relevant doc url : https://docs.microsoft.com/powershell/azureps-cmdlets-docs/ "
    return
 }

 Login-AzureRmAccount -EnvironmentName $EnvironmentName
 $Subscription = Select-AzureRmSubscription -SubscriptionId $SubscriptionId

 # Create a Run As account by using a service principal
 $CertifcateAssetName = "AzureRunAsCertificate"
 $ConnectionAssetName = "AzureRunAsConnection"
 $ConnectionTypeName = "AzureServicePrincipal"

 if ($EnterpriseCertPathForRunAsAccount -and $EnterpriseCertPlainPasswordForRunAsAccount) {
 $PfxCertPathForRunAsAccount = $EnterpriseCertPathForRunAsAccount
 $PfxCertPlainPasswordForRunAsAccount = $EnterpriseCertPlainPasswordForRunAsAccount
 } else {
   $CertificateName = $AutomationAccountName+$CertifcateAssetName
   $PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
   $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
   $CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")
   CreateSelfSignedCertificate $KeyVaultName $CertificateName $PfxCertPlainPasswordForRunAsAccount $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired
 }

 # Create a service principal
 $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
 $ApplicationId=CreateServicePrincipal $PfxCert $ApplicationDisplayName

 # Create the Automation certificate asset
 CreateAutomationCertificateAsset $ResourceGroup $AutomationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount $PfxCertPlainPasswordForRunAsAccount $true

 # Populate the ConnectionFieldValues
 $SubscriptionInfo = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
 $TenantID = $SubscriptionInfo | Select TenantId -First 1
 $Thumbprint = $PfxCert.Thumbprint
 $ConnectionFieldValues = @{"ApplicationId" = $ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId}

 # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
 CreateAutomationConnectionAsset $ResourceGroup $AutomationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues

 if ($CreateClassicRunAsAccount) {
     # Create a Run As account by using a service principal
     $ClassicRunAsAccountCertifcateAssetName = "AzureClassicRunAsCertificate"
     $ClassicRunAsAccountConnectionAssetName = "AzureClassicRunAsConnection"
     $ClassicRunAsAccountConnectionTypeName = "AzureClassicCertificate "
     $UploadMessage = "Please upload the .cer format of #CERT# to the Management store by following the steps below." + [Environment]::NewLine +
             "Log in to the Microsoft Azure Management portal (https://manage.windowsazure.com) and select Settings -> Management Certificates." + [Environment]::NewLine +
             "Then click Upload and upload the .cer format of #CERT#"

      if ($EnterpriseCertPathForClassicRunAsAccount -and $EnterpriseCertPlainPasswordForClassicRunAsAccount ) {
      $PfxCertPathForClassicRunAsAccount = $EnterpriseCertPathForClassicRunAsAccount
      $PfxCertPlainPasswordForClassicRunAsAccount = $EnterpriseCertPlainPasswordForClassicRunAsAccount
      $UploadMessage = $UploadMessage.Replace("#CERT#", $PfxCertPathForClassicRunAsAccount)
 } else {
      $ClassicRunAsAccountCertificateName = $AutomationAccountName+$ClassicRunAsAccountCertifcateAssetName
      $PfxCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".pfx")
      $PfxCertPlainPasswordForClassicRunAsAccount = $SelfSignedCertPlainPassword
      $CerCertPathForClassicRunAsAccount = Join-Path $env:TEMP ($ClassicRunAsAccountCertificateName + ".cer")
      $UploadMessage = $UploadMessage.Replace("#CERT#", $CerCertPathForClassicRunAsAccount)
      CreateSelfSignedCertificate $KeyVaultName $ClassicRunAsAccountCertificateName $PfxCertPlainPasswordForClassicRunAsAccount $PfxCertPathForClassicRunAsAccount $CerCertPathForClassicRunAsAccount $SelfSignedCertNoOfMonthsUntilExpired
 }

 # Create the Automation certificate asset
 CreateAutomationCertificateAsset $ResourceGroup $AutomationAccountName $ClassicRunAsAccountCertifcateAssetName $PfxCertPathForClassicRunAsAccount $PfxCertPlainPasswordForClassicRunAsAccount $false

 # Populate the ConnectionFieldValues
 $SubscriptionName = $subscription.Subscription.SubscriptionName
 $ClassicRunAsAccountConnectionFieldValues = @{"SubscriptionName" = $SubscriptionName; "SubscriptionId" = $SubscriptionId; "CertificateAssetName" = $ClassicRunAsAccountCertifcateAssetName}

 # Create an Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
 CreateAutomationConnectionAsset $ResourceGroup $AutomationAccountName $ClassicRunAsAccountConnectionAssetName $ClassicRunAsAccountConnectionTypeName $ClassicRunAsAccountConnectionFieldValues

 Write-Host -ForegroundColor red $UploadMessage
 }