#Requires -RunAsAdministrator
Get-ChildItem -Path $PSScriptRoot | Unblock-File

Function Invoke-VMWareRestRequest 
{
    [cmdletbinding()]
    Param 
    (
        $Uri=$URL,
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE')]
        $Method,
        [Parameter(Mandatory)]

        $Body=$Null
    )
    $Authentication = ("{0}:{1}" -f $Username,$Password)
    $Authentication = [System.Text.Encoding]::UTF8.GetBytes($Authentication)
    $Authentication = [System.Convert]::ToBase64String($Authentication)
    $Authentication = "Basic {0}" -f $Authentication

    $Headers = @{
        'authorization' =  $Authentication;
        'content-type' =  'application/vnd.vmware.vmw.rest-v1+json';
        'accept' = 'application/vnd.vmware.vmw.rest-v1+json';
        'cache-control' = 'no-cache'
    }
      $RequestResponse = Invoke-RestMethod -Uri $URL -Method $Method -Headers $Headers -Body $body
      return $RequestResponse
}

function Get-VM {
    param (
        $VMId
    )
    if ([string]::IsNullOrEmpty() -eq $BASEURL) {

    }
    
    $URL = $BASEURL + "/vms"
    $RequestResponse = Invoke-VMWareRestRequest -method GET -uri ($URL + "/$($vmid.id)")
    return $RequestResponse
}

Function Get-VMWareWorkstationConfiguration 
{
    if ($null -eq $VMwareWorkstationConfigParameters) {
         Remove-Variable VMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
    }

    $global:VMwareWorkstationConfigParameters = New-Object PSObject

    try {
            #$VMwareWorkstationConfigParameters = Get-WmiObject -ClassName Win32_Product | Where-Object { $_.name -like "VMware Workstation*" } | Select-Object Version
        }
    catch {
        $Error[0].Exception
    }

    try {
        $GetVMwareWorkstationConfigParameters = $(Get-Content -Path $("$([System.Environment]::ExpandEnvironmentVariables($env:USERPROFILE))\vmrest.cfgs") -ErrorAction Stop | Select-String -Pattern 'PORT','USERNAME' -AllMatches ).line.Trim() 
         if (!([String]::IsNullOrEmpty(($GetVMwareWorkstationConfigParameters)))) {
             $GetVMwareWorkstationConfigParameters | ForEach-Object { 
                    $VMwareWorkstationConfigParameters | add-member Noteproperty $($_.split("=")[0]) $($_.split("=")[1]) 
            }
        }
    }
    catch {
        $Error[0].Exception
    }

  try {
        $GetVMwareWorkstationConfigParameters = $(Get-Content -Path $("$([System.Environment]::ExpandEnvironmentVariables($env:APPDATA))\VMware\preferences.inis") -ErrorAction Stop | Select-String -Pattern 'PREFVMX' -AllMatches ).line.Trim() 
        
         if (!([String]::IsNullOrEmpty(($GetVMwareWorkstationConfigParameters)))) {
            $GetVMwareWorkstationConfigParameters | ForEach-Object { 
            
                $ValueOne = $($_.Split("=")[0])
                $ValueTwo = $($_.Split("=")[1])

                if ($ValueOne.StartsWith(' ') -or $ValueOne.EndsWith(' ') -or $ValueTwo.StartsWith(' ') -or $ValueTwo.EndsWith(' ') ) {
                    $ValueOne = $($ValueOne).TrimStart().TrimEnd()
                    $ValueTwo = $ValueTwo.TrimStart().TrimEnd()
                }
                
                $VMwareWorkstationConfigParameters | add-member Noteproperty $ValueOne $ValueTwo
            }
        }
    }
    catch {
        $Error[0].Exception
    }
    finally {
        Remove-Variable GetVMwareWorkstationConfigParameters -ErrorAction SilentlyContinue
        $Error.Clear()
    }
}
