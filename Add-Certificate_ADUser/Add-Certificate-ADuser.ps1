
#the Aduser must have a machting description filled with the folder name where the certificate is placed. Where-Object { $_.Description -Match $Directory.Name}

$DomainName = "test.lab.lan"
$ActiveDirectoryOrganizationUnit = "OU=1,OU=2,OU=3,DC=test,DC=lab,DC=lan"
$BaseFolder = "C:\Certificates\"

if ((!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Error "Run this script under a privileged account or put the files in folder where you have full control"
    Start-Sleep 10
    Exit
}
else {


    Start-Transcript -Path $("$($BaseFolder)\transcipt.log") -Append -Force

    Function Convert-CertficateToDerFormat {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateScript({
                if(-Not ($_ | Test-Path) ){
                    return $false
                }
                else {
                    return $true
                }
            })]
            [System.IO.FileInfo]$File
        )

        $File = $File.FullName
        try {
            $X509Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $X509Certificate.Import($File)
            $CertX509 = New-Item $File -ItemType File -Force
            $CertFileStream = $CertX509.OpenWrite()
            $CertX509Bytes = $X509Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            $CertFileStream.Write($CertX509Bytes,0, $CertX509Bytes.Length)
            $CertFileStream.Flush($true)
            $CertFileStream.Close()
            return $CertX509
        }
        catch {
            Write-Host "ERROR - Convert-Certficate:" $_ -ErrorAction Stop
        }
    }

    Function Import-AD {
        [cmdletbinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateScript({
                if(-Not ($_ | Test-Path) ){
                    return $false
                }
                else {
                    return $true
                }
            })]
            [System.IO.FileInfo]$Directory,
            [Parameter(Mandatory)]
            [string]$Cert
        )
       try {

        [void]::(Import-Module ActiveDirectory -ErrorAction Stop)

            $DomainController = "$(Get-ADDomainController -DomainName $DomainName -Discover -ForceDiscover -Service PrimaryDC | Select-Object -ExpandProperty HostName)"

            if ($DomainController) {
                $GetADUser = Get-AdUser -Server $DomainController -SearchBase $ActiveDirectoryOrganizationUnit -Filter * -Properties * | Where-Object { $_.Description -Match $Directory.Name} | Select-Object -ExpandProperty Name

                if ($GetADUser) {

                    $X509Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                    $X509Certificate.Import($Cert)

                    if ($X509Certificate) {

                        $UserCertificates = Get-ADUser $GetADUser -Properties Certificates | Select-Object Certificates
                        $AdUserThumbprints = @()

                        if ($UserCertificates) {

                            $UserCertificates.Certificates | ForEach-Object {
                                $AdUserThumbprints += New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $_
                            }
                                $X509ImportCertificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                                $X509ImportCertificate.Import($Cert)

                            if ($AdUserThumbprints -contains $X509ImportCertificate) {

                                $AdUserThumbprints | ForEach-Object { if ($_ -eq $X509ImportCertificate) { $Thumbprint = $_.Thumbprint} }
                                Write-Host "`n -------------------------------------------------------------------------------------------------------------------------------------------- `n"
                                Write-Host "The certificate with thumbprint: $($Thumbprint) from location: $($Cert) is already linked to the user: $($GetADUser)"
                            }
                            else{
                                Set-AdUser -Server $DomainController $GetADUser -Certificates @{add=$X509Certificate} -ErrorAction break
                                Write-Host "`n -------------------------------------------------------------------------------------------------------------------------------------------- `n"
                                Write-Host "Adding Certifcate on DC $($DomainController) under User: $($GetADUser). The Following Certificate $($X509Certificate.subject) with thumbprint $($X509Certificate.Thumbprint) and path $($Cert)"
                            }
                        }
                    }
                    else {
                        Write-Error "Couldnt import Certificate" $X509Certificate -ErrorAction Continue
                    }
                }
            }
            else {
                Write-Error "DomainController not Reachable" -ErrorAction Stop
            }
        }
        catch {
            Write-Host "`n -------------------------------------------------------------------------------------------------------------------------------------------- `n"
            Write-Host "Error adding on DC $($DomainController) under User: $($GetADUser) Certificate $($X509Certificate.subject) with thumbprint $($X509Certificate.Thumbprint)"
            Write-Error "ERROR - IMPORT-AD: " $_ -ErrorAction Continue
        }
    }

    try {

        $Certificates = Get-ChildItem -Path $BaseFolder -Force -Recurse -Include "*.cer","*.crt","*.der","*.p7b","*.pfx" | ForEach-Object {

            if ($_.Extension -eq ".p7b") {

                $CertutilArgs = @("-ca.chain","$($_.FullName)")
                [void]::(Start-Process "C:\Windows\System32\certutil.exe" -ArgumentList $CertutilArgs -PassThru)

                [void][Reflection.Assembly]::LoadWithPartialName("System.Security")

                $ReadCertificateData = [System.IO.File]::ReadAllBytes("$($_.FullName)")

                $CMSProvider = New-Object System.Security.Cryptography.Pkcs.SignedCms
                $CMSProvider.Decode($ReadCertificateData)

                foreach ($P7BCertificate in $CMSProvider.Certificates ) {
                    $P7BToCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $P7BCertificate
                    $CommonName = ([regex]'(?i)cn=(.+?),').Match($P7BToCert.Subject).Groups[1].Value

                    $WriteContent = @(
                    '-----BEGIN CERTIFICATE-----'
                    [System.Convert]::ToBase64String($P7BToCert.RawData, 'InsertLineBreaks')
                    '-----END CERTIFICATE-----'
                    )

                    $ExportToCertFile = Join-Path -Path $_.Directory -ChildPath "$($CommonName)_FromP7bToCert.p7b"
                    $WriteContent | Out-File -FilePath $ExportToCertFile -Encoding Ascii -Force
                }

                $ReadCertificateData.Clear()

                Convert-CertficateToDerFormat -File $ExportToCertFile
                Import-AD -Directory $_.Directory.FullName -Cert $ExportToCertFile
                Remove-Item  $ExportToCertFile -Force -ErrorAction SilentlyContinue
            }

            if ($_.Extension -eq ".cer" -or $_.Extension -eq ".crt"  -or $_.Extension -eq ".der"  -or $_.Extension -eq ".txt" ) {
                $ReadCertificate = Get-Content -First 1 -Path $_.FullName

                if ($ReadCertificate -eq "-----BEGIN CERTIFICATE-----" ) {
                    $Cert = Convert-CertficateToDerFormat -File $_.FullName
                    Import-AD -Directory $_.Directory.FullName -Cert $Cert
                }
                else {
                    $TempFile = $(New-TemporaryFile).FullName
                    Start-Process "C:\Windows\System32\certutil.exe" -ArgumentList "-f -Encode $($_.FullName) $($_.FullName)" -PassThru -NoNewWindow -Wait -RedirectStandardOutput $TempFile -ErrorAction Stop
                    $Content = Get-Content -Path $TempFile -ErrorAction Stop | Select-Object -First 3 | Select-Object -Last 1

                    if ($Content -eq "CertUtil: -encode command completed successfully.") {
                        $Cert = Convert-CertficateToDerFormat -File $_.FullName
                        Import-AD -Directory $_.Directory.FullName -Cert $($Cert)
                    }
                    else {
                        $Content = Get-Content -Path $TempFile -ErrorAction SilentlyContinue
                        Write-Host "Error $($Content) on $($_.FullName)"
                    }
                }
            }

            if ($_.Extension -eq ".pfx") {
                Write-Host "PFX File found, please enter the password for the PFX file" $_.FullName
                Get-PfxCertificate -FilePath $_.FullName 
                Export-Certificate -FilePath $_.FullName.Replace("pfx","cer") -Type CERT
                $Cert = Convert-CertficateToDerFormat -File  $_.FullName.Replace("pfx","cer")
                Import-AD -Directory $_.Directory.FullName -Cert $($Cert)
                Remove-Item  -Path  $_.FullName.Replace("pfx","cer") -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
         Write-Error "Error Processing certificates import" $_ -ErrorAction Continue
    }
    
    Write-Host "total certificate files found $($certificates).Count under $($BaseFolder)"
    
    Stop-Transcript
}
