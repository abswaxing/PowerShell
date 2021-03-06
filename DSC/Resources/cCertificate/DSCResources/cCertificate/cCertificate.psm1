function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Thumbprint,

        [System.String]
        $Root,

		[System.String]
		$Store
	)


    Write-Verbose "Getting the information for certificate name: $SslCertName."

    $Certificate = Get-ChildItem -Path Cert:\$Root\$Store | Where {$_.Thumbprint -eq $Thumbprint}

    if($Certificate -gt 1)
    {
        Write-Error "More than one certificate found for subject name : $Subject"
        $returnValue = @{
            Name = $Name
            Ensure = $Ensure
            Password = "N/A"
            Path = $null
            Subject = $Subject
            Store = $Store
            Thumbprint = "N/A"
            Issuer = "N/A"
            IssuerName = "N/A"
        }
    }
    else
    {
        $returnValue = @{
            Name = $Name
            Ensure = $Ensure
            Password = ""
            Path = $Path
            Subject = $Certificate.SubjectName
            Store = $Store
            Thumbprint = $Certificate.Thumbprint
            Issuer = $Certificate.Issuer
            IssuerName = $Certificate.IssuerName
        }
    }
    
    return $returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[System.Management.Automation.PSCredential[]]
		$Password,

		[System.String]
		$Path,

        [System.String]
        $Thumbprint,

		[System.String]
		$Subject,

        [System.String]
        $Root,

		[System.String]
		$Store
	)

    switch ($Ensure)
    {
        "Present" {
            # Install SSL certificate
            Write-Verbose "Importing certificate $Subject into $Root\$Store."
            Import-Certificate -Path $Path -Root $Root -Store $Store -Password $Password
        }
        "Absent" {
            # Remove SSL certificate
            Write-Verbose "Removing certificate $Subject from $Root\$Store."
            Remove-Certificate -Subject $Subject -Root $Root -Store $Store
        }
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[System.Management.Automation.PSCredential[]]
		$Password,

		[System.String]
		$Path,

        [parameter(Mandatory = $true)]
        [System.String]
        $Thumbprint,

		[System.String]
		$Subject,

        [System.String]
        $Root,

		[System.String]
		$Store
	)

    Write-Verbose "Getting the information for certificate name: $SslCertName."

    $Certificate = Get-ChildItem -Path Cert:\$Root\$Store | Where {$_.Thumbprint -eq $Thumbprint}

    switch ($Ensure)
    {
        "Present" {
            if($Certificate) 
            {
                $ReturnedThumbprint = $Certificate.Thumbprint
                Write-Verbose "One certificate found for subject in cert:\$Root\$Store : $Subject : $ReturnedThumbprint"
                return $true
            }
            else 
            {
                Write-Verbose "Certificate not found in cert:\$Root\$Store : $Subject : $Thumbprint"
                return $false
            }
        }
        "Absent" {
            if(!($Certificate))
            {
                Write-Verbose "Certificate not found in cert:\$Root\$Store : $Subject : $Thumbprint"
                return $true
            }
            else
            {
                $ReturnedThumbprint = $Certificate.Thumbprint
                Write-Verbose "One certificate found for subject in cert:\$Root\$Store : $Subject : $ReturnedThumbprint"
                return $false
            }
        }
    }
}



function Remove-Certificate 
{
    param(
	    [String] $Subject,
	    [String] $Root,
        [String] $Store
    )

	$Certificate = Get-ChildItem -path cert:\$Root\$Store | where { $_.Subject.ToLower().Contains($Subject) }

	$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store($Store,$Root)
	
	$Store.Open("ReadWrite")
	$Store.Remove($Certificate)
	$Store.Close()
}

function Import-Certificate 
{    
    param(
		[String] $Path,
		[String] $Root = "LocalMachine",
		[String] $Store = "My",
		[System.Management.Automation.PSCredential[]] $Password
    )

    $PfxPass = $Password.GetNetworkCredential().Password

	$Pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2    
    $Pfx.Import($certPath,$pfxPass,"Exportable,PersistKeySet")

 	$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store($Store,$Root)
 	$Store.Open("MaxAllowed")
 	$Store.Add($Pfx)
 	$Store.Close()

    $PfxPass = $null
 } 


Export-ModuleMember -Function *-TargetResource

