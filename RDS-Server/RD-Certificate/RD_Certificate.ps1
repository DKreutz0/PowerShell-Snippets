<#
.Description
Specify the connection brokers, in the script, then we can determine which is the active management server.
.EXAMPLE
	Local or Remote on ClientAccessName
		By FQDN
        $ConnectionBrokers = @("rdsserver01.testlab.lan","rdsserver02.testlab.lan" ) 
		or on a connectionbroker
		$ConnectionBrokers = (Get-RDConnectionBrokerHighAvailability).ActiveManagementServer
        or by searching AD
        $ConnectionBrokers = Get-ADComputer -Filter * -Properties * | Select DNSHostName, MemberOf | Where-Object { $_.MemberOf -match "CN=RDS Management Servers"} | Select-Object -ExpandProperty DNSHostName

	Local undefined
		$ConnectionBrokers = Get-RDServer -Connectionbroker (Get-RDConnectionBrokerHighAvailability).ActiveManagementServer

	Variables:
		# Must be $true or $false, If $false use a selfsigned certificate otherwise use the build-in ADCS
		# $UseWindowsCA = $true
		# Name of the Certificate template that is used for signing the request
		# $CATemplateName = "WebServer2003CLI"

		# Set own pre-defined roles. If not set, te script will determine which roles are already set. If no roles have a certificate set, all roles will get a certificate ( can create a warning on roles that arent specified ).
		#$RDCertificateRoles = "RDPublishing","RDRedirector","RDWebAccess","RDGateway"
#>

If ($null -eq $(Get-Module ActiveDirectory)) {
    Install-WindowsFeature RSAT-AD-PowerShell 
}

[void]::(Import-Module ActiveDirectory -ErrorAction Stop)
[void]::(Import-Module RemoteDesktop -ErrorAction Stop)

$ConnectionBrokers = Get-ADComputer -Filter * -Properties * | Select-Object DNSHostName, MemberOf | Where-Object { $_.MemberOf -match "CN=RDS Management Servers"} | Select-Object -ExpandProperty DNSHostName

# Must be $true or $false, If $false use a selfsigned certificate otherwise use the build-in ADCS
$UseWindowsCA = $true
# Name of the Certificate template that is used for signing the request
$CATemplateName = "WebServer2003CLI"

# Set own pre-defined roles. If not set, te script will determine which roles are already set. If no roles have a certificate set, all roles will get a certificate ( can create a warning on roles that arent specified ).
#$RDCertificateRoles = "RDPublishing","RDRedirector","RDWebAccess","RDGateway"

