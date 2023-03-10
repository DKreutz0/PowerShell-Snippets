<#
+---------------+--------------------------------------------------------------------------------+
| Script        | VSCode_Extensions_loader.ps1                                                   |
| Version       | 1.0                                                                            |
| Documentation | ToDo                                                                           |
+---------------+--------------------------------------------------------------------------------+
| Korte Omschrijving:                                                                            |
|   Script om VSIX files in visual studio offline te installeren.                                |
|   er dient een syteem variabel aanwezig te zijn en dat is current_vscode                       |
|   in DEM is dit env_current_vscode onder vars                                                  |
|   # https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell                   |
+----------------------+-------------------------------------------------------------------------+
#>



$ExtensionNetworkPath = "D:\VSCode 1.74.3\CachedExtensionVSIXs\" #$(Get-DfsnFolder -Path $($(Get-DfsnRoot).Path + "\*") | Where-Object { $_.Path -like "*Appv*"}).Path + "\Vscode Extensions\"

# Hierna niets meer wijzigen.

Add-Type -assemblyname System.IO.Compression.FileSystem,System.XML,PresentationCore,PresentationFramework -ErrorAction Stop

if (!($(Get-Location).Path -eq [System.Environment]::SystemDirectory)) { Set-Location $([System.Environment])::SystemDirectory }

$VSCodePath = "C:\Program Files\Microsoft VS Code\bin\code.cmd" #Join-Path -Resolve "code.cmd" -Path $([System.Environment]::ExpandEnvironmentVariables($env:current_vscode))

