

if (!((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))  {
    Write-Host "Cannot become a privileged user. The script is aborting" -BackgroundColor red -ForegroundColor white
    Start-Sleep 5
    Exit
} 
else {
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}


#place code here.