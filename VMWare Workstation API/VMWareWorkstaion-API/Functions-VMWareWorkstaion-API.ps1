#Requires -RunAsAdministrator

Function Write-Message {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [String]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('ERROR', 'INFORMATION', 'WARNING', 'CRITICAL')]
        $MessageType     
    )
    switch ($MessageType) {
        ERROR { 
            $ForegroundColor = 'White'
            $BackgroundColor = 'Red'
            $MessageStartsWith = "[ERROR] - " 
        }
        INFORMATION {
            $ForegroundColor = 'White'
            $BackgroundColor = 'blue'
            $MessageStartsWith = "[INFORMATION] - " 
        }
        WARNING {
            $ForegroundColor = 'White'
            $BackgroundColor = 'DarkYellow'
            $MessageStartsWith = "[WARNING] - " 
        }
    }
   Write-Host "$MessageStartsWith $Message" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

Function ShowFolder {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('GetInstallationPath')]
        $Parameter
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop      
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -ErrorAction Stop
    $FolderBrowserDialog.Description = "Select de Folder where VMWARE Workstation $($VMWareWorkStationSettings.Version) is installed"
    $FolderBrowserDialog.ShowNewFolderButton = $false
    $FolderBrowserDialog.rootfolder = "MyComputer"
    [void]::($FolderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true })))
    
    switch ($Parameter) {

        GetInstallationPath { $FolderBrowserDialogPath = Get-ChildItem -Path $FolderBrowserDialog.SelectedPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "vmware.exe" } }
    }
    return $FolderBrowserDialogPath
}