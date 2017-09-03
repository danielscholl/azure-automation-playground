<# 
	This PowerShell script was automatically converted to PowerShell Workflow so it can be run as a runbook.
	Specific changes that have been made are marked with a comment starting with “Converter:”
#>
<#
    .DESCRIPTION
        This runbook stops all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be stopped.

    .NOTES
        AUTHOR: Daniel Scholl
#>
workflow stop-machines {
	Param(
  	[string]$ResourceGroupName
	
	)
	# Converter: Wrapping initial script in an InlineScript activity, and passing any parameters for use within the InlineScript
	# Converter: If you want this InlineScript to execute on another host rather than the Automation worker, simply add some combination of -PSComputerName, -PSCredential, -PSConnectionURI, or other workflow common parameters (http://technet.microsoft.com/en-us/library/jj129719.aspx) as parameters of the InlineScript
	inlineScript {
		$ResourceGroupName = $using:ResourceGroupName
		
		
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
  		Write-Error `
    -Message $ErrorMessage `
    -ErrorAction Stop
		}
		
		$Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
		if (!$Machines) {
  		Write-Output "No VMs were found in the Resource Group."
		} else {
  		$Machines | ForEach-Object {
    		
    		Write-Output "Starting Server $_.Name"
    		Stop-AzureRMVM -Name $_.Name `
      -ResourceGroupName $ResourceGroupName `
      -Force
  		}
		}
		
		
		
	}
}