<#
#menu maken. 

opties in het menu bouwen

Verder uitwerken.

        Write-host "Checking SystemHealth"
        DISM.exe /Online /Cleanup-Image /ScanHealth
        sfc /ScanNow
        
https://learn.microsoft.com/en-us/troubleshoot/windows-server/deployment/fix-windows-update-errors?source=recommendations 
https://gist.github.com/mavaddat/24a03fd07aa059806d58c39b06acee70#file-resetwindowsupdate-ps1-L61
#>


<#
if (!((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))  {
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-Noprofile -file "{0}"' -f ($myinvocation.MyCommand.Definition))
}
#>

param([switch]$Elevated)

function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}
<#
if (!((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))  {
    
    $ProcessName = $([System.Diagnostics.Process]::GetCurrentProcess())
    switch ([System.Diagnostics.Process]::GetCurrentProcess().ProcessName) {

        Powershell_ise {
            Start-Process $ProcessName.ProcessName -Verb RunAs -ArgumentList ('-file "{0}"' -f $($myinvocation.MyCommand.Definition))
            Stop-Process $ProcessName.id
        }

        Powershell {
            Start-Process $ProcessName.ProcessName -Verb RunAs -ArgumentList ('-file "{0}"' -f ($myinvocation.MyCommand.Definition))
            exit
       }
    }
    
 }
 #>

Function ServiceHandler {
    [cmdletbinding()]
        Param 
        (        
            [Parameter(Mandatory)]
            [ValidateSet('START', 'STOP', 'GET')]
            [string]$Action,
            
            [Parameter(Mandatory)]
            [ValidateSet('True','False','0','1')]
            $ReturnResponseOutput
        )

        $ReturnResponseOutput = [System.Convert]::ToBoolean($ReturnResponseOutput)

        switch ($Action) {

            START { $Global:ReturnResponse = $StartServices | ForEach-Object { Start-Service -Name $_  -PassThru } }
            STOP { $Global:ReturnResponse = $StopServices | ForEach-Object { Stop-Service -Name $_ -Force -PassThru -ErrorAction Stop } }
            GET { $Global:ReturnResponse = $Services | ForEach-Object { Get-Service -Name $_ } }
        }        

        if ($ReturnResponseOutput) {
            return $ReturnResponse
        }
}
Function ResetWSUS {
        
    $ComputerInfo = Get-ComputerInfo

    if ($($ComputerInfo.OsName -replace "[\Wa-zA-Z]","") -lt '11') {            
        if (Test-Path -Path "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\" -PathType Container) {                
            Write-Host "`n Creating Backup files from the qmgr files and deleting the original files> Microsoft Windows updates uses these file for caching. for Windows 10 or below " 
            $Files = Get-ChildItem "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.*" | Where-Object { $_.Extension -eq ".dat" }
            Write-Host "`n $($Files) Found, Creating backup "
            $Files | ForEach-Object {            
                $RenamedFile = $($_.Fullname + ".bak")            
                Copy-Item -Path $_.Fullname -Destination $RenamedFile -WhatIf     
                if (Test-Path -Path $RenamedFile) {
                    Write-Host "`n $($RenamedFile) Found, Deleting original file $($_.fullname) "
                    Remove-Item $_.FullName -Force -WhatIf
                }
            }
        }
        else {
            Write-Host "`n $("$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\") Folder not found, skipping... "  -ForegroundColor white -BackgroundColor red 
        }
    }
    else {
        Write-Host "`n $($ComputerInfo.OsName) detected, skipping step for qmgr backup/deletion " -ForegroundColor White -BackgroundColor Green
    }

    $MicrosoftWindowsUpdateFolders = New-Object -TypeName System.Collections.ArrayList
    $TMPMicrosoftWindowsUpdateFolders = New-Object -TypeName System.Collections.ArrayList
    $MicrosoftWindowsUpdateFolders = @("%Systemroot%\SoftwareDistribution\DataStore","%Systemroot%\SoftwareDistribution\Download","%Systemroot%\System32\catroot2")

    $MicrosoftWindowsUpdateFolders  | ForEach-Object {
        if ($_.split("\").StartsWith("%") -and $_.split("\").EndsWith("%")) {
            $TMPMicrosoftWindowsUpdateFolders += [System.Environment]::ExpandEnvironmentVariables($_)
        }       
    }

    $MicrosoftWindowsUpdateFolders = $TMPMicrosoftWindowsUpdateFolders 
    Remove-Variable $TMPMicrosoftWindowsUpdateFolders -ErrorAction SilentlyContinue

    $MicrosoftWindowsUpdateFolders | ForEach-Object {
        if (Test-Path -Path $_ -PathType Container) {
            Write-Host "`n $($_) Folder found, Creating backup folder "  -ForegroundColor white -BackgroundColor Green
                
            $RenameFolder = "$($_).bak"                
            Copy-Item -Path $_ -Destination $RenameFolder -Force -Recurse -WhatIf
            if (Test-Path -Path $RenameFolder) { 
                    Write-Host "`n $($RenameFolder) Folder found, Deleting folder $_ "  -ForegroundColor white -BackgroundColor Green
                    Remove-Item -Path $_ -Force -Recurse -WhatIf
            }                
        }
        else{
            Write-Host "$($_) Folder not found, skipping... `n"  -ForegroundColor white -BackgroundColor red
        }
    }

    #Reset the BITS service and the Windows Update service to the default security descriptors.
    Write-Host "`n Reset the BITS service and the Windows Update service to the default security descriptor."        
    cmd.exe /c "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    cmd.exe /c "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    Reset-WinhttpProxy -Direct

    if ($($ComputerInfo.OsName -replace "[\Wa-zA-Z]","") -eq '7') {
        proxycfg.exe -d
    }

    if ($ComputerInfo.OsName -like "*vista" -or $ComputerInfo.OsName -like "2008") { 
        bitsadmin.exe /reset /allusers 
    }

    # (re)Registering Dynamic Link Libraries
    $ListOfRegisteredDLLFiles = New-Object -TypeName System.Collections.ArrayList
    $RegisteredDLLFiles = @("atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll", "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll")
    
    ForEach ($DLLFile in $RegisteredDLLFiles) {
        Write-Progress -Activity "Registering DLL-Files in $($ComputerInfo.OsName) for Microsoft Windows Updates to work properly" -Status "Registering $DLLFile" -PercentComplete (((1+$RegisteredDLLFiles.IndexOf($DLLFile))/ $RegisteredDLLFiles.Count)*100)
        if(Test-Path -Path "$($env:windir)\System32\$($DLLFile)" -PathType Leaf){
	        $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
	        $ProcessStartInfo.Filename = "regsvr32.exe"
	        $ProcessStartInfo.Arguments = "/s" + $DLLFile
	        $ProcessStartInfo.RedirectStandardError = $true
	        $ProcessStartInfo.CreateNoWindow = $true
	        $ProcessStartInfo.UseShellExecute = $false
            Start-Sleep -Milliseconds 300
	        [void]::($ListOfRegisteredDLLFiles.Add(@([Diagnostics.Process]::Start($ProcessStartInfo),$ProcessStartInfo)))
	    }
    }
    #foreach ($process in $ListOfRegisteredDLLFiles){ if ( -not ($process.ExitCode -ceq 0 )) {if($process.ExitCode -eq 3) {$codeThree += @($process.Arguments.Replace("/s ","")) } elseif($process.ExitCode -eq 4) {$codeFour += @($process.Arguments.Replace("/s ","")) } }}
        
    sc.exe config wuauserv start= auto
	sc.exe config bits start= delayed-auto
	sc.exe config cryptsvc start= auto
	sc.exe config TrustedInstaller start= demand
	sc.exe config DcomLaunch start= auto
}
Function RunResetWUS {
    $Error.Clear()
    $Services = New-Object -TypeName System.Collections.ArrayList
    $Services = @("BITS","wuauserv","appidsvc","cryptsvc")
    ServiceHandler -Action GET -ReturnResponseOutput False
    $StopServices = New-Object -TypeName System.Collections.ArrayList
    $ReturnResponse | ForEach-Object {   
        if ($_.status -ne "Stopped") {        
                $StopServices += $_.name
        }
    }
    Write-Host "`n Stopping Services" -ForegroundColor White -BackgroundColor Green
    ServiceHandler -Action STOP -ReturnResponseOutput True

    if (($ReturnResponse.Status | Sort-Object -Unique).count -eq "1") {
        ResetWSUS
        $StartServices = New-Object -TypeName System.Collections.ArrayList
        ServiceHandler -Action GET -ReturnResponseOutput False
        $ReturnResponse | ForEach-Object {   
            if ($_.status -ne "Started") {        
                    $StartServices += $_.name
            }
        }
        ServiceHandler -Action START -ReturnResponseOutput True
    }
    else {
        Write-Host "`, Niet alle services konden gestopt worden. Het script gaat stoppen" -ForegroundColor White -BackgroundColor red
        Start-Sleep 5
        exit
    }

    $msg = "`n Reboot needed, do you want to reboot this computer $($env:computername)?" 
    do {
        $response = Read-Host -Prompt $msg
        if ($response -eq 'y' -or $response -eq "Yes" ) {
            Restart-Computer -Confirm
        }
    } until ($response -eq 'n' -or $response -eq "No")    
}
Function RestoreWSUSBAK {

}
Function DeleteWSUSBackup {
    
}

Function CheckDismSystemHealth {
    DISM.exe /Online /Cleanup-Image /CheckHealth
    DISM.exe /Online /Cleanup-Image /ScanHealth
}
Function RestoreDismSystemHealth {
    DISM.exe /Online /Cleanup-Image /Restore
}

Function SFCVerifyOnly {        
    sfc.exe /VerifyOnly
}
Function SFCScanNow {        
    sfc.exe /ScanNow
}

Function PressAnyKey {
    Write-Host " Press any key to continue..."
    read-host
}

$MainMenu = {
    Write-Host " **********************************************************************************************"
    Write-Host " *                                                                                            *"
    Write-Host " *                            Microsoft Windows Error Solutions                               *"
    Write-Host " *                                                                                            *"
    Write-Host " **********************************************************************************************"
    Write-Host
    Write-Host "   1.) Reset Microsoft Windows Update Services"
    Write-Host "   2.) Restore Microsoft Windows Update Services settings made earlier with option 1"
    Write-Host "   3.) Delete Microsoft Windows Update Services backup settings made earlier with option 1" 
    Write-Host
    Write-Host "   4.) Check SystemHealth (SFC)"
    Write-Host "   5.) Restore SystemHealth (SFC)"
    Write-Host
    Write-Host "   6.) Check SystemHealth (DISM)"
    Write-Host "   7.) Restore SystemHealth (DISM)"
    Write-Host
    Write-Host "   8.) Quit"
    Write-Host
    Write-Host " **********************************************************************************************"
    Write-Host
    Write-Host " Select an option and press Enter: "  -nonewline
}

Do {
    cls
    Invoke-Command $MainMenu
    $Select = Read-Host        
    if (!($(Get-Location).Path -eq [System.Environment]::SystemDirectory)) { Set-Location $([System.Environment])::SystemDirectory }
        
    Switch ($Select)
        {
            1 { 
                Write-Host "`n Start resetting Microsoft Windows Update services "
                RunResetWUS  
                }
            2 {
                Write-Host "`nRestore Microsoft Windows Update Services settings" 
                RestoreWSUSBAK
                }
            3 { 
                Write-Host "`n Delete Microsoft Windows Update Services backup settings "
                DeleteWSUSBackup         
                }
            4 { 
                Write-Host "`n Starting sfc Healthcheck verifying only "
                SFCVerifyOnly         
                }
            5 {
                Write-Host "`n Starting sfc Health Restore"
                SFCScanNow
                }
            6 { 
                Write-Host "`n Starting dism Healthcheck verifying only "
                CheckDismSystemHealth
                }
            7 { 
                Write-Host "`n Starting dism restoring Health"
                RestoreDismSystemHealth 
                }
            8 {
                Write-Host "`n You've pressed choice $($Select): The script will be quitting in 5 seconds..." -BackgroundColor red -ForegroundColor white
                Start-Sleep 3
                Write-Host " GoodBye" -BackgroundColor red -ForegroundColor white
                Start-Sleep 2
                Exit
            }
        }
    PressAnyKey
}
While ($Select -ne 8)