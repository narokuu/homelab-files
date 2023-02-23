@echo off
FOR /F "skip=2 tokens=2,*" %%A IN ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Endpoint Security" /v "UninstallString"') DO SET "UninstallString=%%B"
%UninstallString% /silent /remove
shutdown.exe /r /norestart /t 10