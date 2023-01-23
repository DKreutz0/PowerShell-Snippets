<#
+---------------+--------------------------------------------------------------------------------+
| Script        | CheckCRL-CA.ps1                                                                |
| Version       | 1.0                                                                            |
| Documentation | ToDo                                                                           |
+---------------+--------------------------------------------------------------------------------+
| Korte Omschrijving:                                                                            |
|   Script voor het ophalen en controleren op de geldigehid van de CRL's                         |
+----------------------+-------------------------------------------------------------------------+
#>

if (!($(Get-Location).Path -eq [System.Environment]::SystemDirectory)) { Set-Location $([System.Environment]::SystemDirectory) }

if ($(Resolve-Path certutil.exe).Path) {

    # Search for CRL'S in the RootCertificate(s)
    $FoundCA = .\certutil.exe -dump | Select-String "Config:" | ForEach-Object { $_.line.replace("Config:",([string]::Empty)).trim().replace("``",([string]::Empty)).replace("'",([string]::Empty))}

    if ($FoundCA) {

        $DummyFile  = New-TemporaryFile | Select-Object -ExpandProperty FullName
        $Today = Get-Date

        foreach ( $CurrentCA in $FoundCA) {

            Remove-Item $DummyFile -Force -ErrorAction SilentlyContinue
            [void](certutil.exe -config "$($CurrentCA)" -getcrl "$($DummyFile)")

            $FoundUrls = .\certutil.exe -dump "$($DummyFile)" | Select-String "\.crl" | ForEach-Object { $_.line.replace("URL=", ([string]::Empty)).Trim() }
            $ExpirationDate = [System.DateTime]::ParseExact($(get-date($(.\certutil.exe -Dump $DummyFile | Select-String "NextUpdate:").Line.Trim().Replace("NextUpdate: ", $([string]::Empty))) -format ($(Get-Culture).DateTimeFormat.ShortDatePattern)), $(Get-Culture).DateTimeFormat.ShortDatePattern, ([Globalization.CultureInfo]::CreateSpecificCulture($(Get-Culture).Name)))
            $CompareDatesCA = New-TimeSpan -Start $Today -End $ExpirationDate
            if (($CompareDatesCA).Days -gt 30) {
                Write-Host "CRL from ROOTCA [ $($CurrentCA) ] with NextUpdate $ExpirationDate is still valid for $(($CompareDatesCA).Days) days" -ForegroundColor Green
            }
            elseif (($CompareDatesCA).Days -gt 0 ){
                Write-Host "CRL from ROOTCA [ $($CurrentCA) ] with NextUpdate $ExpirationDate will expire in $(($CompareDatesCA).Days) days " -ForegroundColor Magenta
            }
            else {
                 Write-Host "CRL from ROOTCA [ $($CurrentCA) ] with NextUpdate $ExpirationDate is already $(($CompareDatesCA).Days) days expired " -ForegroundColor Red
            }
        }
        # Search for distribution points in the RootCertificate(s)
        foreach ($Url in $FoundUrls) {
            $DownLoadPath = $(New-TemporaryFile).FullName
            $WebRequest = Invoke-WebRequest -Uri $Url -OutFile $DownLoadPath -PassThru

            if ($WebRequest.StatusCode -eq 200) {
                $ExpirationDate = [System.DateTime]::ParseExact($(Get-Date(.\certutil.exe -Dump $DummyFile | Select-String "NextUpdate:").Line.Trim().Replace("NextUpdate: ", $([string]::Empty)) -Format 'dd-MM-yyyy HH:mm'), "dd-MM-yyyy HH:mm", $null)
                $CompareDatesCA = New-TimeSpan -Start $Today -End $ExpirationDate
                $strSubMsg  = ([string]::Empty)

                if (($CompareDatesCA).Days -ne $CompareDatesCA.Days) { $strSubMsg = " - This CRL is different from the CA " } 
                if (($CompareDatesCA).Days -gt 30) {
                    Write-Host "CRL from Distributionpoint [ $($Url) ] with NextUpdate $ExpirationDate is still valid for $(($CompareDatesCA).Days) days" -NoNewline -ForegroundColor Green
                }
                elseif (($CompareDatesCA).Days -gt 0 ){
                    Write-Host "CRL from Distributionpoint [ $($Url) ] with NextUpdate $ExpirationDate will expire in $(($CompareDatesCA).Days) days " -NoNewline -ForegroundColor Magenta
                }
                else {
                     Write-Host "CRL from Distributionpoint [ $($Url) ] with NextUpdate $ExpirationDate is already $(($CompareDatesCA).Days) days expired " -NoNewline -ForegroundColor Red
                }
                if ($strSubMsg.Trim() -eq ([string]::Empty)) { Write-Host "" } else { Write-Host "$($strSubMsg)" -ForegroundColor White -BackgroundColor Red }
                Remove-Item -Path $DownLoadPath -Force

            }
            else {
                throw("Unable to download file $( $WebRequest.StatusCode + " "  + $WebRequest.StatusDescription) $Error[0] ")
            }
        }
    }
    else {
        Throw("No Certificate autorities could be found or retrieved")
    }
    Remove-Variable ResolvedPath,FoundCA,DummyFile,Today,currentCA,FoundUrls,ExpirationDate,CompareDatesCA,Url,FoundUrls,DownLoadPath,WebRequest,strSubMsg -ErrorAction SilentlyContinue
}
else {
    throw("Certutil can't be found.")
}