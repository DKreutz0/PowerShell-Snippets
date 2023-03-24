Function ShowFolder {

    [void]::(Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop)
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -ErrorAction Stop
    $FolderBrowserDialog.Description = "Select the Folder where VMWARE Workstation $($VMWareWorkStationSettings.Version) is installed"
    $FolderBrowserDialog.ShowNewFolderButton = $false
    $FolderBrowserDialog.rootfolder = "MyComputer"
    $FolderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true }))
    

    return $FolderBrowserDialog.SelectedPath
  
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
    
    $SelectPath = ShowFolder
    
    if ($SelectPath[0] -eq "OK") {
       $FolderBrowserDialogPath = Get-ChildItem -Path $SelectPath[1] -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $FolderBrowserFile } 
       
        if ($FolderBrowserDialogPath -ne "$FolderBrowserFile") {
            return $FolderBrowserDialogPath
        }
    }
    else {
        break
    }
}


$FolderBrowserDialogPath = FindFiles -Parameter GetVMWareWorkstationInstallationPath

