#Requires -RunAsAdministrator


Function Write-Message {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [String]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('ERROR', 'INFORMATION', 'WARNING')]
        $MessageType     
    )
    switch ($MessageType) {
        ERROR { 
            $ForegroundColor = 'White'
            $BackgroundColor = 'Red'
            $MessageStartsWith = "[ERROR] - " 
        }
        INFORMATION {
            $ForegroundColor = 'White'
            $BackgroundColor = 'blue'
            $MessageStartsWith = "[INFORMATION] - " 
        }
        WARNING {
            $ForegroundColor = 'White'
            $BackgroundColor = 'DarkYellow'
            $MessageStartsWith = "[WARNING] - " 
        }
    }
   Write-Host "$MessageStartsWith $Message" -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

Function ShowFolder {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('GetVMWareWorkstationInstallationPath')]
        $Parameter
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop      
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog -ErrorAction Stop
    $FolderBrowserDialog.Description = "Select de Folder where VMWARE Workstation $($VMWareWorkStationSettings.Version) is installed"
    $FolderBrowserDialog.ShowNewFolderButton = $false
    $FolderBrowserDialog.rootfolder = "MyComputer"
    [void]::($FolderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true; TopLevel = $true })))
    
    switch ($Parameter) {

        GetVMWareWorkstationInstallationPath { $FolderBrowserFile = "vmware.exe" }
    }

    $FolderBrowserDialogPath = Get-ChildItem -Path $FolderBrowserDialog.SelectedPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $FolderBrowserFile }
    return $FolderBrowserDialogPath
}

Function VMWare_SetPassword {
    
    $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject
    
    if (!($Credentials.Password)) {
        [void]::(New-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -Credentials $(Get-Credential -UserName $VMwareWorkstationConfigParameters.username -message "Provide the vmrest credentials") -Persist LocalMachine)
        $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject   
    }
    
    $securePassword = $Credentials.Password | ConvertTo-SecureString -AsPlainText -Force
    Remove-Variable -Name $Credentials -ErrorAction SilentlyContinue         
    
    if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name Password -ErrorAction SilentlyContinue)) {
        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Password" -Value $securePassword -Force -ErrorAction Stop
    }
    else {
        $Credentials = Get-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" –AsCredentialObject
        $VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Password" -Value $securePassword -Force -ErrorAction Stop
    } 
    Remove-Variable $securePassword -ErrorAction SilentlyContinue
}

Function RunVMRestConfig {
    [cmdletbinding()]
    Param 
    (
        [Parameter(Mandatory)]
        [ValidateSet('Preconfig','ConfigCredentialsCheck')]
        $Config     
    )
    switch ($Config) {
        Preconfig { 
            Write-Host "TEST"
        }
        ConfigCredentialsCheck {
            if (($VMwareWorkstationConfigParameters.HostAddress) -and ($VMwareWorkstationConfigParameters.port) -and ($VMwareWorkstationConfigParameters.Password)) {
                 $URL = "http://$($VMwareWorkstationConfigParameters.HostAddress):$($VMwareWorkstationConfigParameters.port)/api/vms"  
                 [void]::(Invoke-VMWareRestRequest -Method GET -Uri $URL)
            }
        }
    }
}

Function VMWare_ImportSettings {
    $VMWareImportSettings = "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml"

    try {

        Remove-Variable -Name VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
        if (Test-Path -Path $VMWareImportSettings -ErrorAction Stop) {
            $GLOBAL:VMwareWorkstationConfigParameters = Import-Clixml -Path $VMWareImportSettings -ErrorAction Stop
        }
        else {
            VMWare_RetrieveSettings
        }
    }
    catch {
        VMWare_RetrieveSettings
    }
}

Function VMWare_ExportSettings {
    $VMwareWorkstationConfigParameters | Export-Clixml -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force
}

