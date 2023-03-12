
Remove-Module VMWareWorkstaion-API -Force -ErrorAction SilentlyContinue 
Import-Module VMWareWorkstaion-API -Force -ErrorAction SilentlyContinue

Test-ModuleManifest -Path "$PSScriptRoot\VMWareWorkstaion-API.psd1"

$VMwareWorkstationConfigParameters