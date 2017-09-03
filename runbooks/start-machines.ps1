<#
    .DESCRIPTION
        This runbook starts all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be started.

    .NOTES
        AUTHOR: Daniel Scholl
#>
workflow start-machines {
	Param(
  	    [string]$ResourceGroupName
	)
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
            Write-Error -Message $ErrorMessage `
                -ErrorAction Stop
		}
		
		$Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName
		if (!$Machines) {
  		    Write-Output "No VMs were found in the Resource Group."
		} else {
  		$Machines | ForEach-Object {
    		Write-Output "Starting Server $_.Name"
    		Start-AzureRMVM -Name $_.Name `
                -ResourceGroupName $ResourceGroupName
  		    }
		}
	}
}