Function VMWare_RetrieveSettings {

    [void]::([bool]$VmwareCouldNotDetermine_Win32_Products = $true) 

    if (Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation -ErrorAction SilentlyContinue) {
        Remove-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
    }

    if (Test-Path -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml") {
        Remove-Item -Path "$PSScriptRoot\Settings-$($([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).replace("\","-")).xml" -Force -ErrorAction SilentlyContinue
    }

    # Gather Registry settings
    if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Version)) {
        try {        
            if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.Name) ) {
                Write-Message -Message "Gathering Information about the VMWare Workstation installation on your computer: $(hostname)" -MessageType INFORMATION
            
                $Global:VMwareWorkstationConfigParameters = Get-CimInstance  -ClassName Win32_Product -ErrorAction Stop | Where-Object { $_.Name -like "*VMware Workstation" } | Select-Object Name, Version, InstallLocation
                Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) found" -MessageType INFORMATION 
            }
        }
        catch {
            Write-Message -Message "Cannot load the CimInstance Win32_Product $($error[0])" -MessageType ERROR
            $VmwareCouldNotDetermine_Win32_Products = $true
        }
    }
    # Gathering Folder information
     try {
        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            
            Write-Message -Message "Could not find the installation folder in the registry. Please provide the VMWare $($VMwareWorkstationConfigParameters.Version) installation folder" -MessageType INFORMATION

            [void]::([int]$RetryRetrieveFolder)

            [bool]$RetryRetrieveFolderError = $false    
            do {
                if ($FolderBrowserDialogPath = ShowFolder -Parameter GetVMWareWorkstationInstallationPath) {
                    if (Test-Path $FolderBrowserDialogPath.FullName -ErrorAction Stop) {
            
                        if (!(Get-Member -InputObject $VMwareWorkstationConfigParameters -Name installlocation)) {
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value "" -Force -ErrorAction Stop
                        }

                        if ($VmwareCouldNotDetermine_Win32_Products) {
                            $Global:VMwareWorkstationConfigParameters.InstallLocation = $FolderBrowserDialogPath.DirectoryName
                            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Name" -Value "VMware Workstation" -Force -ErrorAction Stop
                        }
                        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Version" -Value "$([System.Diagnostics.FileVersionInfo]::GetVersionInfo($FolderBrowserDialogPath.fullname) | Select-Object -ExpandProperty FileVersion)" -Force
                        Write-Message -Message "Vmware Workstation $($VMwareWorkstationConfigParameters.Version) Installlocation defined as: $($VMwareWorkstationConfigParameters.InstallLocation)" -MessageType INFORMATION
                        $VmwareCouldNotDetermine_Win32_Products = $true
                        [void]::($RetryRetrieveFolder = 0)
                    } 
                }
  
                if ($RetryRetrieveFolder -lt 1) {
                $RetryRetrieveFolder
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, please retry" -MessageType INFORMATION
                    $RetryRetrieveFolderError = $true
                    $VmwareCouldNotDetermine_Win32_Products = $false
                }
                if ($RetryRetrieveFolder -ge 1) {
                    Write-Message -Message "The Path $($FolderBrowserDialogPath) does not contain the vmware installation, last retry" -MessageType INFORMATION
                    $RetryRetrieveFolderError = $true
                     Write-Error -Exception "Path Not found" -ErrorAction Stop
                }
                [void]::($RetryRetrieveFolder++)

            } until (($RetryRetrieveFolder -ge 2) -or (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation))))
        }
        else {
            $VmwareCouldNotDetermine_Win32_Products = $true
        }
    }
    catch {
         try {
             if ($RetryRetrieveFolderError) {
                Write-Message -Message "Doing a alternative scan - Scanning all filesystem disks that are found on your system" -MessageType INFORMATION
                $CollectDriveLetters = $(Get-PSDrive -PSProvider FileSystem ) | Select-Object -ExpandProperty Root
                $Collected = [System.Collections.ArrayList]@()
                $CollectDriveLetters | ForEach-Object { $Collected += Get-ChildItem -Path $($_) -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "vmware.exe" } }
                [void]::($RetryRetrieveFolder = 0)
                if (!([string]::IsNullOrEmpty($Collected))) {
                    if ($Collected.count -le 1) {
                           $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Name" -Value "VMware Workstation" -Force -ErrorAction Stop
                           $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "Version" -Value "$([System.Diagnostics.FileVersionInfo]::GetVersionInfo($Collected.fullname) | Select-Object -ExpandProperty FileVersion)" -Force
                           $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $Collected.DirectoryName -Force -ErrorAction Stop
                           $VmwareCouldNotDetermine_Win32_Products = $true
                    }

                    if ($Collected.count -gt 1) {
                        do {
                            $SelectedPath = $Collected | Select-Object Name,fullname,DirectoryName | Out-GridView -Title "Multiple VMWare Workstation installation folders found, please select the folder where VMWare Workstation is installed" -OutputMode Single
                            if ($null -ne $SelectedPath) {
                                if (Test-Path $SelectedPath.FullName -ErrorAction Stop) {
                                    $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty -Name "InstallLocation" -Value $SelectedPath.DirectoryName -Force -ErrorAction Stop
                                    $RetryRetrieveFolderError = $false
                                    break
                                }
                            }
                            else {                        
                                if ($RetryRetrieveFolder -lt 1) {
                                    Write-Message -Message "No input gathered, retrying" -MessageType INFORMATION
                                    $VmwareCouldNotDetermine_Win32_Products = $false
                                }
                                if ($RetryRetrieveFolder -gt 1) {
                                    Write-Message -Message "No input gathered, last retry" -MessageType INFORMATION
                                    Write-Error -Exception "Path Not found" -ErrorAction Stop
                                    break
                                }
                                [void]::($RetryRetrieveFolder++)
                            }
                        
                        } until ($RetryRetrieveFolder -ge 2)
                    }
                }
             }
             else {
                  Write-Error -Exception "Path Not found" -ErrorAction Stop
             }
        }
        catch {
                 Write-Message -Message "Unknown error occured the script is quitting" -MessageType ERROR            
        }

        if ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation)) {
            Write-Message -Message "Cannot determine if VMWare Workstation is installed on this machine, the script is quitting" -MessageType ERROR
            $RetryRetrieveFolder = $false
        }
    }

   #Gather VMRest Config Settings vmrest.cfg
    if (($RetryRetrieveFolderError) -or ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.port)) -or ([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.username)))  {
        Write-Message -Message "Gathering VMREST config" -MessageType INFORMATION
        Try {
            $GetVMRESTConfig = Get-ChildItem -Path $([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) -Recurse | Where-Object { $_.Name -eq "vmrest.cfg" } | Select-Object -ExpandProperty fullname -ErrorAction SilentlyContinue

            if (Test-Path $GetVMRESTConfig) {
                $GetVMRESTConfigLoader = $(Get-Content -Path $GetVMRESTConfig -ErrorAction Stop | Select-String -Pattern 'PORT','USERNAME' -AllMatches ).line.Trim()

                if (!([String]::IsNullOrEmpty(($GetVMRESTConfigLoader)))) {
                    $GetVMRESTConfigLoader | ForEach-Object { 
                        $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType Noteproperty $($_.split("=")[0]) $($_.split("=")[1]) -Force
                }
            
                $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType NoteProperty "HostAddress" -Value "127.0.0.1" -Force
                $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType Noteproperty -Name BASEURL -Value "http://$($VMwareWorkstationConfigParameters.HostAddress):$($VMwareWorkstationConfigParameters.port)/api/" -Force
                Remove-Variable -name GetVMRESTConfigLoader,GetVMRESTConfig -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Message -Message "Cannot load the vmrest.cfg file" -MessageType INFORMATION 
            Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait
            VMWare_SetPassword
            VMWare_RetrieveSettings
         }
    }

}

Function Invoke-VMWareRestRequest {
    [cmdletbinding()]
    Param 
    (
        $Uri=$URL,
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        $Method,
        $Body=$Null
    )
    if (!($(Get-Process -name vmrest -ErrorAction SilentlyContinue))) {
        Stop-Process -name vmrest -ErrorAction SilentlyContinue -Force
        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -PassThru -NoNewWindow -Verbose #-ArgumentList "" -WindowStyle Minimized
    } 

    $Credential = [pscredential]::new('username',$VMwareWorkstationConfigParameters.password).GetNetworkCredential().Password
    if ($Credential) {               
        $Authentication = ("{0}:{1}" -f $VMwareWorkstationConfigParameters.username,$Credential)
        Remove-Variable -name Credential -ErrorAction SilentlyContinue
        $Authentication = [System.Text.Encoding]::UTF8.GetBytes($Authentication)
        $Authentication = [System.Convert]::ToBase64String($Authentication)
        $Authentication = "Basic {0}" -f $Authentication

        $Headers = @{
            'authorization' =  $Authentication;
            'content-type' =  'application/vnd.vmware.vmw.rest-v1+json';
            'accept' = 'application/vnd.vmware.vmw.rest-v1+json';
            'cache-control' = 'no-cache'
        }
        $Error.clear()
        try {
            $RequestResponse = Invoke-RestMethod -Uri $URI -Method $Method -Headers $Headers -Body $body -ErrorAction Stop
            return $RequestResponse
        }
        catch {
        $RequestResponse
            if ($Error[0].ErrorDetails.message) {
                write-host $Error[0]
                $ErrorHandler = $Error[0].ErrorDetails.message | ConvertFrom-Json
                $ErrorHandler.Message
                switch ($ErrorHandler.Message) {
            
                    'Authentication failed' { 
                        Stop-Process -name vmrest -Force
                        Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait -PassThru
                        Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
                        VMWare_SetPassword
                        VMWare_ExportSettings
                        VMWare_ImportSettings                        
                     } 
                     default { Write-Message -Message "Unknown error occured in the VMWARE Workstation restapi call $error[0] " -MessageType ERROR } 
                }
            }
        }
    }
    else {
        Write-Message -Message "Credentials not found" -MessageType WARNING
        VMWare_ImportSettings
        if (($VMwareWorkstationConfigParameters.username) -and ($VMwareWorkstationConfigParameters.password)) {
            Stop-Process -name vmrest -ErrorAction SilentlyContinue      
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait -PassThru
            Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
            Vmware_SetPassword
            RunVMRestConfig -Config ConfigCredentialsCheck
            VMWare_ExportSettings
            VMWare_ImportSettings
        }
        else {
            Stop-Process -name vmrest -ErrorAction SilentlyContinue      
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmrest.exe") -ArgumentList "-C" -Wait -PassThru
            Remove-StoredCredential -Target "VMWARE-API-VMREST-PASSWORD" -ErrorAction SilentlyContinue
            Vmware_SetPassword
            RunVMRestConfig -Config ConfigCredentialsCheck
            VMWare_ExportSettings
            VMWare_ImportSettings
        }
    }
}

function Get-VMWareWorkstationConfiguration {
<#
    .SYNOPSIS
    
        creates a psobject to store the data needed for the proper functioning of the module, all the necessary data is stored in a variable

    .DESCRIPTION
        creates a psobject to store the data needed for the proper functioning of the module, all the necessary data is stored in a variable

    .EXAMPLE
 
       Get-VMWareWorkstationConfiguration
       will create a global variable $VMwareWorkstationConfigParameters based on the existing xml file that has been saved. or on the gathered information.


    .EXAMPLE

        Get-VMWareWorkstationConfiguration
        
                VMwareWorkstationConfigParameters

                Name            Definition                                                             
                ----            ----------                                                             
                BASEURL         string BASEURL=http://127.0.0.1:8697/api/                              
                HostAddress     string HostAddress=127.0.0.1                                           
                InstallLocation string InstallLocation=C:\Program Files (x86)\VMware\VMware Workstation
                Name            string Name=VMware Workstation                                         
                Password        securestring Password=System.Security.SecureString                     
                port            string port=8697                                                       
                username        string username=<your username>                                               
                Version         string Version=17.0.1 build-21139696  

    .EXAMPLE

        Adding own data to the variable. 

        load the variable with Get-VMWareWorkstationConfiguration

        $VMwareWorkstationConfigParameters | Add-Member -MemberType Noteproperty -Name DATA -Value "Your data here" -Force
    
        use the -force to override settings.
    
        use [ Get-VMWareWorkstationConfiguration -SaveConfig ] to save the data into the XML file that will be created in the module folder.
    .EXAMPLE

        Removing data from the object 

        load the variable with Get-VMWareWorkstationConfiguration

        remove data from the object 
        $VMwareWorkstationConfigParameters.PSObject.properties.remove('data')
    
        use [ Get-VMWareWorkstationConfiguration -SaveConfig ] to save the data into the XML file that will be created in the module folder.
 
     .EXAMPLE

        using data

        load the variable with Get-VMWareWorkstationConfiguration
                
                Name            Definition                                                             
                ----            ----------                                                             
                BASEURL         string BASEURL=http://127.0.0.1:8697/api/    
        
        
        VMwareWorkstationConfigParameters.PSOBJECT can be called
        
        for example
        
        $VMwareWorkstationConfigParameters.BASEURL
        
        will result in a string with output http://127.0.0.1:8697/api/
   
    .INPUTS
       System.String

    .OUTPUTS
       System.String

#>  
    [cmdletbinding()]
    param (
        [switch]$SaveConfig
    )

    if (!($(Get-Process -name vmrest -ErrorAction SilentlyContinue))) {
        Stop-Process -name vmrest -ErrorAction SilentlyContinue -Force
    }

    if ($SaveConfig) {
        if ($(Get-Variable VMwareWorkstationConfigParameters)) {
            VMWare_ExportSettings
            VMWare_ImportSettings
        }
    }
    else {
        try {
            [void]::(Get-Variable -Name $VMwareWorkstationConfigParameters -ErrorAction Stop)
            }
        catch {
            $Global:VMwareWorkstationConfigParameters = New-Object PSObject
        }

        VMWare_ImportSettings    
    
        if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.InstallLocation))) {
            VMWare_SetPassword    
            VMWare_ExportSettings
            VMWare_ImportSettings
            RunVMRestConfig -Config ConfigCredentialsCheck 
            $Global:VMwareWorkstationConfigParameters | Add-Member -MemberType Noteproperty -Name BASEURL -Value "http://$($VMwareWorkstationConfigParameters.HostAddress):$($VMwareWorkstationConfigParameters.port)/api/" -Force

            Write-Host "`n"
            (Get-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue -Verbose) | Select-Object -ExpandProperty Name 
            (Get-Member -InputObject $VMwareWorkstationConfigParameters -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object Name, Definition)
        }
    }
}

