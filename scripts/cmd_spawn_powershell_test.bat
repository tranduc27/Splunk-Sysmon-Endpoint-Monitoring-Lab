@echo off
REM Safe test script for Splunk-Sysmon-Endpoint-Monitoring-Lab
REM Purpose: Generate a cmd.exe -> powershell.exe process chain.

echo [*] Running harmless cmd spawned PowerShell test...
powershell.exe -NoProfile -Command "Write-Output cmd_spawned_powershell_test"
pause
