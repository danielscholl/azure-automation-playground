<#
    .DESCRIPTION
        Playing with Azure Automation Runbook using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Daniel Scholl
        LASTEDIT: 
#>

workflow manage-linux
{
    $Computer = "vm0" 
                 
    $SSHCred = Get-AutomationPSCredential -Name 'LinuxCredential' 
    $Connection = Get-AutomationConnection -Name 'LinuxConnection'                        
    $SSHKey = Get-AutomationVariable -Name 'SSHKey' 

    
    Invoke-SSHCommand `
		-ComputerName $Connection `
		-Credential $SSHCred `
		[-KeyString $SSHKey `
		[-Port 22] `
		-ScriptBlock {
            cd /bin
            ls
        }
}