# 1 GET /vms Returns a list of VM IDs and paths for all VMs
Function Get-VMTemplate {
<#
    .SYNOPSIS        
        List the virtual machines stored in the virtual machine folder

    .DESCRIPTION        
        List the virtual machines stored in the virtual machine folder

    .PARAMETER VirtualMachinename
       Can be a asterix * to retrieve all virtual machines
       Mandatory - [string]

        PS C:\WINDOWS\system32> Get-VMTemplate -VirtualMachinename *

        id                               path                                                                                           
        --                               ----                                                                                           
        PK7CPPB5UV50M3B73QD5ELDQN2OD9UFJ D:\Virtual machines\VMFOLDER1\VMNAME1.vmx 
        649TJ74BEAHCM93M56DM79VD21562M8D D:\Virtual machines\VMFOLDER2\VMNAME2.vmx 

    .PARAMETER Description
       Can be a VMID retrieved bij knowing the VMID 

        PS C:\WINDOWS\system32> Get-VMTemplate -VirtualMachinename E6QBUTVNKFRL0TTG8JA8BCN5LKCKFTJ5

        id                               path                                                                                           
        --                               ----                                                                                           
        E6QBUTVNKFRL0TTG8JA8BCN5LKCKFTJ5 D:\Virtual machines\VMFOLDER3\VMNAME3.vmx

       Mandatory - [string]


     .EXAMPLE
       Can be a asterix * to retrieve all virtual machines
       
       Mandatory - [string]

        Get-VMTemplate -VirtualMachinename *

        id                               path                                                                                           
        --                               ----                                                                                           
        PK7CPPB5UV50M3B73QD5ELDQN2OD9UFJ D:\Virtual machines\VMFOLDER1\VMNAME1.vmx 
        649TJ74BEAHCM93M56DM79VD21562M8D D:\Virtual machines\VMFOLDER2\VMNAME2.vmx 
    .PARAMETER Description
       Can be a VMID retrieved by knowing the VMID 

        Get-VMTemplate -VirtualMachinename E6QBUTVNKFRL0TTG8JA8BCN5LKCKFTJ5

        id                               path                                                                                           
        --                               ----                                                                                           
        E6QBUTVNKFRL0TTG8JA8BCN5LKCKFTJ5 D:\Virtual machines\VMFOLDER2\VMNAME2.vmx
        Mandatory - [string]                                 
    .EXAMPLE        
        retrieve the path of the virtual machine
        $(Get-VMTemplate -VirtualMachinename PK7CPPB5UV50M3B73QD5OLDQN2OD9UFJ).Path

        results in D:\Virtual machines\VMFOLDER1\VMNAME1.vmx

    .EXAMPLE
        retrieve the id of the virtual machine
        $(Get-VMTemplate -VirtualMachinename PK7CPPB5UV50M3B73QD5OLDQN2OD9UFJ).id

        results E6QBUTVNKFRL0TTG8JA8BCN5LKCKFTJ5
    .EXAMPLE     
     $GatherVMS = $(Get-VMTemplate -VirtualMachinename *)

    .INPUTS
       System.String

    .OUTPUTS
       System.String
#>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        $VirtualMachinename
    )

    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.BASEURL))) {
        $RequestResponse=Invoke-VMWareRestRequest -method  GET -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms")
        
        if ($VirtualMachinename -eq "*"){
            return $RequestResponse
            break
        }

        foreach ($VM in $RequestResponse)
        {
            $PathSplit = ($vm.path).split("\")
            $vmxfile = $PathSplit[($PathSplit.Length)-1]
            $thisVM = ($vmxfile).split(".")[0]
            if ($thisVM -eq $VirtualMachinename) { return $VM ;break}
        } 
        return $VM
    }
    else {
        Write-Message -Message "Configuration is not loaded, use Get-VMWareWorkstationConfiguration to load the configuration" -MessageType ERROR 
    }
}

