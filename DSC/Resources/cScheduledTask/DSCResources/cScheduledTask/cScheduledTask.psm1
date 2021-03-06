function Get-TargetResource
{
    [CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TaskName
	)

	
    Write-Verbose "Getting information for $TaskName scheduled task."
    
    $tasks_com_connector = New-Object -ComObject("Schedule.Service")
    $tasks_com_connector.Connect()

    $TaskList = $tasks_com_connector.getFolder("\").GetTasks(0)
    $Task = $TaskList | where {$_.Name -eq $TaskName}
    if($Task -ne $null)
    {
        $TaskEnsure = "Present"
    }
    else
    {
        $TaskEnsure = "Absent"
    }

    $Xml = [xml] ($Task.XML)

    $TaskStartTime = $Xml.Task.Triggers.CalendarTrigger.StartBoundary
    if($TaskStartTime)
    {
        $TaskStartTimeFormatted = $TaskStartTime | Get-Date -Format HH:mm:ss
    }
    Write-Verbose "Building TaskItem hash table."
   
    $TaskItem = @{
        TaskName = $Task.Name
        Ensure = $TaskEnsure
        Enabled = $Task.Enabled
        Description = $xml.Task.RegistrationInfo.Description
        TaskSchedule = $Xml.Task.Triggers.CalendarTrigger.ScheduleByDay.DaysInterval
        TaskStartTime = $TaskStartTimeFormatted
        RunAsUser = [ciminstance]$convertToCimCredential
        TaskToRun = $Xml.Task.Actions.Exec.Command
        Arguments = $Xml.Task.Actions.Exec.Arguments
    }
    
    return $TaskItem
}


function Set-TargetResource
{	
    [CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TaskName,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[ValidateSet("True","False")]
		[System.String]
		$Enabled,

		[System.String]
		$Description,

		[ValidateSet("Time","Daily","Weekly","Monthly","Idle","Boot","Logon")]
		[System.String]
		$TaskSchedule,

		[System.String]
		$TaskStartTime,

        [System.Management.Automation.PSCredential[]]
		$RunAsUser,

		[System.String]
        $TaskToRun,

		[System.String]
		$Arguments
	)

    
    if($Ensure -eq "Present")
    {
        
        $ScheduleTable = @{
            Time = 1
            Daily = 2
            Weekly = 3
            Monthly = 4
            Idle = 6
            Boot = 8
            Logon = 0
        }

        switch ($TaskSchedule)
        {
            "Time"{
                $TriggerValue = 1
                $TriggerDaysInterval = 0
            }
            "Daily"{
                $TriggerValue = 2
                $TriggerDaysInterval = 1
            }
            "Weekly"{
                $TriggerValue = 3
                $TriggerDaysInterval = 7
            }
            "Monthly"{
                $TriggerValue = 4
                $TriggerDaysInterval = 0
            }
            "Idle"{
                $TriggerValue = 6
                $TriggerDaysInterval = 0
            }
            "Boot"{
                $TriggerValue = 8
                $TriggerDaysInterval = 0
            }
            "Logon"{
                $TriggerValue = 9
                $TriggerDaysInterval = 0
            }
        }
        if($TaskStartTime)
        {
            $TaskStartTimeFormatted = $TaskStartTime | Get-Date -Format s
        }
        
        $User = $RunAsUser.GetNetworkCredential().UserName
        $Domain = $RunAsUser.GetNetworkCredential().Domain
        $Password = $RunAsUser.GetNetworkCredential().Password
        $FullUserName = ($Domain + "\" + $User)

        $tasks_com_connector = New-Object -ComObject("Schedule.Service")
        $tasks_com_connector.Connect()
        
        $TaskDefinition = $tasks_com_connector.NewTask(0)
        $RegInfo = $TaskDefinition.RegistrationInfo

        $RegInfo.Description = $Description
        $RegInfo.Author = $FullUserName

        $Settings = $TaskDefinition.Settings
        $Settings.Enabled = $Enabled

        $Triggers = $TaskDefinition.Triggers
        $Trigger = $Triggers.Create($TriggerValue)
        if($TriggerDaysInterval -ne 0)
        {
            $Trigger.DaysInterval = $TriggerDaysInterval
        }
        $Trigger.Enabled = $Enabled
        $Trigger.StartBoundary = $TaskStartTimeFormatted
        $Action = $TaskDefinition.Actions.Create(0)
        $Action.Path = $TaskToRun
        $Action.Arguments = $Arguments

        $rootFolder = $tasks_com_connector.GetFolder("\")
        $rootFolder.RegisterTaskDefinition($TaskName,$TaskDefinition,6,$FullUserName,$Password,1)

        Write-Verbose "Registered scheduled task $TaskName with user credentials for $FullUserName."
    }
    
    if($Ensure -eq "Absent")
    {        
        $tasks_com_connector = New-Object -ComObject("Schedule.Service")
        $tasks_com_connector.Connect()
        
        $Task = $TaskList | where {$_.Name -eq $TaskName}

        if($Task -ne $null)
        {
            $TaskEnsure = "Present"
        }

        $tasks_com_connector.getfolder("\").DeleteTask($TaskName,0)
        Write-Verbose "Scheduled Task $TaskName was removed from $ENV:COMPUTERNAME."
    }
    #>
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$TaskName,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[ValidateSet("True","False")]
		[System.String]
		$Enabled,

		[System.String]
		$Description,

		[ValidateSet("Time","Daily","Weekly","Monthly","Idle","Boot","Logon")]
		[System.String]
		$TaskSchedule,

		[System.String]
		$TaskStartTime,

        [System.Management.Automation.PSCredential[]]
		$RunAsUser,

		[System.String]
        $TaskToRun,

		[System.String]
		$Arguments
	)

    switch ($TaskSchedule)
        {
            "Time"{
                $TriggerValue = 1
                $TriggerDaysInterval = 0
            }
            "Daily"{
                $TriggerValue = 2
                $TriggerDaysInterval = 1
            }
            "Weekly"{
                $TriggerValue = 3
                $TriggerDaysInterval = 7
            }
            "Monthly"{
                $TriggerValue = 4
                $TriggerDaysInterval = 0
            }
            "Idle"{
                $TriggerValue = 6
                $TriggerDaysInterval = 0
            }
            "Boot"{
                $TriggerValue = 8
                $TriggerDaysInterval = 0
            }
            "Logon"{
                $TriggerValue = 9
                $TriggerDaysInterval = 0
            }
        }

    if($RunAsUser)
    {
        $User = $RunAsUser.GetNetworkCredential().UserName
        $Domain = $RunAsUser.GetNetworkCredential().Domain
        $FullUserName = ($Domain + "\" + $User)
    }

    $tasks_com_connector = New-Object -ComObject("Schedule.Service")
    $tasks_com_connector.Connect()

    $TaskList = $tasks_com_connector.getFolder("\").GetTasks(0)
    $Task = $TaskList | where {$_.Name -eq $TaskName}

    if($Task.Name -eq $TaskName -and $Ensure -eq "Absent")
    {
        Write-Verbose "$TaskName found on $ENV:COMPUTERNAME. Ensure = $Ensure"
        $Result = $false
    }
    if($Task.Name -ne $TaskName -and $Ensure -eq "Absent")
    {
        Write-Host "$TaskName not found on $ENV:COMPUTERNAME. Ensure = $Ensure"
        $Result = $true
    }
    
    if($Task.Name -ne $TaskName -and $Ensure -eq "Present")
    {
        Write-Verbose "$TaskName not found on $ENV:COMPUTERNAME. Ensure = $Ensure"
        $Result = $false
    }
    
    if($Task.Name -eq $TaskName -and $Ensure -eq "Present")
    {
        Write-Verbose "$TaskName found on $ENV:COMPUTERNAME. Verifying task parameters."

        $Xml = [xml] ($Task.XML)

        $TaskStartTime = $Xml.Task.Triggers.CalendarTrigger.StartBoundary
        if($TaskStartTime)
        {
            $TaskStartTimeFormatted = $TaskStartTime | Get-Date -Format HH:mm:ss
        }
                
        $TaskNameOutput = $Task.Name
        $EnabledOutput = $Task.Enabled
        $DescriptionOutput = $xml.Task.RegistrationInfo.Description
        $DaysIntervalOutput = $Xml.Task.Triggers.CalendarTrigger.ScheduleByDay.DaysInterval
        $TaskStartTimeOutput = $TaskStartTimeFormatted
        $AuthorOutput = $Xml.Task.RegistrationInfo.Author
        $RunAsUserOutput = $Xml.Task.Principals.Principal.UserId
        $TaskToRunOutput = $Xml.Task.Actions.Exec.Command
        $ArgumentsOutput = $Xml.Task.Actions.Exec.Arguments
        $LastRunTimeOutput = $Task.LastRunTime
        $LastResultOutput = $Task.LastTaskResult
        $NextRunTimeOutput = $Task.NextRunTime

        if($Ensure -eq "Absent" -and $TaskItem.TaskName -eq $TaskName)
        {
            $Result = $False
        }
        else
        {
            if($TaskNameOutput -ne $TaskName)
            {
                Write-Verbose "$TaskNameOutput != $TaskName. Test Failed!"
                $TaskNameResult = $False
            }
                else
                {
                    Write-Verbose "$TaskNameOutput = $TaskName. Test Success!"
                    $TaskNameResult = $True
                }

            if($EnabledOutput -ne $Enabled)
            {
                Write-Verbose "$EnabledOutput != $Enabled. Test Failed!"
                $EnabledResult = $False
            }
                else
                {
                    Write-Verbose "$EnabledOutput = $Enabled. Test Success!"
                    $EnabledResult = $True
                }

            if($TriggerDaysInterval -ne 0)
            {
                if($DaysIntervalOutput -ne $TriggerDaysInterval)
                {
                    Write-Verbose "$DaysIntervalOutput != $TriggerDaysInterval. Test Failed!"
                    $DaysIntervalResult = $False
                }
                    else
                    {
                        Write-Verbose "$DaysIntervalOutput = $TriggerDaysInterval. Test Success!"
                        $DaysIntervalResult = $True
                    }
            }
        
            if($TaskStartTimeOutput -ne $TaskStartTimeFormatted)
            {
                Write-Verbose "$TaskStartTimeOutput != $TaskStartTimeFormatted. Test Failed!"
                $TaskStartTimeResult = $False
            }
                else
                {
                    Write-Verbose "$TaskStartTimeOutput = $TaskStartTimeFormatted. Test Success!"
                    $TaskStartTimeResult = $True
                }

            if($Description)
            {
                if($DescriptionOutput -ne $Description)
                {
                    Write-Verbose "$DescriptionOutput != $Description. Test Failed!"
                    $DescriptionResult = $False
                }
                    else
                    {
                        Write-Verbose "$DescriptionOutput = $Description. Test Success!"
                        $DescriptionResult = $True
                    }
            }
            if($RunAsUserOutput -ne $FullUserName)
            {
                Write-Verbose "$RunAsUserOutput != $RunAsUser. Test Failed!"
                    $RunAsUserResult = $False
            }
                else
                {
                    Write-Verbose "$RunAsUserOutput = $RunAsUser. Test Success!"
                    $RunAsUserResult = $True
                }

            if($TaskToRunOutput -ne $TaskToRun)
            {
                Write-Verbose "$TaskToRunOutput != $TaskToRun. Test Failed!"
                $TaskToRunResult = $False
            }
                else
                {
                    Write-Verbose "$TaskToRunOutput = $TaskToRun. Test Success!"
                    $TaskToRunResult = $True
                }

            if($Arguments)
            {
                if($ArgumentsOutput -ne $Arguments)
                {
                    Write-Verbose "$ArgumentsOutput != $Arguments. Test Failed!"
                    $ArgumentsResult = $False
                }
                    else
                    {
                        Write-Verbose "$ArgumentsOutput = $Arguments. Test Success!"
                        $ArgumentsResult = $True
                    }
            }

            if(
                $TaskNameResult -eq $False -or
                $EnabledResult -eq $False -or
                $DaysIntervalResult -eq $False -or
                $DescriptionResult -eq $False -or
                $RunAsUserResult -eq $False -or
                $TaskToRunResult -eq $False -or
                $ArgumentsResult -eq $False
            )
                {
                    Write-Verbose "One or more tests failed."
                    [System.Boolean]$Result = $False
                }
                else
                {
                    Write-Verbose "All tests passed!"
                    [System.Boolean]$Result = $True
                }
        }
    }
    
    return $Result
}

Export-ModuleMember -Function *-TargetResource