Try {

	# Clean-up variables (to prevent issues on rerun) and clear errors
	Clear-Variable -Name ActiveConnectionbroker -ErrorAction SilentlyContinue
	$Error.Clear()

	# Determine the active connection broker, we can also ask the secondary about this.
	# Nevertheless we do a loop here because the secondary can also be unreachable.
	$ConnectionBrokers | ForEach-Object {
		if ($Null -eq $ActiveConnectionbroker) {
			# Ask one of the connection brokers which is the active management server
            # And run the script on the activebroker            
            if ($ConnectionBrokers -contains [System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName) {
                if ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName -ne $_) {
                     Set-RDActiveManagementServer -ManagementServer $([System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName)
                     $ActiveConnectionBroker = $(Get-RDConnectionBrokerHighAvailability -ConnectionBroker $_ -ErrorAction SilentlyContinue).ActiveManagementServer
                }
            }    
		}
	}

    # Check if the RD-ManagementServer(s) is/are available
    if ($Null -eq $ActiveConnectionBroker) {
        throw "Cannot connect to the RD-ManagementServer, tried: $([string]::Join(', ', $ConnectionBrokers))"
    }
   
	# Check for all required variables
	$RDServerList = Get-RDServer -ConnectionBroker $ActiveConnectionbroker -ErrorAction SilentlyContinue
	$ClientAccessName = $(Get-RDConnectionBrokerHighAvailability -ConnectionBroker $ActiveConnectionbroker -ErrorAction SilentlyContinue).ClientAccessName

    if ($Null -eq $RDServerList -or $Null -eq $ClientAccessName) {
        throw "Failed to get the RD-Server list of ClientAccessName from the active broker."
    }

	If (($UseWindowsCA) -or (!$UseWindowsCA))  {
		switch ( $UseWindowsCA ) {
			$true { 
                # Retreive Certificate Templates
				$ADSIConfig = ([ADSI]"LDAP://ROOTDSE").ConfigurationNamingContext
				$ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ADSIConfig"
				$CerticateTemplates = $ADSI.Children | Select-Object -ExpandProperty CN
                            
                if ($Null -eq $CerticateTemplates ) {
			        throw "Unable to retrieve the certificate templates `n $($Error[0].Exception)"
		        }
				[bool]$CertificateTemplateExists = $false
				$CerticateTemplates | ForEach-Object { if ($_ -eq $CATemplateName) { $CertificateTemplateExists = $true } }
				If ($CertificateTemplateExists) {
					$CertificateRequest = Get-Certificate -Template $CATemplateName -SubjectName "CN=$($ClientAccessName)" -DnsName ($RDServerList | Select-Object -ExpandProperty Server) -CertStoreLocation Cert:\LocalMachine\My -ErrorAction SilentlyContinue

		            if ($Null -eq $CertificateRequest -or $CertificateRequest.Status -ne "Issued") {
			            throw "Requesting the RD-Certificate failed with statuscode $($CertificateRequest.Status) `n $($Error[0].Exception)"
		            }
				}
			}
			$false { 
                $CertificateRequest = New-SelfSignedCertificate -Subject "CN=$($ClientAccessName)" -DnsName ($RDServerList) -CertStoreLocation Cert:\LocalMachine\My -ErrorAction SilentlyContinue 
            }
			Default { Throw("Something went wrong with the 'UseWindowsCA' parameter, it should be $true or $false, please refer to the manual") }
		}
	}
	else {
		throw(" The 'UseWindowsCA Parameter' is not set, The parameter must be $true or $false")
	}

	try {
		#Export the Certificate with exportable key
		$PFXPath = New-item -Path $env:TMP  -Name  $(($(-join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 20 | ForEach-Object {[char]$_}))).tostring() + ".pfx") -ItemType File
		$PFXPassword = ConvertTo-SecureString ($(-join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 20 | ForEach-Object {[char]$_}))).tostring() -AsPlainText -Force
		$CertificateRequest.Certificate | Export-PfxCertificate -FilePath $PFXPath -ChainOption BuildChain -Password $PFXPassword | Out-Null
	}
	catch {
		throw "Failed to export the RD-Certificate to $($PFXPath)."
	}
		
	try {
		# Assign the certificate on the below specified roles
		if ($null -eq $RDCertificateRoles) {
			$RDCertificateRoles = Get-RDCertificate -ConnectionBroker $ActiveConnectionBroker | Where-Object { $_.Level -eq "Trusted" } | Select-Object -ExpandProperty Role
            if ($null -eq $RDCertificateRoles) {
                $RDCertificateRoles = Get-RDCertificate -ConnectionBroker $ActiveConnectionBroker  | Select-Object -ExpandProperty Role
            }
		}
        if ($RDCertificateRoles) {
		    $RDCertificateRoles | ForEach-Object { Set-RDCertificate -Role $_ -ImportPath $PFXPath -Password $PFXPassword -Force -ErrorAction Continue }
        }
		Remove-Item -Path $PFXPath -Force -ErrorAction SilentlyContinue
		Get-ChildItem "Cert:\LocalMachine\My\$($CertificateRequest.Certificate.Thumbprint)"| Remove-Item -Force
		Remove-Variable PFXPassword,PFXPath,CertificateRequest -ErrorAction SilentlyContinue
	}
	catch {
		throw "The certificate could not be assigned to the role, the script has stopped `n" + $Error[0].Exception
	}
	Restart-Service -Force -Name "TermService"
    Remove-Variable RDServerList,ClientAccessName,ActiveConnectionBroker,RDCertificateRoles,ADSIConfig,CATemplateName,CerticateTemplates,certificateTemplateExists,ConnectionBrokers,UseWindowsCA -ErrorAction SilentlyContinue
}
catch {
    $errorMsg = "Unexpected Error `n ############## `n"
	$Error | ForEach-Object { $errorMsg += "$($_.Exception) `n ############## `n" }
	throw $errorMsg
}