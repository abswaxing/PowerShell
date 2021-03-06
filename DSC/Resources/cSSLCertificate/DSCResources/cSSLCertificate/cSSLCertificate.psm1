function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Thumbprint,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[System.String]
		$Store = "My",

		[System.String]
		$Root = "Localmachine"
	)

    # Create full path to use for the Get-ChildItem cmdlet.
    $CertStoreLocation = "$Root\$Store"
    
    $Cert = Get-ChildItem -Path Cert:\$CertStoreLocation | Where {$_.Thumbprint -eq $Thumbprint}

	$returnValue = @{
		Name = [System.String] $Cert.FriendlyName
		Ensure = [System.String] $Ensure
		Thumbprint = [System.String] $Thumbprint
		Subject = [System.String] $Cert.Subject
		Store = [System.String] $Store
		PfxPassphrase = [System.Management.Automation.PSCredential] $null
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$Thumbprint,

		[System.String]
		$Subject,

		[System.String]
		$Store = "My",

		[System.String]
		$Root = "Localmachine",

		[System.Management.Automation.PSCredential]
		$PfxPassphrase,

        [System.String]
        $PfxPath,

        [System.Management.Automation.PSCredential]
		$PfxPathCredential
	)
    
    # Create full path to use for the Get-ChildItem cmdlet.
    $CertStoreLocation = "$Root\$Store"

    if($Ensure = "Present")
    {

        # Copy the certificate locally before attempting to import
        Copy-Item -Path $PfxPath -Destination $env:TEMP\$Name.pfx -Credential $PfxPathCredential -Force

        # Get the secure password from the pscredential object. This will be used as a parameter for the Import-PfxCertificate cmdlet.
        $SecurePassphrase = $PfxPassphrase.GetNetworkCredential().SecurePassword

        try
        {
            Import-PfxCertificate -FilePath $env:TEMP\$Name.pfx -CertStoreLocation $CertStoreLocation -Password $SecurePassphrase
        }
        catch
        {
            Write-Verbose "Import-PfxCertificate failed to import the certificate. This cmdlet is only available on Windows Server 2012 R2 and Windows 8.1 (PowerShell 4.0)."
            Write-Verbose "Attempting to import the certificate with the X509Certificates object method."

            # Create certificate object to import into the store.

            $Pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $Pfx.Import($Store,$SecurePassphrase,"PersistKeySet")
        
            # Create the store object to be imported into.

            $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($Store,$Root)

            # Add the certificate to the store.
            $CertStore.Open("ReadWrite")
            $CertStore.Add($Pfx)
            $CertStore.Close()
        }

        # Clean-up to remove the certificate
        Remove-Item -Path $env:TEMP\$Name.pfx -Force
        $Seed = Get-Random
        $SecurePassphrase = Get-Random -SetSeed $Seed
    }

    if($Ensure = "Absent")
    {
        $Cert = Get-ChildItem -Path Cert:\$CertStoreLocation | Where {$_.Thumbprint -eq $Thumbprint}

        $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($Store,$Root)

        #Remove the certificate from the store.
        $CertStore.Open("ReadWrite")
        $CertStore.Remove($Cert)
        $CertStore.Close()
    }
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$Thumbprint,

		[System.String]
		$Subject,

		[System.String]
		$Store= "My",

		[System.String]
		$Root = "Localmachine",

		[System.Management.Automation.PSCredential]
		$PfxPassphrase,

        [System.String]
        $PfxPath
	)

    $CertStoreLocation = "$Root\$Store"

    $Cert = Get-ChildItem -Path Cert:\$CertStoreLocation | Where {$_.Thumbprint -eq $Thumbprint}

    if($Cert.Length -eq 1 -and $Ensure -eq "Present")
    {
        Write-Verbose "SUCCESS : Certificate was successfully found in the location : $Store, $Thumbprint."
        $Result = $true
    }
    elseif($Cert.Length -eq 0 -and $Ensure -eq "Absent")
    {   
        Write-Verbose "SUCCESS : Certificate was not found in the location : $Store, $Thumbprint."
        $Result = $true        
    }
    elseif($Cert.Length -eq 0 -and $Ensure -eq "Present")
    {
        Write-Verbose "FAILED : Certificate was not found in the location : $Store, $Thumbprint."
        $Result = $false
    }
    elseif($Cert.Length -eq 1 -and $Ensure -eq "Absent")
    {
        Write-Verbose "FAILED : Certificate was found in the location : $Store, $Thumbprint."
        $Result = $false
    }
    else
    {
        Write-Verbose "Unknown condition occurred, certificate not found or other issues present. Returning false."
        $Result = $false
    }
    return $Result
}


Export-ModuleMember -Function *-TargetResource

