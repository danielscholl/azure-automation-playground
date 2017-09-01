<#
    .DESCRIPTION
        Play with executing commands over SSH.

    .NOTES
        AUTHOR: Daniel Scholl
#>
workflow linux-command
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
