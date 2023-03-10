# Defineer benodigde parameters
## Geef de connection brokers op, in het script bepalen we vervolgens welke de actieve management server is.
$ConnectionBrokers = @("<Server1","Server2")

try {
	# Clean-up variables (to prevent issues on rerun) and clear errors
	Clear-Variable -Name ActiveConnectionbroker -ErrorAction SilentlyContinue
	$Error.Clear()

	# Bepaal de actieve connection broker, dit kunnen we ook aan de secondary vragen.
	# toch doen we hier een loop omdat de secondary ook onbereikbaar kan zijn.
	$ConnectionBrokers | ForEach-Object {
		if ($Null -eq $ActiveConnectionbroker) {
			## Vraag aan 1 van de connection brokers welke de actieve management server is
			$ActiveConnectionBroker = $(Get-RDConnectionBrokerHighAvailability -ConnectionBroker $_ -ErrorAction SilentlyContinue).ActiveManagementServer
		}
	}

    # Check if the RD-ManagementServers are available
    if ($Null -eq $ActiveConnectionBroker) {
        throw "Cannot connect to the RD-ManagementServer, tried: $([string]::Join(', ', $ConnectionBrokers))"
    }

	# Check for all required variables
	$rdServerList = Get-RDServer -ConnectionBroker $ActiveConnectionbroker -ErrorAction SilentlyContinue
	$ClientAccessName = $(Get-RDConnectionBrokerHighAvailability -ConnectionBroker $ActiveConnectionbroker -ErrorAction SilentlyContinue).ClientAccessName

    if ($Null -eq $rdServerList -or $Null -eq $ClientAccessName) {
        throw "Failed to get the RD-Server list of ClientAccessName from the active broker."
    }

	Invoke-Command -ComputerName $ActiveConnectionbroker -ScriptBlock {
		param($rdServerList, $ClientAccessName)

		$CertificateRequest = Get-Certificate -Template WebServer2003CLI -SubjectName "CN=$($ClientAccessName)" -DnsName ($rdServerList | Select-Object -ExpandProperty Server) -CertStoreLocation Cert:\LocalMachine\My -ErrorAction SilentlyContinue
		if ($Null -eq $CertificateRequest -or $CertificateRequest.Status -ne "Issued") {
			throw "Requesting the RD-Certificate failed with statuscode $($CertificateRequest.Status) `n $($Error[0].Exception)"
		}

		try {
			#Export the Certificate with exportable key
			$PFXPath = $(New-TemporaryFile).FullName
			$PFXPassword = ConvertTo-SecureString ($(-join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 20 | ForEach-Object {[char]$_}))).tostring() -AsPlainText -Force
			
			$CertificateRequest.Certificate | Export-PfxCertificate -FilePath $PFXPath -ChainOption BuildChain -Password $PFXPassword | Out-Null
		}
		catch {
			throw "Failed to export the RD-Certificate to $($PFXPath)."
		}

		# Assign the certificate on the below specified roles
		try {
			Set-RDCertificate -Role RDPublishing -ImportPath $PFXPath -Password $PFXPassword -Force 
			Set-RDCertificate -Role RDRedirector -ImportPath $PFXPath -Password $PFXPassword -Force 
			Set-RDCertificate -Role RDWebAccess -ImportPath $PFXPath -Password $PFXPassword -Force
			Set-RDCertificate -Role RDGateway -ImportPath $PFXPath -Password $PFXPassword -Force 
		}
		catch {
			throw "The certificate could not be assigned to the role, the script has stopped `n" + $Error[0].Exception
		}

		Restart-Service -Force -Name "TermService"
		Remove-Item -Path $PFXPath -Force -ErrorAction SilentlyContinue
	} -ArgumentList $rdServerList, $ClientAccessName

    Remove-Variable rdServerList,ClientAccessName
}
catch {
    $errorMsg = "Unexpected Error `n ############## `n"

	$Error | ForEach-Object { $errorMsg += "$($_.Exception) `n ############## `n" }

	throw $errorMsg
}