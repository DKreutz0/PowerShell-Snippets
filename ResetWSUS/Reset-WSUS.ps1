<#
#menu maken. 

opties in het menu bouwen

Verder uitwerken.

        Write-host "Checking SystemHealth"
        DISM.exe /Online /Cleanup-Image /ScanHealth
        sfc /ScanNow

#>


if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    
    if (!($(Get-Location).Path -eq [System.Environment]::SystemDirectory)) { Set-Location $([System.Environment])::SystemDirectory }

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

                START { $Global:ReturnResponse = $StartServices | foreach { Start-Service -Name $_  -PassThru } }
                STOP { $Global:ReturnResponse = $StopServices | foreach { Stop-Service -Name $_ -Force -PassThru -ErrorAction Stop } }
                GET { $Global:ReturnResponse = $Services | foreach { Get-Service -Name $_ } }
            }        

            if ($ReturnResponseOutput) {
                return $ReturnResponse
            }
    }

    Function ResetWSUS {
        
        $ComputerInfo = Get-ComputerInfo

        if ($($ComputerInfo.OsName -replace "[\Wa-zA-Z]","") -lt '11') {            
            if (Test-Path -Path "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\" -PathType Container) {                
                Write-Host "`n Creating Backup files from the qmgr files and deleting the original files> Microsoft Windows updates uses these file for caching. for Windows 10 or below `n" 
                $Files = Get-ChildItem "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.*" | Where-Object { $_.Extension -eq ".dat" }
                Write-Host "`n $($Files) Found, Creating backup `n"
                $Files | foreach {            
                    $RenamedFile = $($_.Fullname + ".bak")            
                    Copy-Item -Path $_.Fullname -Destination $RenamedFile -WhatIf     
                    if (Test-Path -Path $RenamedFile) {
                        Write-Host "`n $($RenamedFile) Found, Deleting original file $($_.fullname) `n"
                        Remove-Item $_.FullName -Force -WhatIf
                    }
                }
            }
            else {
                Write-Host "$ENV:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\ Folder not found, skipping... `n"  -ForegroundColor white -BackgroundColor red 
            }
        }
        else {
            Write-Host "`n $($ComputerInfo.OsName) detected, skipping step for qmgr backup/deletion `n" -ForegroundColor White -BackgroundColor Green
        }

        $MicrosoftWindowsUpdateFolders = New-Object -TypeName System.Collections.ArrayList
        $TMPMicrosoftWindowsUpdateFolders = New-Object -TypeName System.Collections.ArrayList
        $MicrosoftWindowsUpdateFolders = @("%Systemroot%\SoftwareDistribution\DataStore","%Systemroot%\SoftwareDistribution\Download","%Systemroot%\System32\catroot2")

        $MicrosoftWindowsUpdateFolders  | foreach {
            if ($_.split("\").StartsWith("%") -and $_.split("\").EndsWith("%")) {
                $TMPMicrosoftWindowsUpdateFolders += [System.Environment]::ExpandEnvironmentVariables($_)
            }       
        }

        $MicrosoftWindowsUpdateFolders = $TMPMicrosoftWindowsUpdateFolders 
        Remove-Variable $TMPMicrosoftWindowsUpdateFolders -ErrorAction SilentlyContinue

        $MicrosoftWindowsUpdateFolders | foreach {
            if (Test-Path -Path $_ -PathType Container) {
                Write-Host "`n $($_) Folder found, Creating backup folder `n"  -ForegroundColor white -BackgroundColor Green
                
                $RenameFolder = "$($_).bak"                
                Copy-Item -Path $_ -Destination $RenameFolder -Force -Recurse -WhatIf
                if (Test-Path -Path $RenameFolder) { 
                     Write-Host "`n $($RenameFolder) Folder found, Deleting folder $_ `n"  -ForegroundColor white -BackgroundColor Green
                     Remove-Item -Path $_ -Force -Recurse -WhatIf
                }
                    

            }
            else{
                Write-Host "$($_) Folder not found, skipping... `n"  -ForegroundColor white -BackgroundColor red
            }
        }

        #Reset the BITS service and the Windows Update service to the default security descriptors.
        Write-Host "`nReset the BITS service and the Windows Update service to the default security descriptor. `n"        
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
    
        foreach ($DLLFile in $RegisteredDLLFiles) {
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

    $Error.Clear()
    $Services = "BITS","wuauserv","appidsvc","cryptsvc"
    ServiceHandler -Action GET -ReturnResponseOutput False
    
    $StopServices = New-Object -TypeName System.Collections.ArrayList
    $ReturnResponse | foreach {   
       if ($_.status -ne "Stopped") {        
             $StopServices += $_.name
       }
    }
    Write-Host "Stopping Services" -ForegroundColor White -BackgroundColor Green
    ServiceHandler -Action STOP -ReturnResponseOutput True

    if (($ReturnResponse.Status | Sort-Object -Unique).count -eq "1") {
        ResetWSUS
        $StartServices = New-Object -TypeName System.Collections.ArrayList
        ServiceHandler -Action GET -ReturnResponseOutput False
        $ReturnResponse | foreach {   
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

    $msg = "`n Reboot needed, do you want to reboot computer $($env:computername)?" 
    do {
        $response = Read-Host -Prompt $msg
        if ($response -eq 'y' -or $response -eq "Yes" ) {
            Restart-Computer -Confirm
        }
    } until ($response -eq 'n' -or $response -eq "No")

}
else {
    Write-Host "`n This Script must be runned as administrator or under a privileged account"
    Start-Sleep 5
    Exit
}
