Function CreateRandomPSDrive {
    <#
        .SYNOPSIS
        Create a usable PSDrive Letter 

        .DESCRIPTION
            Create a local subst to PSDrive letter or connect to a Networkshare

        .PARAMETER Path
            is a string

            -Path can be a local folder or networkshare

            -path "C:\"
            -Path "\\localhost'\C$"

        .PARAMETER ExcludeDriveLetters
            can be a array
        
            -ExcludeDriveLetter "A"
            -ExcludeDriveLetter "A","B"
        
        .PARAMETER -Credentials 
            Must be a PSCredenial object
        
            -Credentials $(Get-Credential)   

        .EXAMPLE
        PS> CreateRandomPSDrive -Path "\\localhost\C$" -ExcludeDriveLetter "A","B" 

            Name           Used (GB)     Free (GB) Provider      Root                                                                            CurrentLocation
            ----           ---------     --------- --------      ----                                                                            ---------------
            Z                 111,74        819,15 FileSystem    \\localhost\C$                                                                                 

        PS> CreateRandomPSDrive -Path "\\localhost\C$" -ExcludeDriveLetter "A","B" -Description "TESTING"

        .EXAMPLE
        PS> CreateRandomPSDrive -Path "C:\Documents and Settings" -ExcludeDriveLetter "A","B" -Description "subst from C:"

            Name           Used (GB)     Free (GB) Provider      Root                                                                            CurrentLocation
            ----           ---------     --------- --------      ----                                                                            ---------------
            R                   0,00        819,15 FileSystem    C:\Documents and Settings                                                                      
        
        .LINK
        Online version: https://github.com/DKreutz0/PSSnippits/tree/main/CreateRandomPSDrive

    #>
    [CmdletBinding()]
    Param(
        
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [Array]$ExcludeDriveLetters,
        
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        [Parameter(Mandatory=$false)]
        $Credentials = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false)]
        [string]$Description               
    )
    
    $InUseDrivesLetters = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name  -ErrorAction Stop
    $InUseDrivesLetters = $InUseDrivesLetters + $ExcludeDriveLetters | Sort-Object -Unique

    Do 
    {
        $RandomDriveLetter = -join ((65..90) | Get-Random -Count 1 | ForEach-Object { [char]$_ })
        
    } Until($RandomDriveLetter -notin $InUseDrivesLetters)

    Switch ($([System.Uri]$path).IsUnc) {

        $true {  New-PSDrive -Name $RandomDriveLetter -PSProvider FileSystem -Root $Path -Persist -Scope Global -Credential $Credentials -ErrorAction Stop }
        $False { New-PSDrive -Name $RandomDriveLetter -PSProvider FileSystem -Root $Path -Description $Description -Scope Global -Credentials Get-Credential -ErrorAction Stop }
    }
}

<# Example Code
try {
    CreateRandomPSDrive -Path "\\127.0.0.1\c$" -ExcludeDriveLetter "A","B" -Description "NetworkShare" #-Credentials $(Get-Credential)
}
catch  {
    Write-Output  $Error[0].Exception -NoEnumerate
}
#>