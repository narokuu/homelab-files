@echo off
goto check_permissions

:check_permissions
	echo You must have administrative rights to run this script. Checking if you have sufficient priviledges...
	net session > nul 2>&1
	if %errorLevel% == 0 (
		echo You have sufficient priviledges. Running the script...
		REG ADD HKLM\SOFTWARE\Policies\Microsoft\PassportForWork /v Enabled /t REG_DWORD /d 0 /f
		echo Script completed.
		DEL "%~f0"
	) else (
		echo You do not have sufficient priviledges to run this script.
	)
	
	pause