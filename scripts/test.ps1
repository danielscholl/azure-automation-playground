$Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName

if (!$Machines) {
    Write-Output "No VMs were found in your subscription."
} else {
  foreach ($VM in $Machines) {
    Write-Output "Starting down $VM.Name"
    Start-AzureRmVM -Name $VM.Name -ResourceGroupName $ResourceGroupName
  }
}
