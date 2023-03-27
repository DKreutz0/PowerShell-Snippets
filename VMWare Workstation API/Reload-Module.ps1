Remove-Variable -name * -ErrorAction SilentlyContinue
Remove-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
Remove-Module VMWareWorkstation-API -Force -ErrorAction SilentlyContinue 
Import-Module VMWareWorkstation-API -Force -ErrorAction SilentlyContinue 
Test-ModuleManifest -Path "$PSScriptRoot\VMWareWorkstation-API.psd1"


<#
vm.cfg inlezen en vmrest.exe afmaken
$EnumSpecialFolders = [Environment+SpecialFolder]::GetNames([Environment+SpecialFolder]) | Sort-Object 
$GetSpecialFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
$GetUserProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
#>