# 2 GET /vms/{id} Returns the VM setting information of a VM
function Get-VM {
    param (
        [Parameter(Mandatory)]
        $VMId
    )
    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.BASEURL))) {
        $RequestResponse = Invoke-VMWareRestRequest -method GET -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms/$($vmid)") 
        return $RequestResponse
    }
    else {
        Write-Message -Message "Configuration is not loaded, use Get-VMWareWorkstationConfiguration to load the configuration" -MessageType ERROR 
    }
}

# 3 GET /vms/{id}/params/{name} Get the VM config params

Function Set-VMConfig {

}

# 4 GET /vms/{id}/restrictions Returns the restrictions information of the VM
Function Get-VMRestrictions {

    param (
        [Parameter(Mandatory)]
        $VMId
    )
    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.BASEURL))) {
        $RequestResponse = Invoke-VMWareRestRequest -method GET -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms/$($vmid)/restrictions") 
        return $RequestResponse
    }
    else {
        Write-Message -Message "Configuration is not loaded, use Get-VMWareWorkstationConfiguration to load the configuration" -MessageType ERROR 
    }
}

# 5 POST /vms Creates a copy of the VM

Function New-VMClonedMachine {
    [cmdletbinding()]
    param 
    (
        [Parameter(Mandatory)]
        $NewVMCloneName,
        [Parameter(Mandatory)]
        $NewVMCloneId,
        [Parameter(Mandatory)]
        $IsBodyJson
    )
    $Body = @{
        'name' = $NewVMCloneName;
        'parentId' = $NewVMCloneId
    }
    $RequestBody = ( ConvertTo-Json $Body)
    $RequestResponse=Invoke-VMWareRestRequest -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms") -Method POST -Body $RequestBody 
    return $RequestBody, $RequestResponse
}

