#Requires -RunAsAdministrator



Function VMWare_ExportSettings {
    $VMwareWorkstationConfigParameters | Export-Clixml -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force
}

Function VMWware_RetrieveSettings {
    
    try {
          [void]::(Get-Variable -Name VMwareWorkstationConfigParameters -ErrorAction Stop)
        }
    catch {
        $Global:VMwareWorkstationConfigParameters = New-Object PSObject
    }  
   
    try {        
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Name) ) {
            Write-Message -Message "Gathering Information about the VMWare Workstation installation on your computer: $(hostname)" -MessageType INFORMATION
            
            $Global:VMwareWorkstationConfigParameters = Get-CimInstance  -ClassName Win32_Product -ErrorAction Stop | Where-Object { $_.Name -like "*VMware Workstation" } | Select-Object Name, Version, InstallLocation
            Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) found" -MessageType INFORMATION 
        }
    }
    catch {
        Write-Message -Message "Cannot load the CimInstance Win32_Product $($error[0])" -MessageType ERROR
        break
    }

    try {
        
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            
            Write-Message -Message "Could not find the installation folder in the registry. Please provide the VMWare $($VMwareWorkstationConfigParameters.Version) installation folder" -MessageType INFORMATION

            [int]$RetryRetrieveFolder            
            do {
                if ($FolderBrowserDialogPath = ShowFolder -Parameter GetInstallationPath) {
                    if (Test-Path $FolderBrowserDialogPath.FullName -ErrorAction Stop) {
            
                        if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation)) {
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -ErrorAction Stop
                        }

                        $Global:VMwareWorkstationConfigParameters.InstallLocation = $FolderBrowserDialogPath.DirectoryName
                        Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) Installlocation defined as: $($VMwareWorkstationConfigParameters.InstallLocation)" -MessageType INFORMATION
                        $RetryRetrieveFolder = 0
                    } 
                }
                else {
                        Write-Message -Message "Vmware Workstation installationfolder $($VMwareWorkstationConfigParameters.Version) could not be defined, Last retry" -MessageType ERROR
                }
                $RetryRetrieveFolder++

                if ($RetryRetrieveFolder -gt 1) {
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, please retry" -MessageType INFORMATION
                }

            } until (($RetryRetrieveFolder -ge 2) -or (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation))))
        }
    }
    catch {
         Write-Message -Message "Unknown Error occured $($error[0])" -MessageType ERROR 
    }
    finally {
        VMWare_ExportSettings
        Remove-Variable -Name FolderBrowserDialog,FolderBrowserDialogPath,RetryRetrieveFolder -ErrorAction SilentlyContinue
    }    
}

Function VMWare_ImportSettings {
    $VMWareImportSettings = "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml"

    try {
        if (Test-Path -Path $VMWareImportSettings -ErrorAction Stop) {
            $GLOBAL:VMwareWorkstationConfigParameters = Import-Clixml -Path $VMWareImportSettings -ErrorAction Stop
        }
        else {
            VMWware_RetrieveSettings
        }
    }
    catch {
        VMWware_RetrieveSettings
    }

    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters))) {
        
        if (!(Test-Path -Path $VMwareWorkstationConfigParameters.InstallLocation)) {
            VMWware_RetrieveSettings 
        }
    }
    Write-Message -Message "VMWareWorkstaion-API Settings Loaded" -MessageType INFORMATION
}

Function Get-VMWareWorkstationConfiguration 
{

}

VMWare_ImportSettings