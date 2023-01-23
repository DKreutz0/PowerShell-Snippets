<#
+---------------+--------------------------------------------------------------------------------+
| Script        | CheckCRL-URL.ps1                                                               |
| Version       | 1.0                                                                            |
| Documentation | ToDo                                                                           |
+---------------+--------------------------------------------------------------------------------+
| Korte Omschrijving:                                                                            |
|   PowerShell Script for validation CRL-validity                                                |
+----------------------+-------------------------------------------------------------------------+
#>

try
{
    $Urls = "http://crl.quovadisglobal.com/quovadispkioverheidserverca2020.crl","http://crl4.digicert.com/DigiCertHighAssuranceEVRootCA.crl"

    $TLS12Protocol = [System.Net.SecurityProtocolType] 'Ssl3 , Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $TLS12Protocol

    if (!($(Get-Location).Path -eq [System.Environment]::SystemDirectory)) { Set-Location $([System.Environment]::SystemDirectory) }

    if ($(Resolve-Path certutil.exe).Path)  {
        foreach ($Url in $Urls) {

            $DownloadPath = Join-Path $ENV:TEMP ($Url).Split("/")[$(($Url.ToCharArray() | Where-Object { $_ -eq '/' } | Measure-Object).Count)]
            $WebRequest = Invoke-WebRequest -Uri $Url -OutFile $DownloadPath -PassThru

            if ($WebRequest.StatusCode -eq 200) {
                $ExpirationDate = [System.DateTime]::ParseExact($(get-date($(.\certutil.exe -Dump $DownloadPath | Select-String "NextUpdate:").Line.Trim().Replace("NextUpdate: ", $([string]::Empty))) -format ($(Get-Culture).DateTimeFormat.ShortDatePattern)), $(Get-Culture).DateTimeFormat.ShortDatePattern, ([Globalization.CultureInfo]::CreateSpecificCulture($(Get-Culture).Name)))
                $CompareDates = New-TimeSpan -Start $((Get-Date -Format "dd/MM/yyyy")).ToString() -End $Expirationdate -ErrorAction Stop
                $Count = ($DownloadPath.ToCharArray() | Where-Object { $_ -eq '\' } | Measure-Object).Count

                if (($CompareDates).days -gt 15) {
                    Write-Host "CRL $(($DownloadPath).Split("\")[$count]) with NextUpdate $(Get-Date($ExpirationDate) -Format $(Get-Culture).DateTimeFormat.ShortDatePattern) is still valid for $($($CompareDates).Days) days `n" -ForegroundColor Green
                }
                else {
                    if (($CompareDates).days -gt 0) {
                        Write-Host "CRL $(($DownloadPath).Split("\")[$Count]) with NextUpdate $(Get-Date($ExpirationDate) -Format $(Get-Culture).DateTimeFormat.ShortDatePattern) will expire in $($($CompareDates).Days) days " -ForegroundColor Magenta
                    }
                    else {
                        Write-Host "CRL $(($DownloadPath).Split("\")[$Count]) with NextUpdate $(Get-Date($ExpirationDate) -Format $(Get-Culture).DateTimeFormat.ShortDatePattern) is already $($($CompareDates).Days) days expired " -ForegroundColor Red
                    }
                }
            }
            else {
                throw("Cannot connect to the url: $($WebRequest.BaseResponse.ResponseUri) with status: $($WebRequest.StatusDescription) and statuscode: $($WebRequest.StatusCode)")
            }
        }
    }
    else {
        throw("Certutil.exe cannot be found in $(Get-Location)!")
    }
}
catch {
    throw("$($error[0])")
}
finally {
    Remove-Variable DownloadPath,DumpCrl,Expirationdate,Url,Urls,CompareDates,Count,WebRequest,TLS12Protocol -ErrorAction SilentlyContinue
}