# 6 POST /vms/registration Register VM to VM Library
Function Register-VMClonedMachine {

    [cmdletbinding()]
    param 
    (
        [Parameter(Mandatory)]
        $NewVMCloneId,
        [Parameter(Mandatory)]
        $VMClonePath
    )
    $Body = @{
        'name' = $NewVMCloneId;
        'path' = $VMClonePath
    }
    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.BASEURL))) {
        if ($(Get-Process -name vmware -ErrorAction SilentlyContinue)) {
            $VMWareReopen = $true
            Stop-Process -name vmware -ErrorAction SilentlyContinue -Force 
        }

        if (!($(Get-Process -name vmware -ErrorAction SilentlyContinue))) {
            $RequestBody = ( ConvertTo-Json $Body)
            $RequestResponse=Invoke-VMWareRestRequest -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms/registration") -Method POST -Body $RequestBody 
            return $RequestResponse
        }
        else {
            Write-Message -Message "Can't close vmware.exe the deletion of vm with id $($id) can't be proccessed. please close the program "
        }
                
        if ($VMWareReopen) {
            Start-Sleep 5
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmware.exe")
        }
    }
    else {
        Write-Message -Message "Configuration is not loaded, use Get-VMWareWorkstationConfiguration to load the configuration" -MessageType ERROR 
    }
}