if ($null -ne $VSCodePath) {
    
    $MessageTitle = '[Visual Studio Extension Loader] - An error has occured.'
    $MessageImage = 'Hand'
    $MessageButton = '0'

    $VSVersion = Invoke-Command -ScriptBlock { cmd.exe /c "$VSCodePath" --version } -ErrorAction SilentlyContinue

    If ((Test-Path -path $ExtensionNetworkPath)) {
        If ((Test-Path -path $($([System.Environment]::ExpandEnvironmentVariables($env:USERPROFILE) + "\.vscode\")))) {
            Try {
           
                $LoadExtensions = Get-ChildItem -path $ExtensionNetworkPath -Recurse | Where-Object { $_.Extension -eq ".vsix" }
        
                If ($LoadExtensions -ne $null) {
                    $VisualCodeExtensions = New-Object System.Data.DataTable 'VisualStudioCodeExtensions'
                    $newcolumn = New-Object System.Data.DataColumn 'PackageName',([string]); $VisualCodeExtensions.columns.add($newcolumn)
                    $newcolumn = New-Object System.Data.DataColumn 'Catagories',([string]); $VisualCodeExtensions.columns.add($newcolumn)
                    $newcolumn = New-Object System.Data.DataColumn 'ExtensionName',([string]); $VisualCodeExtensions.columns.add($newcolumn)
                    $newcolumn = New-Object System.Data.DataColumn 'Installed',([string]); $VisualCodeExtensions.columns.add($newcolumn)
                    $newcolumn = New-Object System.Data.DataColumn 'Path',([string]); $VisualCodeExtensions.columns.add($newcolumn)
                    $newcolumn = New-Object System.Data.DataColumn 'Compatible Above',([string]); $VisualCodeExtensions.columns.add($newcolumn)

                    Foreach ($item in $LoadExtensions) { 
      
                        $zip = [io.compression.zipfile]::OpenRead($item.FullName)
                        $zipfile = $zip.Entries | where-object { $_.Name -eq "extension.vsixmanifest"}
                        $stream = $zipfile.open()

                        $reader = New-Object IO.StreamReader($stream)
                        [xml]$xml = $reader.ReadToEnd()

                        $reader.Close()
                        $stream.Close()  
                
                        $row = $VisualCodeExtensions.NewRow()
                        $row.PackageName=($xml.PackageManifest.Metadata.DisplayName)
                        $row.Catagories= ($xml.PackageManifest.Metadata.Categories)
                        $row.Path=($item.FullName)
                        $row.ExtensionName=($xml.PackageManifest.Metadata.Identity.Publisher + "." + $xml.PackageManifest.Metadata.Identity.id + "-" + $xml.PackageManifest.Metadata.Identity.Version)

                        $Path = Join-Path -Path $([System.Environment]::ExpandEnvironmentVariables($env:USERPROFILE)) -ChildPath "\.vscode\Extensions\$($xml.PackageManifest.Metadata.Identity.Publisher + "." + $xml.PackageManifest.Metadata.Identity.id + "-" + $xml.PackageManifest.Metadata.Identity.Version)"
                     
                        if ($(Test-Path -Path $Path) -eq $true) {  
                            $row.Installed=("Installed")
                        }
                        if ($(Test-Path -Path $Path) -eq $false) {  
                            $row.Installed=("Not Installed")
                        }
                
                        if ($($xml.PackageManifest.Metadata.Properties.ChildNodes | Where-Object { $_.Id -like "*Microsoft.VisualStudio.Code.Engine*" })) {
                            $IsExtensionCompatible = $($xml.PackageManifest.Metadata.Properties.ChildNodes | Where-Object { $_.Id -like "*Microsoft.VisualStudio.Code.Engine*" } | Select-Object -ExpandProperty Value).replace("^",[string]::Empty) 
                            $IsExtensionCompatible = $IsExtensionCompatible -Replace "[a-zA-Z]"
                        }
                        else {
                            $IsExtensionCompatible = $null                    
                        }
                
                        if ($null -eq $IsExtensionCompatible ) {
                            #Extensie is gewoon shit! XMl format van een dooie marmot! 
                            #Omdat de maker van de extensie zich geen eens aan het standaard XML format kan houden! Voegen we zijn meuk maar gewoon toe! Vscode vang vanzelf wel af of het werkt!
                            $row.'Compatible Above'=("Could not determine compatibility")
                            $VisualCodeExtensions.Rows.Add($row)
                        }
                        else {
                            if ($VSVersion[0] -gt $IsExtensionCompatible) {
                                $row.'Compatible Above'=($IsExtensionCompatible)
                                $VisualCodeExtensions.Rows.Add($row)
                            }
                        }                    
                    }

                    if (($VSCodePath -eq "code.cmd") -or ($null -eq $vscodepath) -and ($([System.Environment]::ExpandEnvironmentVariables($env:current_vscode)).Substring($([System.Environment]::ExpandEnvironmentVariables($env:current_vscode)).Length -1) -ne "\" ))  {                    
                            $MessageBody = "Controleer de variable in DEM, betreft current_vscode variable. Deze  klopt niet of mist"
                            [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$MessageButton,$MessageImage)
                            Break
                        }
                        else {        
                            if ((Test-Path -path $VSCodePath)) {
                               $title = "Visual Studio - $($VSVersion[0] + " - " +  $VSVersion[1] ) - [ Selecteer de Visual Studio code addons die je graag wilt installeren. ]"
                               $Tasks_Todo = $VisualCodeExtensions | Out-GridView -Title $title -PassThru | Where-Object { $_.Installed -eq "Not Installed" }
                            }
                            else {        
                                $MessageBody = "Controleer de variable in DEM, betreft current_vscode variable. Deze  klopt niet of mist"
                                [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$MessageButton,$MessageImage)
                                Break 
                            }
                        } 
                    
                    foreach ($taskTodo in $Tasks_Todo) {
                        if ((Test-Path $(Join-Path -Path $([System.Environment]::ExpandEnvironmentVariables($env:USERPROFILE)) -ChildPath "\.vscode\Extensions\$($TaskTodo.Extensionname)")) -eq $false) {                    
                            $Argument = "--install-extension " + "`"$($tasktodo.path)`"" + " --verbose --force"
                            Start-Process -FilePath "code.cmd" -WorkingDirectory $(Join-Path -Path $([System.Environment]::ExpandEnvironmentVariables($env:current_vscode)) -ChildPath \) -ArgumentList $Argument -Wait
                        }                    
                    }
                }
                else {
                    $MessageBody = "Er zijn geen Extensie bestanden gevonden, het script zal stoppen. Raadpleeg een Windows Beheerder"
                    [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$MessageButton,$MessageImage)            
                    Break; 
                }       
            }
            catch {
                $MessageBody = "An error has occcurred : $($_) $($Error[0].ScriptStackTrace). Raadpleeg een Windows beheerder"
                [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$MessageButton,$MessageImage)                     
            }
        }
        Else {
            $MessageImage = 'Asterisk'
            $MessageBody = "VSCode Profiel bestaat niet, $($env:USERPROFILE + "\.vscode") Start Visual studio code eerst een keer op!"
        }
    }
    Else { 
        $MessageBody = "Extensie folder $($ExtensionNetworkPath) bestaat niet."
    }
}
else {
    $MessageBody = 'Kan het pad naar de Visual Studio Package niet bepalen. Controleer de DEM variabel current_vscode en of de package wel geladen is!'
}

if ($MessageBody) {
    [System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$MessageButton,$MessageImage) | Out-Null
}