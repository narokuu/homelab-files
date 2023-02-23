Get-ComputerRestorePoint | Delete-ComputerRestorePoint -WhatIf  

#delete all System Restore Points older than 14 days 
$removeDate = (Get-Date).AddDays(-14) 
Get-ComputerRestorePoint |  
        Where { $_.ConvertToDateTime($_.CreationTime) -lt  $removeDate } |  
        Delete-ComputerRestorePoint