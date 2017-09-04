
Param(
  [Parameter(Mandatory = $true)]
  [String] $Name,
  [Parameter(Mandatory = $true)]
  [String] $ResourceGroup,
  [Parameter(Mandatory = $true)]
  [String] $user,
  [Parameter(Mandatory = $true)]
  [securestring] $secpasswd
)

$automation = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup
$credential = New-Object System.Management.Automation.PSCredential ($User, $secpasswd)

New-AzureRmAutomationCredential -Name $Name `
   -ResourceGroupName $ResourceGroup `
   -AutomationAccountName $automation.AutomationAccountName `
   -Value $credential
