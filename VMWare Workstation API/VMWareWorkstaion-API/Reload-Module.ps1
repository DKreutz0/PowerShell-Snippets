
if ($(Get-Module VMWareWorkstaion-API).Path) {
    Remove-Module VMWareWorkstaion-API -Force
    Import-Module VMWareWorkstaion-API -Force
}
else {
    Import-Module VMWareWorkstaion-API -Force
}