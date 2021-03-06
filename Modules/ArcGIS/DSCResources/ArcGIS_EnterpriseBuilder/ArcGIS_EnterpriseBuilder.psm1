<#
    .SYNOPSIS
        Installs and Licenses the Different component of a base deployment of ArcGIS using the Enterprise Builder.
    .PARAMETER Ensure
         Indicates to Install and License components of ArcGIS Enterpise Base Deployment using Enterprise Builder. Take the values Present or Absent. 
        - "Present" ensures that components of ArcGIS Enterpise Base Deployment using Enterprise Builder are installed and Licensed.
        - "Absent" ensures that components of ArcGIS Enterpise Base Deployment using Enterprise Builder are uninstalled if present.
    .PARAMETER Path
       Path to a Physical Location or Network Share Address for the Enterprise Builder setup.
    .PARAMETER Version
        Version of the Enterprise Builder to be installed. Required to Fetch the Product Id for installation.
    .PARAMETER InstallDir
        The destination folder for installing the base ArcGIS Enterprise Components.
    .PARAMETER GIS_User
        A MSFT_Credential Object - The account to be used as the owner of various processes and to be used by your base deployment for functions such as accessing operating system locations.
    .PARAMETER ServerLicenseFilePath
        .prvc or .ecp Fie - Path Required for Server License File so that it can be Configured.
    .PARAMETER PortalLicenseFilePath
        .prvc or .ecp Fie - Path Required for Portal License File so that it can be Configured.
#>

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Path,

		[parameter(Mandatory = $true)]
		[System.String]
		$Version
    )
    
    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

	$null
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
        [parameter(Mandatory = $true)]
		[System.String]
		$Path,

		[parameter(Mandatory = $true)]
		[System.String]
		$Version,

        [parameter(Mandatory = $true)]
		[System.String]
		$InstallDir,

		[System.Management.Automation.PSCredential]
		$GIS_User,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$ServerLicenseFilePath,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$PortalLicenseFilePath,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
    )
    
    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

    $Name = "EnterpriseBuilder"
    if($Ensure -eq 'Present') {
        if(-not(Test-Path $Path)){
            throw "$Path is not found or inaccessible"
        }
        $ExecPath = $null
        if(((Get-Item $Path).length -gt 5mb) -and ([IO.Path]::GetExtension((Get-Item $Path)) -Contains ".iso")) 
        {
            Write-Verbose 'Mounting Installation iso Disk Image'
            $MountResult = Mount-DiskImage -ImagePath $Path -PassThru
            $MountDiskLetter = ($mountResult | Get-Volume).DriveLetter
            $ExecPath = "$($MountDiskLetter):\Builder.exe"
            $Arguments = "GIS_INSTALLDIR=`"$($InstallDir)`" GIS_USER_NAME=`"$($GIS_User.UserName)`" GIS_PASSWORD=`"$($GIS_User.GetNetworkCredential().Password)`" PORTAL_AUTHORIZATION=`"$($PortalLicenseFilePath)`" SERVER_AUTHORIZATION=`"$($ServerLicenseFilePath)`" /qn"
            #F:\Builder.exe GIS_INSTALLDIR="C:\Program Files\ArcGIS" GIS_USER_NAME=arcgis GIS_PASSWORD="Arc_123456_Gis" PORTAL_AUTHORIZATION="\\metro\ArcGIS_Automation\Authorization_Files\Version10.5\portal_2000_1000.prvc" SERVER_AUTHORIZATION="\\metro\ArcGIS_Automation\Authorization_Files\Version10.5\Server_Ent_Adv_AllExt.prvc" /qb
            
            Write-Verbose "Executing $ExecPath with arguments $Arguments"
            Write-Verbose "$ExecPath $Arguments"

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $ExecPath
            $psi.Arguments = $Arguments
            $psi.UseShellExecute = $false #start the process from it's own executable file    
            $psi.RedirectStandardOutput = $true #enable the process to read from standard output
            $psi.RedirectStandardError = $true #enable the process to read from standard error
            
            $p = [System.Diagnostics.Process]::Start($psi)
            $p.WaitForExit()
            $op = $p.StandardOutput.ReadToEnd()
            if($op -and $op.Length -gt 0) {
                Write-Verbose "Output of execution:- $op"
            }
            $err = $p.StandardError.ReadToEnd()
            if($err -and $err.Length -gt 0) {
                Write-Verbose $err
            }
            Dismount-DiskImage -InputObject $MountResult           
        }else{
             throw "$Path - unsupported type."
        }
    }
    elseif($Ensure -eq 'Absent') {
        $ProdId = Get-ComponentCode -ComponentName $Name -Version $Version
        if(-not($ProdId.StartsWith('{'))){
            $ProdId = '{' + $ProdId
        }
        if(-not($ProdId.EndsWith('}'))){
            $ProdId = $ProdId + '}'
        }
        Write-Verbose "msiexec /x ""$ProdId"" /quiet"
        Start-Process 'msiexec' -ArgumentList "/x ""$ProdId"" /quiet" -wait
    }
    Write-Verbose "In Set-Resource for $Name"
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
        [parameter(Mandatory = $true)]
		[System.String]
		$Path,

		[parameter(Mandatory = $true)]
		[System.String]
		$Version,

        [parameter(Mandatory = $true)]
		[System.String]
		$InstallDir,

		[System.Management.Automation.PSCredential]
		$GIS_User,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$ServerLicenseFilePath,
        
        [parameter(Mandatory = $true)]
		[System.String]
		$PortalLicenseFilePath,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure
    )
    
    Import-Module $PSScriptRoot\..\..\ArcGISUtility.psm1 -Verbose:$false

    $Name = "EnterpriseBuilder"
    $result = $false
    $ProdId = Get-ComponentCode -ComponentName $Name -Version $Version
    if(-not($ProdId.StartsWith('{'))){
        $ProdId = '{' + $ProdId
    }
    if(-not($ProdId.EndsWith('}'))){
        $ProdId = $ProdId + '}'
    }
    $PathToCheck = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$($ProdId)"
    Write-Verbose "Testing Presence for Component '$Name' with Path $PathToCheck"
    if (Test-Path $PathToCheck -ErrorAction Ignore){
        $result = $true
    }
    if(-not($result)){
        $PathToCheck = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$($ProdId)"
        Write-Verbose "Testing Presence for Component '$Name' with Path $PathToCheck"
        if (Test-Path $PathToCheck -ErrorAction Ignore){
            $result = $true
        }
    }
    if($Ensure -ieq 'Present') {
	       $result   
    }
    elseif($Ensure -ieq 'Absent') {        
        (-not($result))
    }
}

Export-ModuleMember -Function *-TargetResource

