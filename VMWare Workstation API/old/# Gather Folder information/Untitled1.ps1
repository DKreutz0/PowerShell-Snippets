Function ShowFolder {

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -ErrorAction Stop
    $FolderBrowserDialog.Description = "Select the Folder where VMWARE Workstation $($VMWareWorkStationSettings.Version) is installed"
    $FolderBrowserDialog.ShowNewFolderButton = $false
    $FolderBrowserDialog.RootFolder = "MyComputer"    
    $FolderBrowserDialog.SelectedPath = $([System.Environment]::GetFolderPath('ProgramFilesX86') + "\vmware\")
    $FolderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true }))

    $FolderBrowserDialog.SelectedPath
  
}

Function FindFiles {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('GetVMWareWorkstationInstallationPath')]
        $Parameter
    )
    switch ($Parameter) {

        GetVMWareWorkstationInstallationPath { $FolderBrowserFile = "vmware.exe" }
    }
    
    $FolderBrowserDialogPath = ShowFolder

    if ($FolderBrowserDialogPath[0] -eq "OK") {
        
        if (Test-Path -Path $FolderBrowserDialogPath[1]) {
            $GetExecPath = Get-ChildItem -Path $FolderBrowserDialogPath[1] -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $FolderBrowserFile }
            if ($null -eq $GetExecPath) {
                return $GetExecPath = "EMPTY"
            }

            if (Test-Path -Path $GetExecPath.fullname) {
                return $GetExecPath
            }
        }
        else {
            Write-Message -Message "The Path is not available anymore $($error[0])" -MessageType ERROR
        }
    }
    if ($FolderBrowserDialogPath[0] -eq "CANCEL") {
                    write-host "5"
        return $GetExecPath = "CANCEL"
    }
}


FindFiles -Parameter GetVMWareWorkstationInstallationPath