# 7 DELETE /vms/{id} Deletes a VM

Function Remove-VMClonedMachine {    
    param (
        [Parameter(Mandatory)]
        $VMId
    )
    if (!([string]::IsNullOrEmpty($VMwareWorkstationConfigParameters.BASEURL))) {
        if ($(Get-Process -name vmware -ErrorAction SilentlyContinue)) {
            $VMWareReopen = $true
            Stop-Process -name vmware -ErrorAction SilentlyContinue -Force 
        }

        if (!($(Get-Process -name vmware -ErrorAction SilentlyContinue))) {

            $RequestResponse=Invoke-VMWareRestRequest -Method DELETE -Uri ($VMwareWorkstationConfigParameters.BASEURL + "vms/$($VMid)")
        }
        else {
            Write-Message -Message "Can't close vmware.exe the deletion of vm with id $($id) can't be proccessed. please close the program "
        }
                
        if ($VMWareReopen) {
            Start-Sleep 5
            Start-Process -FilePath $(Join-Path -Path $VMwareWorkstationConfigParameters.InstallLocation -ChildPath "\vmware.exe")
        }
    }
    else {
        Write-Message -Message "Configuration is not loaded, use Get-VMWareWorkstationConfiguration to load the configuration" -MessageType ERROR 
    }
}