# Safe process creation test script.
# Purpose: Generate simple Sysmon EventCode 1 process creation logs.

Write-Output "[*] Starting harmless process creation tests..."

Start-Process notepad.exe
Start-Process calc.exe
Start-Process cmd.exe
Start-Process powershell.exe

Write-Output "[*] Done. Check Splunk for Sysmon EventCode=1."
