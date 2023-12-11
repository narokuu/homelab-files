#The Following commands will set the execution polcy on the local machine to allow, then install the script to get the information needed for autopilot.
#Then with the online flag, using globl administrator credentials, automatically upload the devices hardware hash into autopilot.
Set-ExecutionPolicy bypass
Install-Script Get-WindowsAutoPilotInfo
Get-WindowsAutoPilotInfo.ps1 -online