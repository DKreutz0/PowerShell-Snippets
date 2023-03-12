Test-ModuleManifest "C:\Users\Kreut\OneDrive\Bureaublad\VMWareWorkstaion-API\VMWareWorkstaion-API.psd1"
Import-Module "C:\Users\Kreut\OneDrive\Bureaublad\VMWareWorkstaion-API\VMWareWorkstaion-API.psd1"

Function Get-VMWareWorkstationConfiguration 
{
    Remove-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
    $global:VMwareWorkstationConfigParameters = New-Object PSObject

    try {
        #registry afhandeling
        # zorgen dat de installatie te vinden is
        <#
            Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like '*vmware workstation*'}
            $Apps = @()
            $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | { $_.displayName -like '*vmware workstation*'} # 32 Bit
            $Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | { $_.Name -like '*vmware workstation*'}            # 64 Bit
        #>
        
        $GetVMwareWorkstationConfigParameters = $(Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\VMware, Inc.\VMware Workstations\" -ErrorAction Stop) | Select-Object InstallPath
            if (!([String]::IsNullOrEmpty(($GetVMwareWorkstationConfigParameters)))) {
                $GetVMwareWorkstationConfigParameters | ForEach-Object { 
                    $VMwareWorkstationConfigParameters | Add-Member Noteproperty $GetVMwareWorkstationConfigParameters.psobject.Properties.Name $GetVMwareWorkstationConfigParameters.InstallPath
            }
        }        
    }
    catch {
        if ($Error[0].CategoryInfo.Reason.ToString() -eq 'ItemNotFoundException') {
            $VMwareWorkstationConfigParameters = Get-WmiObject -ClassName Win32_Product | Where-Object { $_.name -like "VMware Workstation*" } 
        }
    }


    try {
    # controleren op vmrest.cfg.
    #todo. zorgen dat de config goed komt. 
        $GetVMwareWorkstationConfigParameters = $(Get-Content -Path $("$([System.Environment]::ExpandEnvironmentVariables($env:USERPROFILE))\vmrest.cfg") -ErrorAction Stop | Select-String -Pattern 'PORT','USERNAME' -AllMatches ).line.Trim() 
            if (!([String]::IsNullOrEmpty(($GetVMwareWorkstationConfigParameters)))) {
                $GetVMwareWorkstationConfigParameters | ForEach-Object { 
                    $VMwareWorkstationConfigParameters | Add-Member Noteproperty $($_.split("=")[0]) $($_.split("=")[1]) 
            }
        }

    }
    catch {
        if ($Error[0].CategoryInfo.Reason.ToString()) {
           
            if (!(Get-Process | select ProcessName | Where-Object { $_.ProcessName -eq "vmrest" })) 
            {
                Start-Process -NoNewWindow -PassThru $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallPath -ChildPath "vmrest.exe") -ArgumentList "-d" 
                start-sleep 3
            }
        }        
    }

    try {
        # controleren op preferences.ini
        #todo. Zorgen dat de standaard lokatie gevonden wordt van de VM's als deze niet in het ini file is opgegeven.
        $GetVMwareWorkstationConfigParameters = $(Get-Content -Path $("$([System.Environment]::ExpandEnvironmentVariables($env:appdata))\vmware\preferences.ini") -ErrorAction Stop | Select-String -Pattern '.' -AllMatches ).line.Trim() 
        
         if (!([String]::IsNullOrEmpty(($GetVMwareWorkstationConfigParameters)))) {
            $GetVMwareWorkstationConfigParameters | ForEach-Object { 
                $ValueOne = $($_.Split("=")[0])
                $ValueTwo = $($_.Split("=")[1])

                if ($ValueOne.StartsWith(' ') -or $ValueOne.EndsWith(' ') -or $ValueTwo.StartsWith(' ') -or $ValueTwo.EndsWith(' ') ) {
                    $ValueOne = $($ValueOne).TrimStart().TrimEnd()
                    $ValueTwo = $ValueTwo.TrimStart().TrimEnd()
                }                
                $VMwareWorkstationConfigParameters | Add-Member Noteproperty $ValueOne $ValueTwo
            }
        }
    }
    catch {
        $Error[0].Exception
    }
}







