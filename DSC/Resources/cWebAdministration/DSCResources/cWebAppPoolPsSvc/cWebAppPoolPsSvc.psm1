function Get-PasswordWithCreds
{
    param (
        [Parameter(ParameterSetName="Name",Mandatory=$true)]
        [system.string] $Name,

        [Parameter(ParameterSetName="Name",Mandatory=$true)]
        [System.Management.Automation.PSCredential[]]
        $Credential,

        [Parameter(ParameterSetName="Name",Mandatory=$true)]
        [System.String]
        $PasswordServiceUrl
    )
    
    #Set-Variable -Name password_server -Value "passwords.domain.com"

    $password_urls = New-Object PSObject -Property @{
        PasswordList="https://$PasswordServiceUrl/passwords/api/passwords/"
        PasswordDetails="https://$PasswordServiceUrl/passwords/api/passwords/{0}"
    }

    $password_error_data = New-Object PSObject -Property @{
        NoServiceAccountName="No Service Account was found of Name : {0}"
        NoPasswordofId="No Password was found of ID : {0}."
        GtOneResult="More than one result was found : {0}."
    }

    $User = ($Credential.GetNetworkCredential().Domain + "\" + $Credential.GetNetworkCredential().UserName)    
    $Password = $Credential.GetNetworkCredential().Password
    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
    $Creds = New-Object pscredential -ArgumentList $User,$SecurePassword
    
    $passwordlist = Invoke-RestMethod -Method Get -Uri $password_urls.PasswordList -Credential $Creds
    
    Write-Verbose "Getting the password ID from list : $Name."
    $id = @($passwordlist | Where { $_.Name -ieq $Name } | Select -ExpandProperty PasswordId)
    
    if(!$id) {
        throw ($password_error_data.NoServiceAccountName -f $name)
    }

    Write-Verbose "Checking id length."
    if($id.Length -ne 1)
    {
        throw ($password_error_data.GtOneResult -f $name)
    }
    
    Write-Verbose "Getting password details."
    $response = Invoke-RestMethod -Method Get -Uri ($password_urls.PasswordDetails -f $id) -Credential $Creds
    
    Write-Verbose "Password details are $response."
    return $response

}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    $Ensure = "Absent"
    $State  = "Stopped"

    Import-Module WebAdministration

    try {
        Write-Verbose "Getting WebAppPool for $Name" 
        $WebAppPool = Get-Item -Path IIS:\AppPools\* | ? {$_.name -eq $Name} }
    catch { $WebAppPool = $null }

    if($WebAppPool -ne $null)
    {
        $Ensure = "Present"
        $State  = $WebAppPool.state
        $IdentityType = (Get-ItemProperty -Path IIS:\AppPools\$Name -Name ProcessModel).identityType
        $Identity = (Get-ItemProperty -Path IIS:\AppPools\$Name -Name ProcessModel).userName
    }
    
    if($IdentityType -eq "ApplicationPoolIdentity")
        {$IdentityResult = "ApplicationPoolIdentity" }
    else
        { $IdentityResult = $Identity }
               
    $returnValue = @{
        Name   = $Name
        Ensure = $Ensure
        State  = $State
        AppPoolIdentity = $IdentityResult
        PasswordServiceCredential = "N/A"
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
        $Ensure = "Present",

        [ValidateSet("Started","Stopped")]
        [System.String]
        $State = "Started",
        
        [System.String]
        $AppPoolIdentity,

        [System.Management.Automation.PSCredential[]]
        $PasswordServiceCredential
    )

    Import-Module WebAdministration
    
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw "Please ensure that WebAdministration module is installed."
    }
    <#
    try {
        Import-Module (Join-Path $env:POWERSHELL_HOME "\Libraries\PasswordService.psm1")
    }
    catch {
        Throw "Please ensure that PasswordService.psm1 module is installed and the SCRIPTS_HOME environment variable present."
    }
    #>
    if($Ensure -eq "Absent")
    {
        Write-Verbose("Removing the Web App Pool")
        Remove-WebAppPool $Name
    }
    else
    {

        $WebAppPool = Get-Item -Path IIS:\AppPools\* | ? {$_.name -eq $Name}
        if($WebAppPool.Name -eq $Name)
        {
            $Ensure = "Present"
            $State  = $WebAppPool.state
            $Identity = (Get-ItemProperty -Path IIS:\AppPools\$Name -Name ProcessModel).userName
            
            $AppPool = @{
                Name   = $Name
                Ensure = $Ensure
                State  = $State
                Identity = $Identity
            }
        }

        if($AppPool.Ensure -ne "Present")
        {
            Write-Verbose("Creating the Web App Pool - $Name")
            New-WebAppPool $Name
        }

        if($AppPool.State -ne $State)
        {
            ExecuteRequiredState -Name $Name -State $State
        }

        if($AppPoolIdentity)
        {
            $IdentityCreds = Get-PasswordWithCreds -name $AppPoolIdentity -Credential $PasswordServiceCredential
            $Value = @{
                username = $IdentityCreds.Name;
                password = $IdentityCreds.Value;
                identityType = 3
            }

            Set-ItemProperty  "IIS:\AppPools\$Name" -Name processModel -Value $Value
            <#
            $IdentityCreds = $null
            $Value = $null
            #>
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
        $Ensure  = "Present",

        [ValidateSet("Started","Stopped")]
        [System.String]
        $State = "Started",

        [System.String]
        $AppPoolIdentity,

        [System.Management.Automation.PSCredential[]]
        $PasswordServiceCredential
    )

    Import-Module WebAdministration
    
    $AppPool = Get-Item -Path IIS:\AppPools\* | ? {$_.name -eq $Name}
    
    if($AppPool -ne $null)
    {
        $WebAppPool = @{
            Ensure = "Present"
            State  = $AppPool.State
            Identity = (Get-ItemProperty -Path IIS:\AppPools\$Name -Name ProcessModel).userName
        }
    }
    else
    {        
        $WebAppPool = $null
    }

    if($Ensure -eq "Present" -and $WebAppPool -ne $null)
    {
        if($AppPoolIdentity)
        {
            Write-Verbose "Getting IdentityCreds for $AppPoolIdentity."
            $IdentityCreds = Get-PasswordWithCreds -name $AppPoolIdentity -Credential $PasswordServiceCredential
                        
            $CurrentUsername = Get-ItemProperty "IIS:\AppPools\$Name" -Name processModel | Select username -ExpandProperty username
            $CurrentPassword = Get-ItemProperty "IIS:\AppPools\$Name" -Name processModel | Select password -ExpandProperty password
            $CurrentIdentityType = Get-ItemProperty "IIS:\AppPools\$Name" -Name processModel | Select identityType -ExpandProperty identityType

            if($CurrentUsername -eq $IdentityCreds.Name) { $UsernameResult = $true } else{ $UsernameResult = $false; Write-Verbose "Username comparision failed!" }
            if($CurrentPassword -eq $IdentityCreds.Value) { $PasswordResult = $true } else{ $PasswordResult = $false; Write-Verbose "Password comparision failed!" }
            if($CurrentIdentityType -eq "SpecificUser") { $IdentityTypeResult = $true } else{ $IdentityTypeResult = $false; Write-Verbose "IdentityType comparision failed!" }
            
            if($UsernameResult -eq $true -and $PasswordResult -eq $true -and $IdentityTypeResult -eq $true)
            {
                return $true
            }
            else
            {
                return $false
            }
        }
        elseif($WebAppPool.Ensure -eq $Ensure -and $WebAppPool.State -eq $state)
        {
            return $true
        }
        else
        {
            return $false
        }
    }
    return $false
}


function ExecuteRequiredState([string] $Name, [string] $State)
{
    if($State -eq "Started")
    {
        Write-Verbose("Starting the Web App Pool")
        start-WebAppPool -Name $Name
    }
    else
    {
        Write-Verbose("Stopping the Web App Pool")
        Stop-WebAppPool -Name $Name
    }
}

Export-ModuleMember -Function *-TargetResource