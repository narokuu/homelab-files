Stop-Service -Name IntuneManagementExtension
Get-Item -Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IntuneManagementExtension\win32App* | Remove-Item -Force -Recurse
Restart-Service -Name IntuneManagementExtension