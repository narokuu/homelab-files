#this script will delete all files in a directory older than 30 days

ls -File -Recurse | ? lastwritetime -lt (Get-Date).AddDays(-30) | Remove-Item -WhatIf