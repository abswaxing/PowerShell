﻿# Connect to Exchange Online
$Credentials = Get-Credential
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $Credentials -Authentication Basic –AllowRedirection
Import-PSSession $session -DisableNameChecking


# Get Rooms and disable AllowConflicts
$rooms = Get-Mailbox -ResultSize Unlimited | Where {$_.ResourceType -eq 'Room'}

foreach($room in $rooms){
    
    Set-CalendarProcessing -Identity $room.Identity -AllowConflicts $false
}

# Verify AllowConflicts is now false
(Get-Mailbox -ResultSize Unlimited | Where {$_.ResourceType -eq 'Room'}) | Get-CalendarProcessing | Select Identity, AllowConflicts