rv -name * -ErrorAction SilentlyContinue
rv VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
Remove-Module VMWareWorkstaion-API -Force -ErrorAction SilentlyContinue 
Import-Module VMWareWorkstaion-API -Force -ErrorAction SilentlyContinue 
Test-ModuleManifest -Path "$PSScriptRoot\VMWareWorkstaion-API.psd1"


<#
vm.cfg inlezen en vmrest.exe afmaken

$EnumSpecialFolders = [Environment+SpecialFolder]::GetNames([Environment+SpecialFolder]) | Sort-Object 
$GetSpecialFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
$GetUserProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
#>

