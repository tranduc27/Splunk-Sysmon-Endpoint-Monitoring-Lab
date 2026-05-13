# Safe test script for Splunk-Sysmon-Endpoint-Monitoring-Lab
# Purpose: Generate a harmless PowerShell process with -EncodedCommand
# Run in Windows PowerShell.

$command = 'Write-Output "This is a harmless Sysmon detection test"'
$bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
$encoded = [Convert]::ToBase64String($bytes)

Write-Output "[*] Running harmless encoded PowerShell test..."
powershell.exe -NoProfile -EncodedCommand $encoded
